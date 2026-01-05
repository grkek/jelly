module Jelly
  module VirtualMachine
    # Represents the reason a process exited
    # Similar to Erlang's exit reasons
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
        when .normal?
          "normal"
        when .kill?
          "killed"
        when .shutdown?
          "shutdown: #{@message}"
        when .exception?
          "exception: #{@message}"
        when .timeout?
          "timeout"
        when .invalid_process?
          "invalid_process"
        when .custom?
          @message
        else
          "unknown"
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
    struct MonitorRef
      getter id : UInt64
      getter watcher : UInt64
      getter watched : UInt64
      getter created_at : Time

      @@counter : UInt64 = 0_u64

      def initialize(@watcher : UInt64, @watched : UInt64)
        @id = @@counter += 1
        @created_at = Time.utc
      end

      def ==(other : MonitorRef) : Bool
        @id == other.id
      end

      def hash(hasher)
        hasher = @id.hash(hasher)
        hasher
      end
    end

    # DOWN message sent when monitored process exits
    struct DownMessage
      getter ref : MonitorRef
      getter process : UInt64
      getter reason : ExitReason

      def initialize(@ref : MonitorRef, @process : UInt64, @reason : ExitReason)
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
  end
end
