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

      # Represents the reason a process exited
      class ExitReason
        enum Type
          Normal         # Clean shutdown
          Kill           # Forcefully killed (untrappable)
          Shutdown       # Requested shutdown (trappable)
          Exception      # Crashed with exception
          Timeout        # Timed out waiting
          InvalidProcess # Target process doesn't exist
          Custom         # User-defined reason
        end

        getter type : Type
        getter message : String
        getter exception : Exception?
        getter stacktrace : Array(String)
        getter timestamp : Time

        def initialize(@type : Type, @message : String = "", @exception : Exception? = nil)
          @stacktrace = [] of String
          @timestamp = Time.utc
        end

        def initialize(@type : Type, @message : String, @stacktrace : Array(String))
          @exception = nil
          @timestamp = Time.utc
        end

        # Factory methods for common exit reasons
        def self.normal : ExitReason
          new(Type::Normal, "normal")
        end

        def self.kill : ExitReason
          new(Type::Kill, "killed")
        end

        def self.shutdown(reason : String = "shutdown") : ExitReason
          new(Type::Shutdown, reason)
        end

        def self.exception(exception : Exception) : ExitReason
          reason = new(Type::Exception, exception.message || "Unknown error", exception)

          if backtrace = exception.backtrace?
            reason.stacktrace.concat(backtrace)
          end

          reason
        end

        def self.timeout : ExitReason
          new(Type::Timeout, "timeout")
        end

        def self.invalid_process : ExitReason
          new(Type::InvalidProcess, "invalid_process")
        end

        def self.custom(message : String) : ExitReason
          new(Type::Custom, message)
        end

        # Check if this is a "normal" exit (shouldn't trigger restarts)
        def normal? : Bool
          @type == Type::Normal || @type == Type::Shutdown
        end

        # Check if this exit should propagate to linked processes
        def propagates? : Bool
          @type != Type::Normal
        end

        # Check if this exit can be trapped
        def trappable? : Bool
          @type != Type::Kill
        end

        def to_s : String
          case @type
          when .normal?         then "normal"
          when .kill?           then "killed"
          when .shutdown?       then "shutdown: #{@message}"
          when .exception?      then "exception: #{@message}"
          when .timeout?        then "timeout"
          when .invalid_process? then "invalid_process"
          when .custom?         then @message
          else                       "unknown"
          end
        end

        def inspect : String
          "ExitReason(#{@type}: #{@message})"
        end

        # Convert to a Value for message passing
        def to_value : Value
          hash = Hash(String, Value).new
          hash["type"] = Value.new(@type.to_s)
          hash["message"] = Value.new(@message)
          hash["timestamp"] = Value.new(@timestamp.to_unix.to_i64)
          Value.new(hash)
        end
      end

      # Represents a signal sent between processes
      struct ExitSignal
        getter from : UInt64 # Process that exited
        getter reason : ExitReason
        getter link_type : LinkType

        enum LinkType
          Link    # Bidirectional link
          Monitor # Unidirectional monitor
        end

        def initialize(@from : UInt64, @reason : ExitReason, @link_type : LinkType = LinkType::Link)
        end

        def to_value : Value
          hash = Hash(String, Value).new
          hash["signal"] = Value.new("EXIT")
          hash["from"] = Value.new(@from.to_i64)
          hash["reason"] = @reason.to_value
          hash["link_type"] = Value.new(@link_type.to_s)
          Value.new(hash)
        end
      end

      # Monitor reference for tracking monitors
      struct MonitorReference
        getter id : UInt64
        getter watcher : UInt64
        getter watched : UInt64
        getter created_at : Time

        @@counter : UInt64 = 0_u64

        def initialize(@watcher : UInt64, @watched : UInt64)
          @id = @@counter += 1
          @created_at = Time.utc
        end

        def ==(other : MonitorReference) : Bool
          @id == other.id
        end

        def hash(hasher)
          hasher = @id.hash(hasher)
          hasher
        end
      end

      # DOWN message sent when monitored process exits
      struct DownMessage
        getter ref : MonitorReference
        getter process : UInt64
        getter reason : ExitReason

        def initialize(@ref : MonitorReference, @process : UInt64, @reason : ExitReason)
        end

        def to_value : Value
          hash = Hash(String, Value).new
          hash["signal"] = Value.new("DOWN")
          hash["ref"] = Value.new(@ref.id.to_i64)
          hash["process"] = Value.new(@process.to_i64)
          hash["reason"] = @reason.to_value
          Value.new(hash)
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
