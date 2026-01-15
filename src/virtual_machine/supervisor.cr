module Jelly
  module VirtualMachine
    # Supervisor manages a set of child processes according to a restart strategy
    class Supervisor
      Log = ::Log.for(self)

      # Supervision strategy determines how to handle child failures
      enum RestartStrategy
        OneForOne       # Only restart the failed child
        OneForAll       # Restart all children when one fails
        RestForOne      # Restart the failed child and all children started after it
        SimpleOneForOne # Like one_for_one but for dynamic children with same spec
      end

      # Restart type for individual children
      enum RestartType
        Permanent # Always restart
        Transient # Restart only on abnormal exit
        Temporary # Never restart
      end

      # Shutdown behavior for children
      enum ShutdownType
        Brutal   # Kill immediately
        Timeout  # Wait for graceful shutdown with timeout
        Infinity # Wait forever for graceful shutdown
      end

      module Child
        # Child specification for supervisor
        class Specification
          property id : String
          property instructions : Array(Instruction)
          property subroutines : Hash(String, Subroutine)
          property globals : Hash(String, Value)
          property restart : RestartType
          property shutdown : ShutdownType
          property shutdown_timeout : Time::Span
          property max_restarts : Int32
          property restart_window : Time::Span

          def initialize(
            @id : String,
            @instructions : Array(Instruction),
            @subroutines : Hash(String, Subroutine) = {} of String => Subroutine,
            @globals : Hash(String, Value) = {} of String => Value,
            @restart : RestartType = RestartType::Permanent,
            @shutdown : ShutdownType = ShutdownType::Timeout,
            @shutdown_timeout : Time::Span = 5.seconds,
            @max_restarts : Int32 = 3,
            @restart_window : Time::Span = 5.seconds,
          )
          end

          def clone : Specification
            Specification.new(
              id: @id,
              instructions: @instructions.map(&.clone),
              subroutines: @subroutines.dup,
              globals: @globals.transform_values(&.clone),
              restart: @restart,
              shutdown: @shutdown,
              shutdown_timeout: @shutdown_timeout,
              max_restarts: @max_restarts,
              restart_window: @restart_window
            )
          end
        end
      end

      # Tracks restart history for a child
      class RestartHistory
        property restarts : Array(Time)
        property specification : Child::Specification

        def initialize(@specification : Child::Specification)
          @restarts = [] of Time
        end

        # Record a restart and check if we've exceeded the limit
        def record_restart : Bool
          now = Time.utc

          # Remove old restarts outside the window
          cutoff = now - @specification.restart_window
          @restarts.reject! { |t| t < cutoff }

          # Add new restart
          @restarts << now

          # Check if we've exceeded the limit
          @restarts.size <= @specification.max_restarts
        end

        def restart_count : Int32
          now = Time.utc
          cutoff = now - @specification.restart_window
          @restarts.count { |t| t >= cutoff }
        end

        def clear
          @restarts.clear
        end
      end

      getter address : UInt64
      getter strategy : RestartStrategy
      getter max_restarts : Int32
      getter restart_window : Time::Span
      getter children : Array(Tuple(Child::Specification, UInt64?)) # (specification, current_pid)
      getter restart_histories : Hash(String, RestartHistory)

      @engine : Engine
      @start_order : Array(String) # Track order for RestForOne

      def initialize(
        @engine : Engine,
        @address : UInt64,
        @strategy : RestartStrategy = RestartStrategy::OneForOne,
        @max_restarts : Int32 = 3,
        @restart_window : Time::Span = 5.seconds,
      )
        @children = [] of Tuple(Child::Specification, UInt64?)
        @restart_histories = {} of String => RestartHistory
        @start_order = [] of String
      end

      # Add a child specification
      def add_child(specification : Child::Specification) : UInt64?
        @restart_histories[specification.id] = RestartHistory.new(specification)

        # Start the child
        pid = start_child(specification)

        if pid
          @children << {specification, pid}
          @start_order << specification.id
          Log.info { "Supervisor <#{@address}>: Started child '#{specification.id}' as <#{pid}>" }
        else
          @children << {specification, nil}
          Log.error { "Supervisor <#{@address}>: Failed to start child '#{specification.id}'" }
        end

        pid
      end

      # Start a child process from its specification
      private def start_child(specification : Child::Specification) : UInt64?
        begin
          process = @engine.process_manager.create_process(
            instructions: specification.instructions.map(&.clone)
          )

          # Copy subroutines and globals
          specification.subroutines.each { |name, subroutine| process.subroutines[name] = subroutine }
          specification.globals.each { |name, value| process.globals[name] = value.clone }

          # Link supervisor to child
          @engine.process_links.link(@address, process.address)

          # Register the process
          @engine.processes << process

          process.address
        rescue ex
          Log.error { "Failed to start child '#{specification.id}': #{ex.message}" }
          nil
        end
      end

      # Handle a child exit
      def handle_child_exit(pid : UInt64, reason : Process::ExitReason) : Bool
        # Find the child
        child_index = @children.index { |(specification, current_pid)| current_pid == pid }
        return false unless child_index

        specification, _ = @children[child_index]
        @children[child_index] = {specification, nil}

        Log.info { "Supervisor <#{@address}>: Child '#{specification.id}' <#{pid}> exited: #{reason.type}" }

        # Determine if we should restart
        should_restart = case specification.restart
                         when .permanent?
                           true
                         when .transient?
                           !reason.normal?
                         when .temporary?
                           false
                         else
                           false
                         end

        unless should_restart
          Log.debug { "Supervisor <#{@address}>: Not restarting '#{specification.id}' (restart=#{specification.restart}, reason=#{reason.type})" }
          return true
        end

        # Check restart limits
        history = @restart_histories[specification.id]
        unless history.record_restart
          Log.error { "Supervisor <#{@address}>: Child '#{specification.id}' exceeded restart limit (#{specification.max_restarts} in #{specification.restart_window})" }
          handle_restart_limit_exceeded(specification.id)
          return false
        end

        # Apply restart strategy
        case @strategy
        when .one_for_one?, .simple_one_for_one?
          restart_one(child_index)
        when .one_for_all?
          restart_all
        when .rest_for_one?
          restart_from(child_index)
        end

        true
      end

      # Restart a single child
      private def restart_one(index : Int32)
        specification, _ = @children[index]

        if new_pid = start_child(specification)
          @children[index] = {specification, new_pid}
          Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_pid}>" }
        else
          Log.error { "Supervisor <#{@address}>: Failed to restart child '#{specification.id}'" }
        end
      end

      # Restart all children (for one_for_all strategy)
      private def restart_all
        Log.info { "Supervisor <#{@address}>: Restarting all children" }

        # Stop all children in reverse order
        @children.reverse_each do |(specification, pid)|
          if pid
            terminate_child(pid, specification)
          end
        end

        # Clear current pids
        @children = @children.map { |(specification, _)| {specification, nil.as(UInt64?)} }

        # Restart all in original order
        @children.each_with_index do |(specification, _), i|
          if new_pid = start_child(specification)
            @children[i] = {specification, new_pid}
            Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_pid}>" }
          end
        end
      end

      # Restart from a specific index (for rest_for_one strategy)
      private def restart_from(start_index : Int32)
        Log.info { "Supervisor <#{@address}>: Restarting children from index #{start_index}" }

        # Stop children from start_index to end in reverse order
        ((start_index...@children.size).to_a.reverse).each do |i|
          specification, pid = @children[i]
          if pid
            terminate_child(pid, specification)
          end
          @children[i] = {specification, nil}
        end

        # Restart from start_index to end
        (start_index...@children.size).each do |i|
          specification, _ = @children[i]
          if new_pid = start_child(specification)
            @children[i] = {specification, new_pid}
            Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_pid}>" }
          end
        end
      end

      # Terminate a child process
      private def terminate_child(pid : UInt64, specification : Child::Specification)
        process = @engine.processes.find { |p| p.address == pid }
        return unless process

        case specification.shutdown
        when .brutal?
          process.state = Process::State::DEAD
          process.exit_reason = Process::ExitReason.kill
        when .timeout?
          # Send shutdown signal and wait
          signal_shutdown(process)
          wait_for_exit(process, specification.shutdown_timeout)
        when .infinity?
          signal_shutdown(process)
          # Wait forever (or until process dies)
          while process.state != Process::State::DEAD
            sleep 10.milliseconds
          end
        end

        Log.debug { "Supervisor <#{@address}>: Terminated child '#{specification.id}' <#{pid}>" }
      end

      # Signal a process to shut down gracefully
      private def signal_shutdown(process : Process)
        # Send a shutdown message
        message = Message.new(
          @address,
          Value.new({
            "signal" => Value.new("shutdown"),
            "from"   => Value.new(@address.to_i64),
          } of String => Value)
        )
        process.mailbox.push(message)
      end

      # Wait for a process to exit with timeout
      private def wait_for_exit(process : Process, timeout : Time::Span)
        deadline = Time.utc + timeout
        while process.state != Process::State::DEAD && Time.utc < deadline
          sleep 10.milliseconds
        end

        # Force kill if still alive
        if process.state != Process::State::DEAD
          process.state = Process::State::DEAD
          process.exit_reason = Process::ExitReason.kill
        end
      end

      # Handle when a child exceeds its restart limit
      private def handle_restart_limit_exceeded(child_id : String)
        case @strategy
        when .one_for_one?, .simple_one_for_one?
          # Just log, child remains dead
          Log.warn { "Supervisor <#{@address}>: Child '#{child_id}' will not be restarted" }
        when .one_for_all?, .rest_for_one?
          # Supervisor itself should fail
          Log.error { "Supervisor <#{@address}>: Shutting down due to restart limit exceeded" }
          shutdown
        end
      end

      # Shut down the supervisor and all children
      def shutdown
        Log.info { "Supervisor <#{@address}>: Shutting down" }

        @children.reverse_each do |(specification, pid)|
          if pid
            terminate_child(pid, specification)
          end
        end

        @children.clear
        @restart_histories.clear
        @start_order.clear
      end

      # Get the pid of a child by id
      def whereis(child_id : String) : UInt64?
        @children.find { |(specification, _)| specification.id == child_id }.try { |(_, pid)| pid }
      end

      # Get count of running children
      def running_children : Int32
        @children.count { |(_, pid)| pid != nil }
      end

      # Get status of all children
      def child_status : Array(NamedTuple(id: String, pid: UInt64?, restarts: Int32))
        @children.map do |(specification, pid)|
          history = @restart_histories[specification.id]?
          {
            id:       specification.id,
            pid:      pid,
            restarts: history.try(&.restart_count) || 0,
          }
        end
      end
    end

    # Registry for supervisors
    class SupervisorRegistry
      @supervisors : Hash(UInt64, Supervisor)
      @mutex : Mutex

      def initialize
        @supervisors = {} of UInt64 => Supervisor
        @mutex = Mutex.new
      end

      def register(supervisor : Supervisor)
        @mutex.synchronize do
          @supervisors[supervisor.address] = supervisor
        end
      end

      def unregister(address : UInt64)
        @mutex.synchronize do
          @supervisors.delete(address)
        end
      end

      def get(address : UInt64) : Supervisor?
        @mutex.synchronize do
          @supervisors[address]?
        end
      end

      def find_supervisor_of(pid : UInt64) : Supervisor?
        @mutex.synchronize do
          @supervisors.values.find do |sup|
            sup.children.any? { |(_, child_pid)| child_pid == pid }
          end
        end
      end

      def all : Array(Supervisor)
        @mutex.synchronize do
          @supervisors.values.dup
        end
      end
    end
  end
end
