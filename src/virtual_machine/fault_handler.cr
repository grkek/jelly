module Jelly
  module VirtualMachine
    # Central handler for process faults and exit propagation
    class FaultHandler
      Log = ::Log.for(self)

      @engine : Engine
      @pending_signals : Channel(Tuple(UInt64, Process::ExitSignal))
      @running : Bool

      def initialize(@engine : Engine)
        @pending_signals = Channel(Tuple(UInt64, Process::ExitSignal)).new(1000)
        @running = false
      end

      # Start the fault handler in a fiber
      def start
        return if @running
        @running = true

        spawn do
          Log.debug { "Monitoring for signal handlers" }
          while @running
            begin
              select
              when signal = @pending_signals.receive
                target_pid, exit_signal = signal
                deliver_signal(target_pid, exit_signal)
              when timeout(100.milliseconds)
                # Check for any cleanup needed
              end
            rescue Channel::ClosedError
              break
            end
          end
          Log.debug { "Demonitoring the signal handlers" }
        end
      end

      # Stop the fault handler
      def stop
        @running = false
        @pending_signals.close
      end

      # Handle a process exit - propagate signals to linked/monitoring processes
      def handle_exit(process : Process, reason : Process::ExitReason)
        Log.info { "FaultHandler: Process <#{process.address}> exited: #{reason.type}" }

        # Store exit reason on process
        process.exit_reason = reason

        # Get linked processes and monitors
        linked, monitors = @engine.process_links.cleanup(process.address)

        # Send exit signals to linked processes
        linked.each do |linked_pid|
          signal = Process::ExitSignal.new(process.address, reason, Process::ExitSignal::LinkType::Link)
          queue_signal(linked_pid, signal)
        end

        # Send DOWN messages to monitoring processes
        monitors.each do |ref|
          down = Process::DownMessage.new(ref, process.address, reason)
          deliver_down_message(ref.watcher, down)
        end

        # Notify supervisor if any
        notify_supervisor(process.address, reason)

        # Unregister from process registry
        if name = process.registered_name
          @engine.process_registry.unregister(name)
        end
      end

      # Queue a signal for delivery
      private def queue_signal(target_pid : UInt64, signal : Process::ExitSignal)
        begin
          @pending_signals.send({target_pid, signal})
        rescue Channel::ClosedError
          Log.warn { "FaultHandler: Cannot queue signal, channel closed" }
        end
      end

      # Deliver a signal to a process
      private def deliver_signal(target_pid : UInt64, signal : Process::ExitSignal)
        process = @engine.processes.find { |p| p.address == target_pid }
        return unless process
        return if process.state == Process::State::DEAD

        Log.debug { "FaultHandler: Delivering exit signal to <#{target_pid}> from <#{signal.from}>" }

        # Check if process traps exits
        if @engine.process_links.traps_exit?(target_pid) && signal.reason.trappable?
          # Convert signal to message
          message = Message.new(signal.from, signal.to_value)
          process.mailbox.push(message)

          # Wake up if waiting
          if process.state == Process::State::WAITING
            @engine.queue_process_for_reactivation(process)
          end

          Log.debug { "FaultHandler: Process <#{target_pid}> trapped exit signal" }
        else
          # Kill the process
          process.state = Process::State::DEAD
          process.exit_reason = signal.reason

          Log.debug { "FaultHandler: Process <#{target_pid}> killed by exit signal" }

          # Recursively handle this process's exit
          handle_exit(process, signal.reason)
        end
      end

      # Deliver a DOWN message to a monitoring process
      private def deliver_down_message(target_pid : UInt64, down : Process::DownMessage)
        process = @engine.processes.find { |p| p.address == target_pid }
        return unless process
        return if process.state == Process::State::DEAD

        message = Message.new(down.process, down.to_value)
        process.mailbox.push(message)

        # Wake up if waiting
        if process.state == Process::State::WAITING
          @engine.queue_process_for_reactivation(process)
        end

        Log.debug { "FaultHandler: Delivered DOWN message to <#{target_pid}>" }
      end

      # Notify supervisor of child exit
      private def notify_supervisor(pid : UInt64, reason : Process::ExitReason)
        if supervisor = @engine.supervisor_registry.find_supervisor_of(pid)
          supervisor.handle_child_exit(pid, reason)
        end
      end

      # Kill a process with a specific reason
      def kill_process(pid : UInt64, reason : Process::ExitReason)
        process = @engine.processes.find { |p| p.address == pid }
        return unless process
        return if process.state == Process::State::DEAD

        process.state = Process::State::DEAD
        handle_exit(process, reason)
      end

      # Send an exit signal to a process (like Erlang's exit/2)
      def exit_process(from : UInt64, to : UInt64, reason : Process::ExitReason)
        signal = Process::ExitSignal.new(from, reason, Process::ExitSignal::LinkType::Link)
        queue_signal(to, signal)
      end
    end

    # Error recovery strategies
    module Recovery
      # Attempt to recover a process that crashed
      def self.try_recover(engine : Engine, process : Process, exception : Exception) : Bool
        Log.for(self).debug { "Attempting recovery for <#{process.address}>: #{exception.message}" }

        # Check if process has an error handler subroutine
        if error_handler = process.subroutines["__error_handler__"]?
          begin
            # Push error info onto stack
            error_value = Value.new({
              "type"    => Value.new("exception"),
              "message" => Value.new(exception.message || "unknown"),
              "counter" => Value.new(process.counter.to_i64),
            } of String => Value)

            process.stack.push(error_value)

            # Jump to error handler
            process.call_stack.push(process.counter)
            process.counter = error_handler.start_address
            process.state = Process::State::ALIVE

            Log.for(self).info { "Process <#{process.address}> recovered with error handler" }
            return true
          rescue
            Log.for(self).warn { "Error handler failed for <#{process.address}>" }
          end
        end

        false
      end

      # Create a crash dump for debugging
      def self.create_crash_dump(process : Process, reason : Process::ExitReason) : CrashDump
        CrashDump.new(process, reason)
      end
    end

    # Crash dump for post-mortem debugging
    class CrashDump
      getter process_address : UInt64
      getter registered_name : String?
      getter exit_reason : Process::ExitReason
      getter stack_trace : Array(Value)
      getter call_stack : Array(UInt64)
      getter counter : UInt64
      getter locals : Array(Value)
      getter mailbox_size : Int32
      getter timestamp : Time

      def initialize(process : Process, @exit_reason : Process::ExitReason)
        @process_address = process.address
        @registered_name = process.registered_name
        @stack_trace = process.stack.map(&.clone)
        @call_stack = process.call_stack.dup
        @counter = process.counter
        @locals = process.locals.map(&.clone)
        @mailbox_size = process.mailbox.size
        @timestamp = Time.utc
      end

      def to_s : String
        String.build do |str|
          str << "=== CRASH DUMP ===\n"
          str << "Process: <#{@process_address}>"
          str << " (#{@registered_name})" if @registered_name
          str << "\n"
          str << "Time: #{@timestamp}\n"
          str << "Exit Reason: #{@exit_reason}\n"
          str << "Counter: #{@counter}\n"
          str << "Stack Size: #{@stack_trace.size}\n"
          str << "Call Stack: #{@call_stack.inspect}\n"
          str << "Locals: #{@locals.size}\n"
          str << "Mailbox Size: #{@mailbox_size}\n"

          if @stack_trace.any?
            str << "\nStack (top 10):\n"
            @stack_trace.last(10).reverse_each.with_index do |val, i|
              str << "  #{i}: #{val.inspect}\n"
            end
          end

          if @exit_reason.stacktrace.any?
            str << "\nException Stacktrace:\n"
            @exit_reason.stacktrace.first(20).each do |line|
              str << "  #{line}\n"
            end
          end

          str << "=== END CRASH DUMP ===\n"
        end
      end
    end

    # Crash dump storage
    class CrashDumpStorage
      @dumps : Array(CrashDump)
      @max_dumps : Int32
      @mutex : Mutex

      def initialize(@max_dumps : Int32 = 100)
        @dumps = [] of CrashDump
        @mutex = Mutex.new
      end

      def store(dump : CrashDump)
        @mutex.synchronize do
          @dumps << dump
          while @dumps.size > @max_dumps
            @dumps.shift
          end
        end
      end

      def get(address : UInt64) : CrashDump?
        @mutex.synchronize do
          @dumps.find { |d| d.process_address == address }
        end
      end

      def all : Array(CrashDump)
        @mutex.synchronize do
          @dumps.dup
        end
      end

      def recent(n : Int32 = 10) : Array(CrashDump)
        @mutex.synchronize do
          @dumps.last(n)
        end
      end

      def clear
        @mutex.synchronize do
          @dumps.clear
        end
      end
    end
  end
end
