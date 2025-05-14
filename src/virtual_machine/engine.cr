module Jelly
  module VirtualMachine
    # Main VM engine class with enhanced message passing
    class Engine
      Log = ::Log.for(self)

      property processes : Array(Process) = [] of Process
      property instructions : Array(Instruction) = [] of Instruction
      property subroutines : Hash(String, Subroutine) = {} of String => Subroutine
      property config : Configuration = Configuration.new
      property custom_handlers : Hash(Code, Proc(Process, Instruction, Value)) = {} of Code => Proc(Process, Instruction, Value)
      property breakpoints : Array(Proc(Process, Bool)) = [] of Proc(Process, Bool)
      property process_registry : ProcessRegistry = ProcessRegistry.new
      property delayed_messages : Array(Tuple(Time, UInt64, UInt64, Value)) = [] of Tuple(Time, UInt64, UInt64, Value)
      property reactivation_queue : Array(Process) = [] of Process
      property last_cleanup_time : Time = Time.utc

      @executor : InstructionExecutor?
      @process_manager : ProcessManager?
      @execution_channel : Channel(Tuple(Process, Value))?

      def initialize
        Log.debug { "Initializing the Engine" }
      end

      def executor : InstructionExecutor
        unless @executor
          @executor = InstructionExecutor.new(self)
        end

        return @executor.not_nil!
      end

      def process_manager : ProcessManager
        unless @process_manager
          @process_manager = ProcessManager.new(self)
        end

        return @process_manager.not_nil!
      end

      def execute(process : Process, instruction : Instruction) : Value
        executor.execute(process, instruction)
      end

      # Queue a process for reactivation in the main execution loop
      def queue_process_for_reactivation(process : Process)
        @reactivation_queue << process unless @reactivation_queue.includes?(process)
      end

      # Schedule a delayed message
      def schedule_delayed_message(sender : UInt64, recipient : UInt64, value : Value, delay_seconds : Float64)
        delivery_time = Time.utc + delay_seconds.seconds
        @delayed_messages << {delivery_time, sender, recipient, value}
        Log.debug { "Scheduled message from <0.#{sender}> to <0.#{recipient}> for delivery at #{delivery_time}" }
      end

      # Check for processes blocked on sends to this process
      def check_blocked_sends(process : Process)
        @processes.each do |p|
          next unless p.state == Process::State::BLOCKED

          # Check if this process was blocking any sends
          p.blocked_sends.each_with_index do |(target_address, message), index|
            if target_address == process.address && process.mailbox.size < @config.max_mailbox_size
              # Try to send the message now
              if process.mailbox.push(message)
                Log.debug { "Unblocked send from <0.#{p.address}> to <0.#{process.address}>" }
                p.blocked_sends.delete_at(index)
                p.remove_dependency(process.address)

                # If all blocked sends are cleared, reactivate the process
                if p.blocked_sends.empty?
                  p.state = Process::State::ALIVE
                  queue_process_for_reactivation(p)
                end

                # Only handle one message at a time to avoid array modification issues
                break
              end
            end
          end
        end
      end

      # Deliver any delayed messages that are due
      def deliver_delayed_messages : Int32
        now = Time.utc
        messages_to_deliver = @delayed_messages.select { |time, _, _, _| time <= now }
        return 0 if messages_to_deliver.empty?

        messages_delivered = 0

        messages_to_deliver.each do |_, sender, recipient, value|
          # Find the target process
          target = processes.find { |p| p.address == recipient && p.state != Process::State::DEAD }
          next unless target

          # Create and deliver the message
          message = Message.new(sender, value, @config.enable_message_acks)

          if target.mailbox.size < config.max_mailbox_size && target.mailbox.push(message)
            Log.debug { "Delivered delayed message from <0.#{sender}> to <0.#{recipient}>" }
            messages_delivered += 1

            # Queue for reactivation if waiting
            if (target.state == Process::State::WAITING ||
               (target.state == Process::State::STALE && config.auto_reactivate_processes))
              # Check if the message matches what the process is waiting for
              if target.waiting_for.nil? ||
                 target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
                queue_process_for_reactivation(target)
              end
            end
          end
        end

        # Remove delivered messages
        @delayed_messages.reject! { |time, _, _, _| time <= now }

        messages_delivered
      end

      # Run the VM engine with improved concurrency and deadlock handling
      def run
        iterations = 0
        completed_processes = Set(UInt64).new

        loop do
          iterations += 1
          if iterations >= config.iteration_limit
            Log.warn { "Engine run exceeded iteration limit (#{config.iteration_limit})" }
            break
          end

          # Check for breakpoints
          check_breakpoints

          # Process delayed messages
          delayed_delivered = deliver_delayed_messages

          # Clean up expired messages periodically
          now = Time.utc
          if now - last_cleanup_time > config.message_cleanup_interval
            process_manager.cleanup_expired_messages
            last_cleanup_time = now
          end

          # Find processes in different states
          active_processes = process_manager.active_processes(completed_processes)
          waiting_processes = process_manager.waiting_processes_ready(completed_processes)
          timeout_processes = process_manager.processes_with_expired_timeouts(completed_processes)
          blocked_processes = process_manager.blocked_processes_ready(completed_processes)

          # Process queued reactivations
          reactivation_queue.each do |process|
            process.state = Process::State::ALIVE
          end
          progress_made = !reactivation_queue.empty?
          reactivation_queue.clear

          # Execute instructions for active processes first
          progress_made |= process_manager.execute_active_processes(active_processes, completed_processes)

          # Handle processes with expired timeouts
          progress_made |= process_manager.handle_timeout_processes(timeout_processes)

          # Reactivate waiting processes that now have messages
          progress_made |= process_manager.reactivate_waiting_processes(waiting_processes)

          # Unblock processes waiting on full mailboxes
          progress_made |= process_manager.unblock_blocked_processes(blocked_processes)

          # Check for deadlock if no progress was made
          if !progress_made && !delayed_delivered && process_manager.detect_deadlock
            Log.warn { "Deadlock detected - terminating execution" }

            if config.deadlock_detection
              # Mark all waiting processes as dead and raise an exception
              processes.each do |p|
                if p.state == Process::State::WAITING || p.state == Process::State::STALE || p.state == Process::State::BLOCKED
                  p.state = Process::State::DEAD
                  completed_processes.add(p.address)
                end
              end

              raise DeadlockException.new("Deadlock detected - terminating execution")
            end

            break
          end

          # Update process states based on completion
          process_manager.update_process_states(completed_processes)

          # Check if all processes are done
          if processes.empty? || processes.all? { |p| p.state == Process::State::DEAD }
            Log.info { "All processes completed" }
            break
          end

          Fiber.yield
          sleep config.execution_delay
        end

        log_final_status(iterations)
      end

      # Check if any breakpoints are triggered
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

      # Logs final VM execution status
      private def log_final_status(iterations : Int32)
        Log.info { "VM execution completed after #{iterations} iterations" }

        processes.each do |p|
          Log.info { "Process <#{p.address}> final state: #{p.state}, counter: #{p.counter}" }
          if !p.mailbox.empty?
            Log.info { "Process <#{p.address}> has #{p.mailbox.size} unprocessed messages" }
          end
        end

        # Dump detailed state for debugging
        Log.debug { "Final VM state: #{process_manager.dump_state}" }
      end

      # Get detailed information about a process
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
        }.to_json
      end
    end
  end
end
