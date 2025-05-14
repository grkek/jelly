module Jelly
  module VirtualMachine
    class ProcessManager
      Log = ::Log.for(self)

      # Class-level variable to track the next process address
      @@next_address : UInt64 = 1
      @@address_mutex = Mutex.new

      def initialize(@engine : Engine)
      end

      # Creates a new process with an incrementally assigned address
      def create_process : Process
        address = @@address_mutex.synchronize do
          addr = @@next_address
          @@next_address += 1
          addr
        end
        process = Process.new(address)
        @engine.processes << process
        Log.debug { "Created new Process <#{address}>" }
        process
      end

      # Returns active processes that haven't completed
      def active_processes(completed_processes : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::ALIVE &&
            p.counter < @engine.instructions.size &&
            !completed_processes.includes?(p.address)
        end
      end

      # Returns waiting processes that can be reactivated
      def waiting_processes_ready(completed_processes : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          (p.state == Process::State::WAITING || p.state == Process::State::STALE) &&
            !p.mailbox.empty? &&
            !completed_processes.includes?(p.address) &&
            (p.waiting_for.nil? ||
             p.mailbox.messages.any? { |msg| p.mailbox.matches_pattern?(msg.value, p.waiting_for.not_nil!) })
        end
      end

      # Returns processes with expired timeouts
      def processes_with_expired_timeouts(completed_processes : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::WAITING &&
            p.wait_timed_out? &&
            !completed_processes.includes?(p.address)
        end
      end

      # Returns blocked processes that can be unblocked
      def blocked_processes_ready(completed_processes : Set(UInt64)) : Array(Process)
        result = [] of Process

        @engine.processes.each do |p|
          next if p.state != Process::State::BLOCKED || completed_processes.includes?(p.address)

          # Check if any of the target mailboxes now have space
          can_unblock = p.blocked_sends.any? do |target_address, _|
            target = @engine.processes.find { |t| t.address == target_address }
            target && target.mailbox.size < @engine.config.max_mailbox_size
          end

          result << p if can_unblock
        end

        result
      end

      # Executes instructions for active processes
      def execute_active_processes(
        active_processes : Array(Process),
        completed_processes : Set(UInt64),
      ) : Bool
        progress_made = false

        active_processes.each do |process|
          initial_counter = process.counter
          instruction_count = 0

          max_instructions = @engine.config.max_instructions_per_cycle
          while process.state == Process::State::ALIVE &&
                process.counter < @engine.instructions.size &&
                instruction_count < max_instructions &&
                !completed_processes.includes?(process.address)
            current_instruction = @engine.instructions[process.counter]
            Log.debug { "Process <#{process.address}> executing: #{current_instruction.code} at #{process.counter}" }
            @engine.executor.execute(process, current_instruction)
            instruction_count += 1

            # Mark process as completed if it hits top-level RETURN
            if current_instruction.code == Code::RETURN && process.call_stack.empty?
              Log.info { "Process <#{process.address}> completed execution (top-level RETURN)" }
              completed_processes.add(process.address)
              break
            end
          end

          # Check if process made progress
          progress_made = true if process.counter > initial_counter
        end

        progress_made
      end

      # Reactivates waiting processes that have matching messages
      def reactivate_waiting_processes(waiting_processes : Array(Process)) : Bool
        progress_made = false

        waiting_processes.each do |process|
          Log.info { "Reactivating waiting Process <#{process.address}> which has matching messages" }
          process.state = Process::State::ALIVE

          # Find the receive instruction
          if process.counter < @engine.instructions.size
            instruction = @engine.instructions[process.counter]

            # Only execute if it's a receive-related instruction
            if [Code::RECEIVE, Code::RECEIVE_SELECT, Code::RECEIVE_TIMEOUT].includes?(instruction.code)
              @engine.executor.execute(process, instruction)
              progress_made = true
            end
          end
        end

        progress_made
      end

      # Handles processes with expired timeouts
      def handle_timeout_processes(timeout_processes : Array(Process)) : Bool
        progress_made = false

        timeout_processes.each do |process|
          Log.info { "Process <#{process.address}> receive timeout expired" }
          process.state = Process::State::ALIVE

          # Push timeout indicator and continue execution
          process.stack.push(Value.new(false)) # false indicates timeout
          progress_made = true
        end

        progress_made
      end

      # Unblocks processes that were waiting for mailbox space
      def unblock_blocked_processes(blocked_processes : Array(Process)) : Bool
        progress_made = false

        blocked_processes.each do |process|
          Log.info { "Attempting to unblock Process <#{process.address}>" }

          # Try to send blocked messages
          still_blocked = [] of Tuple(UInt64, Message)

          process.blocked_sends.each do |target_address, message|
            target = @engine.processes.find { |t| t.address == target_address }

            if target && target.mailbox.size < @engine.config.max_mailbox_size
              if target.mailbox.push(message)
                Log.debug { "Successfully sent blocked message from <0.#{process.address}> to <0.#{target.address}>" }
                process.remove_dependency(target.address)

                # Send ack if needed
                if message.needs_ack && @engine.config.enable_message_acks
                  ack = MessageAcknowledgment.new(message.id, target.address, :delivered)
                  process.mailbox.add_ack(ack)
                end

                # Queue target for reactivation if waiting
                if (target.state == Process::State::WAITING ||
                   (target.state == Process::State::STALE && @engine.config.auto_reactivate_processes))
                  # Check if the message matches what the process is waiting for
                  if target.waiting_for.nil? ||
                     target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
                    @engine.queue_process_for_reactivation(target)
                  end
                end
              else
                still_blocked << {target_address, message}
              end
            else
              still_blocked << {target_address, message}
            end
          end

          # Update blocked sends
          process.blocked_sends = still_blocked

          # Reactivate process if all sends were successful
          if process.blocked_sends.empty?
            process.state = Process::State::ALIVE
            progress_made = true
          end
        end

        progress_made
      end

      # Enhanced deadlock detection with dependency graph analysis
      def detect_deadlock : Bool
        return false unless @engine.config.deadlock_detection

        # Basic deadlock check - all processes waiting at RECEIVE
        receive_processes = @engine.processes.select do |p|
          p.state == Process::State::WAITING ||
          (p.state == Process::State::STALE &&
           p.counter < @engine.instructions.size &&
           [Code::RECEIVE, Code::RECEIVE_SELECT, Code::RECEIVE_TIMEOUT].includes?(@engine.instructions[p.counter].code))
        end

        if receive_processes.size == @engine.processes.size && !@engine.processes.empty?
          Log.warn { "Basic deadlock detected: all processes waiting for messages" }
          return true
        end

        # Advanced deadlock detection using process dependencies
        waited_upon = Set(UInt64).new
        @engine.processes.each do |p|
          p.dependencies.each do |dep|
            waited_upon.add(dep)
          end
        end

        # Check for circular dependencies
        cycles = detect_dependency_cycles

        if !cycles.empty?
          Log.warn { "Advanced deadlock detected: dependency cycles found: #{cycles}" }
          return true
        end

        false
      end

      # Detect cycles in the process dependency graph
      private def detect_dependency_cycles : Array(Array(UInt64))
        cycles = [] of Array(UInt64)
        visited = Set(UInt64).new
        stack = Set(UInt64).new

        @engine.processes.each do |process|
          if !visited.includes?(process.address)
            detect_cycles_dfs(process.address, visited, stack, [] of UInt64, cycles)
          end
        end

        cycles
      end

      # DFS to detect cycles
      private def detect_cycles_dfs(
        current : UInt64,
        visited : Set(UInt64),
        stack : Set(UInt64),
        path : Array(UInt64),
        cycles : Array(Array(UInt64))
      )
        visited.add(current)
        stack.add(current)
        path.push(current)

        # Get the current process
        process = @engine.processes.find { |p| p.address == current }
        return unless process # Process might have been removed

        process.dependencies.each do |dep|
          if !visited.includes?(dep)
            detect_cycles_dfs(dep, visited, stack, path.clone, cycles)
          elsif stack.includes?(dep)
            # Found a cycle
            cycle_start_idx = path.index(dep)
            if cycle_start_idx
              cycle = path[cycle_start_idx..-1]
              cycles << cycle
            end
          end
        end

        stack.delete(current)
      end

      # Updates process states based on completion status
      def update_process_states(completed_processes : Set(UInt64))
        @engine.processes.each do |p|
          if completed_processes.includes?(p.address)
            p.state = Process::State::DEAD

            # Unregister from registry if registered
            if name = p.registered_name
              @engine.process_registry.unregister(name)
            end
          end
        end
      end

      # Cleanup expired messages from all mailboxes
      def cleanup_expired_messages : Int32
        return 0 unless @engine.config.cleanup_expired_messages

        total_cleaned = 0
        @engine.processes.each do |process|
          cleaned = process.mailbox.cleanup_expired
          total_cleaned += cleaned
          if cleaned > 0
            Log.debug { "Cleaned #{cleaned} expired messages from Process <#{process.address}>" }
          end
        end

        total_cleaned
      end

      # Dumps the current state for debugging
      def dump_state : String
        {
          processes: @engine.processes.map { |p|
            {
              address: p.address,
              state: p.state.to_s,
              counter: p.counter,
              mailbox_size: p.mailbox.size,
              blocked_sends: p.blocked_sends.size,
              dependencies: p.dependencies.to_a,
            }
          },
          next_address: @@next_address,
        }.to_json
      end
    end
  end
end
