module Jelly
  module VirtualMachine
    # Manages creation and scheduling of processes
    class ProcessManager
      Log = ::Log.for(self)

      # Next available process address
      @next_address : UInt64 = 1_u64

      def initialize(@engine : Engine)
      end

      # Create a new process with its own instruction list
      # This enables true isolation: each process runs different code
      def create_process(
        instructions : Array(Instruction) = [] of Instruction,
        start_address : UInt64 = 0_u64,
      ) : Process
        process = Process.new(@next_address, instructions)
        @next_address += 1
        process.counter = start_address
        Log.debug { "Created new Process <#{process.address}>" }
        process
      end

      # All currently runnable processes
      def active_processes(exclude : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::ALIVE && !exclude.includes?(p.address)
        end
      end

      # Waiting processes that now have matching messages
      def waiting_processes_ready(exclude : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::WAITING &&
            !p.mailbox.empty? &&
            !exclude.includes?(p.address)
        end
      end

      # Waiting processes whose timeout has expired
      def processes_with_expired_timeouts(exclude : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::WAITING &&
            p.wait_timed_out? &&
            !exclude.includes?(p.address)
        end
      end

      # Blocked processes that might now be able to send
      def blocked_processes_ready(exclude : Set(UInt64)) : Array(Process)
        @engine.processes.select do |p|
          p.state == Process::State::BLOCKED &&
            p.blocked_sends.any? &&
            !exclude.includes?(p.address)
        end
      end

      # Execute one instruction per active process (fair scheduling)
      def execute_active_processes(active : Array(Process), completed : Set(UInt64)) : Bool
        progress = false

        active.each do |process|
          # Safety check: prevent out-of-bounds access
          if process.counter >= process.instructions.size
            process.state = Process::State::DEAD
            completed.add(process.address)
            next
          end

          instruction = process.instructions[process.counter]
          @engine.execute(process, instruction)
          progress = true

          if process.state == Process::State::DEAD
            completed.add(process.address)
          end

          Log.debug do
            "Process <#{process.address}> executed #{instruction.code} @ #{process.counter} → #{process.state}"
          end
        end

        progress
      end

      # Resume processes that timed out on receive
      def handle_timeout_processes(timeouts : Array(Process)) : Bool
        return false if timeouts.empty?

        timeouts.each do |p|
          Log.debug { "Process <#{p.address}> RECEIVE timeout expired" }
          p.state = Process::State::ALIVE
          p.waiting_for = nil
          p.waiting_since = nil
          p.waiting_timeout = nil
          p.stack.push(Value.new(false)) # Indicate timeout
          @engine.queue_process_for_reactivation(p)
        end

        true
      end

      # Reactivate waiting processes that received messages
      def reactivate_waiting_processes(waiting : Array(Process)) : Bool
        return false if waiting.empty?

        waiting.each do |p|
          Log.debug { "Reactivating Process <#{p.address}> due to new message" }
          p.state = Process::State::ALIVE
          p.waiting_for = nil
          p.waiting_since = nil
          p.waiting_timeout = nil
          @engine.queue_process_for_reactivation(p)
        end

        true
      end

      # Unblock processes that were blocked on full mailboxes
      def unblock_blocked_processes(blocked : Array(Process)) : Bool
        return false if blocked.empty?

        blocked.each do |p|
          Log.debug { "Unblocking Process <#{p.address}> (mailbox has space)" }
          p.state = Process::State::ALIVE
          # Note: actual resend happens in Engine#check_blocked_sends
          @engine.queue_process_for_reactivation(p)
        end

        true
      end

      # Mark processes that reached end of code as dead
      def update_process_states(completed : Set(UInt64))
        @engine.processes.each do |p|
          if p.counter >= p.instructions.size && p.state == Process::State::ALIVE
            Log.debug { "Process <#{p.address}> reached end of code" }
            p.state = Process::State::DEAD
            completed.add(p.address)
          end
        end
      end

      def cleanup_expired_messages
        removed_total = 0
        @engine.processes.each do |p|
          removed = p.mailbox.cleanup_expired_messages
          removed_total += removed if removed > 0
        end
        Log.debug { "Cleaned up #{removed_total} expired messages across all mailboxes" } if removed_total > 0
      end

      # Proper deadlock detection using wait-for graph + cycle detection
      # Proper deadlock detection using wait-for graph + cycle detection
      def detect_deadlock : Bool
        # Build directed graph: A → B means "A is waiting for B"
        graph = Hash(UInt64, Set(UInt64)).new { |h, k| h[k] = Set(UInt64).new }

        @engine.processes.each do |p|
          next unless p.state.waiting?

          p.dependencies.each do |target_address|
            graph[p.address] << target_address
          end
        end

        return false if graph.empty?

        visited = Set(UInt64).new
        recursion_stack = Set(UInt64).new

        # Use a block + local variable to avoid any shadowing issues
        detect_cycle = uninitialized Proc(UInt64, Bool)

        detect_cycle = ->(node : UInt64) : Bool do
          visited.add(node)
          recursion_stack.add(node)

          graph[node].each do |neighbor|
            unless visited.includes?(neighbor)
              return true if detect_cycle.call(neighbor)
            else
              if recursion_stack.includes?(neighbor)
                Log.warn { "Deadlock cycle detected: Process <#{node}> is waiting on <#{neighbor}>" }
                return true
              end
            end
          end

          recursion_stack.delete(node)
          false
        end

        graph.keys.each do |node|
          next if visited.includes?(node)
          return true if detect_cycle.call(node)
        end

        false
      end

      # Debug helper: dump current VM state
      def dump_state : String
        {
          processes: @engine.processes.map { |p|
            {
              address:         p.address,
              state:           p.state.to_s,
              counter:         p.counter,
              code_size:       p.instructions.size,
              stack_size:      p.stack.size,
              mailbox_size:    p.mailbox.size,
              blocked_sends:   p.blocked_sends.size,
              registered_name: p.registered_name,
            }
          },
          next_address: @next_address,
        }.to_pretty_json
      end
    end
  end
end
