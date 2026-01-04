module Jelly
  module VirtualMachine
    class Engine
      Log = ::Log.for(self)

      property processes : Array(Process) = [] of Process
      property configuration : Configuration = Configuration.new
      property custom_handlers : Hash(Code, Proc(Process, Instruction, Value)) = {} of Code => Proc(Process, Instruction, Value)
      property breakpoints : Array(Proc(Process, Bool)) = [] of Proc(Process, Bool)
      property process_registry : ProcessRegistry = ProcessRegistry.new
      property delayed_messages : Array(Tuple(Time, UInt64, UInt64, Value)) = [] of Tuple(Time, UInt64, UInt64, Value)
      property reactivation_queue : Array(Process) = [] of Process
      property last_cleanup_time : Time = Time.utc

      # Fault tolerance properties
      property process_links : ProcessLinks = ProcessLinks.new
      property supervisor_registry : SupervisorRegistry = SupervisorRegistry.new
      property crash_dump_storage : CrashDumpStorage = CrashDumpStorage.new

      @executor : InstructionExecutor?
      @process_manager : ProcessManager?
      @execution_channel : Channel(Tuple(Process, Value))?
      @fault_handler : FaultHandler?

      def initialize
        Log.debug { "Initializing the Engine" }
      end

      def executor : InstructionExecutor
        @executor ||= InstructionExecutor.new(self)
      end

      def process_manager : ProcessManager
        @process_manager ||= ProcessManager.new(self)
      end

      def fault_handler : FaultHandler
        @fault_handler ||= FaultHandler.new(self)
      end

      def execute(process : Process, instruction : Instruction) : Value
        return Value.new if process.state != Process::State::ALIVE

        process.reductions += 1 if process.responds_to?(:reductions)

        begin
          executor.execute(process, instruction)
        rescue ex : EmulationException
          handle_process_exception(process, ex)
          Value.new(ex)
        rescue ex : Exception
          handle_process_exception(process, ex)
          Value.new(ex)
        end
      end

      def handle_process_exception(process : Process, exception : Exception)
        Log.error { "Process <#{process.address}>: #{exception.message}" }

        if executor.handle_exception(process, exception)
          return
        end

        if Recovery.try_recover(self, process, exception)
          return
        end

        process.state = Process::State::DEAD
        reason = ExitReason.exception(exception)
        process.exit_reason = reason if process.responds_to?(:exit_reason=)

        dump = Recovery.create_crash_dump(process, reason)
        @crash_dump_storage.store(dump)

        fault_handler.handle_exit(process, reason)
      end

      def queue_process_for_reactivation(process : Process)
        @reactivation_queue << process unless @reactivation_queue.includes?(process)
      end

      def schedule_delayed_message(sender : UInt64, recipient : UInt64, value : Value, delay_seconds : Float64)
        delivery_time = Time.utc + delay_seconds.seconds
        @delayed_messages << {delivery_time, sender, recipient, value}
        Log.debug { "Scheduled message from <0.#{sender}> to <0.#{recipient}> for delivery at #{delivery_time}" }
      end

      def check_blocked_sends(process : Process)
        @processes.each do |p|
          next unless p.state == Process::State::BLOCKED

          p.blocked_sends.each_with_index do |(target_address, message), index|
            if target_address == process.address && process.mailbox.size < @configuration.max_mailbox_size
              if process.mailbox.push(message)
                Log.debug { "Unblocked send from <0.#{p.address}> to <0.#{process.address}>" }
                p.blocked_sends.delete_at(index)
                p.remove_dependency(process.address)

                if p.blocked_sends.empty?
                  p.state = Process::State::ALIVE
                  queue_process_for_reactivation(p)
                end
                break
              end
            end
          end
        end
      end

      def deliver_delayed_messages : Int32
        now = Time.utc
        messages_to_deliver = @delayed_messages.select { |time, _, _, _| time <= now }
        return 0 if messages_to_deliver.empty?

        messages_delivered = 0

        messages_to_deliver.each do |_, sender, recipient, value|
          target = processes.find { |p| p.address == recipient && p.state != Process::State::DEAD }
          next unless target

          message = Message.new(sender, value, @configuration.enable_message_acks)

          if target.mailbox.size < @configuration.max_mailbox_size && target.mailbox.push(message)
            Log.debug { "Delivered delayed message from <0.#{sender}> to <0.#{recipient}>" }
            messages_delivered += 1

            if (target.state == Process::State::WAITING ||
               (target.state == Process::State::STALE && @configuration.auto_reactivate_processes))
              if target.waiting_for.nil? ||
                 target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
                queue_process_for_reactivation(target)
              end
            end
          end
        end

        @delayed_messages.reject! { |time, _, _, _| time <= now }
        messages_delivered
      end

      def run
        fault_handler.start
        iterations = 0
        completed_processes = Set(UInt64).new

        loop do
          iterations += 1
          if iterations >= @configuration.iteration_limit
            Log.warn { "Engine run exceeded iteration limit (#{@configuration.iteration_limit})" }
            break
          end

          check_breakpoints
          delayed_delivered = deliver_delayed_messages

          now = Time.utc
          if now - last_cleanup_time > @configuration.message_cleanup_interval
            process_manager.cleanup_expired_messages
            last_cleanup_time = now
          end

          active_processes = process_manager.active_processes(completed_processes)
          waiting_processes = process_manager.waiting_processes_ready(completed_processes)
          timeout_processes = process_manager.processes_with_expired_timeouts(completed_processes)
          blocked_processes = process_manager.blocked_processes_ready(completed_processes)

          reactivation_queue.each do |process|
            process.state = Process::State::ALIVE
          end
          progress_made = !reactivation_queue.empty?
          reactivation_queue.clear

          progress_made |= process_manager.execute_active_processes(active_processes, completed_processes)
          progress_made |= process_manager.handle_timeout_processes(timeout_processes)
          progress_made |= process_manager.reactivate_waiting_processes(waiting_processes)
          progress_made |= process_manager.unblock_blocked_processes(blocked_processes)

          if !progress_made && !delayed_delivered && process_manager.detect_deadlock
            Log.warn { "Deadlock detected - terminating execution" }

            if @configuration.deadlock_detection
              processes.each do |p|
                if p.state == Process::State::WAITING || p.state == Process::State::STALE || p.state == Process::State::BLOCKED
                  p.state = Process::State::DEAD
                  completed_processes.add(p.address)
                  fault_handler.handle_exit(p, ExitReason.custom("deadlock"))
                end
              end
              raise DeadlockException.new("Deadlock detected - terminating execution")
            end
            break
          end

          process_manager.update_process_states(completed_processes)

          if processes.all? { |p| p.state == Process::State::DEAD }
            Log.info { "All processes completed" }
            break
          end

          Fiber.yield
          sleep @configuration.execution_delay
        end

        fault_handler.stop
        @supervisor_registry.all.each(&.shutdown)
        log_final_status(iterations)
      end

      def create_supervisor(
        strategy : RestartStrategy = RestartStrategy::OneForOne,
        max_restarts : Int32 = 3,
        restart_window : Time::Span = 5.seconds,
      ) : Supervisor
        sup_process = process_manager.create_process(instructions: [] of Instruction)
        @processes << sup_process

        supervisor = Supervisor.new(self, sup_process.address, strategy, max_restarts, restart_window)
        @supervisor_registry.register(supervisor)
        supervisor
      end

      def spawn_link(parent : Process, instructions : Array(Instruction)) : Process
        child = process_manager.create_process(instructions: instructions)
        child.parent = parent.address if child.responds_to?(:parent=)
        @processes << child
        @process_links.link(parent.address, child.address)
        child
      end

      def spawn_monitor(parent : Process, instructions : Array(Instruction)) : Tuple(Process, MonitorRef)
        child = process_manager.create_process(instructions: instructions)
        child.parent = parent.address if child.responds_to?(:parent=)
        @processes << child
        ref = @process_links.monitor(parent.address, child.address)
        {child, ref}
      end

      def exit_process(pid : UInt64, reason : String)
        exit_reason = case reason
                      when "normal"   then ExitReason.normal
                      when "kill"     then ExitReason.kill
                      when "shutdown" then ExitReason.shutdown
                      else                 ExitReason.custom(reason)
                      end
        fault_handler.kill_process(pid, exit_reason)
      end

      def fault_tolerance_stats : NamedTuple(links: Int32, monitors: Int32, trapping: Int32, supervisors: Int32, crash_dumps: Int32)
        link_stats = @process_links.stats
        {
          links:       link_stats[:links],
          monitors:    link_stats[:monitors],
          trapping:    link_stats[:trapping],
          supervisors: @supervisor_registry.all.size,
          crash_dumps: @crash_dump_storage.all.size,
        }
      end

      private def check_breakpoints
        processes.each do |process|
          next unless process.state == Process::State::ALIVE

          @breakpoints.each do |condition|
            if condition.call(process)
              Log.info { "Breakpoint hit for Process <#{process.address}>" }
              process.state = Process::State::STALE
              break
            end
          end
        end
      end

      private def log_final_status(iterations : Int32)
        Log.info { "VM execution completed after #{iterations} iterations" }

        processes.each do |p|
          Log.info { "Process <#{p.address}> final state: #{p.state}, counter: #{p.counter}" }
          if !p.mailbox.empty?
            Log.info { "Process <#{p.address}> has #{p.mailbox.size} unprocessed messages" }
          end
        end

        Log.debug { "Final VM state: #{process_manager.dump_state}" }
        Log.debug { "Fault tolerance stats: #{fault_tolerance_stats}" }
      end

      def inspect_process(address : UInt64) : String?
        process = processes.find { |p| p.address == address }
        return nil unless process

        {
          address:       process.address,
          state:         process.state,
          counter:       process.counter,
          stack:         process.stack.map(&.to_s),
          mailbox:       process.mailbox.size,
          call_stack:    process.call_stack.to_a,
          frame_pointer: process.frame_pointer,
          links:         @process_links.get_links(process.address),
          traps_exit:    @process_links.traps_exit?(process.address),
        }.to_json
      end
    end
  end
end
