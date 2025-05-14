module Jelly
  module VirtualMachine
    class Process
      enum State
        ALIVE
        STALE
        WAITING # New state for processes explicitly waiting for messages
        BLOCKED # New state for processes blocked on full mailboxes
        DEAD
      end

      property address : UInt64
      property state : State
      property counter : UInt64
      property stack : Array(Value)
      property mailbox : Mailbox
      property call_stack : Array(UInt64)
      property frame_pointer : Int32
      property waiting_for : Value?                          # Pattern to wait for
      property waiting_since : Time?                         # When the process started waiting
      property waiting_timeout : Time::Span?                 # How long to wait
      property waiting_message_id : UInt64?                  # Specific message ID to wait for
      property blocked_sends : Array(Tuple(UInt64, Message)) # List of blocked send operations
      property registered_name : String?                     # For process registry
      property dependencies : Set(UInt64)                    # Process dependencies for deadlock detection

      def initialize(@address : UInt64)
        @state = State::ALIVE
        @counter = 0_u64
        @stack = [] of Value
        @mailbox = Mailbox.new(100) # Default capacity
        @call_stack = [] of UInt64
        @frame_pointer = 0
        @waiting_for = nil
        @waiting_since = nil
        @waiting_timeout = nil
        @waiting_message_id = nil
        @blocked_sends = [] of Tuple(UInt64, Message)
        @registered_name = nil
        @dependencies = Set(UInt64).new
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
    end
  end
end
