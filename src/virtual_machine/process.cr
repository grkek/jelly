module Jelly
  module VirtualMachine
    class Process
      enum State
        ALIVE
        STALE
        WAITING # Waiting for messages
        BLOCKED # Blocked on full mailboxes
        DEAD

        def waiting? : Bool
          self == WAITING || self == BLOCKED
        end

        def runnable? : Bool
          self == ALIVE
        end
      end

      # Core process properties
      property address : UInt64
      property state : State
      property counter : UInt64
      property stack : Array(Value)
      property mailbox : Mailbox
      property call_stack : Array(UInt64)
      property frame_pointer : Int32
      property locals : Array(Value)

      # Waiting state
      property waiting_for : Value?
      property waiting_since : Time?
      property waiting_timeout : Time::Span?
      property waiting_message_id : UInt64?
      property blocked_sends : Array(Tuple(UInt64, Message))

      # Process identification
      property registered_name : String?
      property dependencies : Set(UInt64)

      # Program and data
      property instructions : Array(Instruction)
      property subroutines : Hash(String, Subroutine) = {} of String => Subroutine
      property globals : Hash(String, Value) = {} of String => Value

      # === NEW: Fault tolerance properties ===

      # Exit reason when process terminates
      property exit_reason : ExitReason?

      # Exception handlers stack for try-catch
      property exception_handlers : Array(ExceptionHandler)

      # Current exception being handled (if any)
      property current_exception : Exception?

      # Process flags (like Erlang process flags)
      property flags : Hash(String, Value)

      # Parent process that spawned this one
      property parent : UInt64?

      # Priority for scheduling
      property priority : Priority

      # Creation time for debugging
      property created_at : Time

      # Total reductions (instructions executed)
      property reductions : UInt64

      enum Priority
        Low
        Normal
        High
        Max
      end

      def initialize(@address : UInt64, @instructions : Array(Instruction))
        @state = State::ALIVE
        @counter = 0_u64
        @stack = [] of Value
        @locals = [] of Value
        @mailbox = Mailbox.new(100)
        @call_stack = [] of UInt64
        @frame_pointer = 0
        @waiting_for = nil
        @waiting_since = nil
        @waiting_timeout = nil
        @waiting_message_id = nil
        @blocked_sends = [] of Tuple(UInt64, Message)
        @registered_name = nil
        @dependencies = Set(UInt64).new

        # Fault tolerance initialization
        @exit_reason = nil
        @exception_handlers = [] of ExceptionHandler
        @current_exception = nil
        @flags = {} of String => Value
        @parent = nil
        @priority = Priority::Normal
        @created_at = Time.utc
        @reductions = 0_u64
      end

      # Initialize with parent process
      def initialize(@address : UInt64, @instructions : Array(Instruction), @parent : UInt64?)
        @state = State::ALIVE
        @counter = 0_u64
        @stack = [] of Value
        @locals = [] of Value
        @mailbox = Mailbox.new(100)
        @call_stack = [] of UInt64
        @frame_pointer = 0
        @waiting_for = nil
        @waiting_since = nil
        @waiting_timeout = nil
        @waiting_message_id = nil
        @blocked_sends = [] of Tuple(UInt64, Message)
        @registered_name = nil
        @dependencies = Set(UInt64).new

        # Fault tolerance initialization
        @exit_reason = nil
        @exception_handlers = [] of ExceptionHandler
        @current_exception = nil
        @flags = {} of String => Value
        @priority = Priority::Normal
        @created_at = Time.utc
        @reductions = 0_u64
      end

      # Check if wait has timed out
      def wait_timed_out? : Bool
        return false unless @waiting_since && @waiting_timeout
        Time.utc - @waiting_since.not_nil! > @waiting_timeout.not_nil!
      end

      # Add a process dependency
      def add_dependency(process_address : UInt64)
        @dependencies.add(process_address)
      end

      # Remove a process dependency
      def remove_dependency(process_address : UInt64)
        @dependencies.delete(process_address)
      end

      # Check if process is alive
      def alive? : Bool
        @state != State::DEAD
      end

      # Check if process has exception handlers
      def has_exception_handler? : Bool
        !@exception_handlers.empty?
      end

      # Get the current exception handler without removing it
      def peek_exception_handler : ExceptionHandler?
        @exception_handlers.last?
      end

      # Increment reductions counter
      def increment_reductions(count : UInt64 = 1_u64)
        @reductions += count
      end

      # Get process info as a hash
      def info : Hash(String, Value)
        hash = Hash(String, Value).new

        hash["address"] = Value.new(@address.to_i64)
        hash["state"] = Value.new(@state.to_s)
        hash["registered_name"] = @registered_name ? Value.new(@registered_name.not_nil!) : Value.new
        hash["counter"] = Value.new(@counter.to_i64)
        hash["stack_size"] = Value.new(@stack.size.to_i64)
        hash["mailbox_size"] = Value.new(@mailbox.size.to_i64)
        hash["call_stack_size"] = Value.new(@call_stack.size.to_i64)
        hash["reductions"] = Value.new(@reductions.to_i64)
        hash["priority"] = Value.new(@priority.to_s)
        hash["created_at"] = Value.new(@created_at.to_unix.to_i64)
        hash["parent"] = @parent ? Value.new(@parent.not_nil!.to_i64) : Value.new

        hash
      end

      # Get a summary string for logging
      def summary : String
        name_part = @registered_name ? " (#{@registered_name})" : ""
        "<#{@address}>#{name_part} [#{@state}] reductions=#{@reductions}"
      end
    end
  end
end
