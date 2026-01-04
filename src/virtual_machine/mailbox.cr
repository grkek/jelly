module Jelly
  module VirtualMachine
    # Thread-safe mailbox for actor-style message passing
    # Each process has its own isolated mailbox
    class Mailbox
      Log = ::Log.for(self)

      # Regular messages waiting to be received
      getter messages : Array(Message)
      # Acknowledgments for delivered/processed messages (if enabled)
      getter acks : Array(MessageAcknowledgment)
      # Maximum number of messages before full (configurable)
      getter capacity : Int32
      # Mutex for thread-safe operations
      getter mailbox_mutex : Mutex

      def initialize(@capacity : Int32 = 100)
        @messages = [] of Message
        @acks = [] of MessageAcknowledgment
        @mailbox_mutex = Mutex.new(:reentrant) # Reentrant to allow nested locks if needed
      end

      # Add a message to the mailbox
      # Returns true if successful, false if mailbox is full
      def push(message : Message) : Bool
        @mailbox_mutex.synchronize do
          if @messages.size >= @capacity
            return false
          end
          @messages << message
          true
        end
      end

      # Remove and return the oldest message (FIFO)
      def shift : Message?
        @mailbox_mutex.synchronize do
          @messages.shift?
        end
      end

      # Return the oldest message without removing it
      def peek : Message?
        @mailbox_mutex.synchronize do
          @messages.first?
        end
      end

      # Find and remove the first message matching the given pattern
      # Used by RECEIVE_SELECT
      def select(pattern : Value) : Message?
        @mailbox_mutex.synchronize do
          index = @messages.index do |msg|
            matches_pattern?(msg.value, pattern)
          end

          if index
            @messages.delete_at(index)
          else
            nil
          end
        end
      end

      # Check if a message value matches a pattern
      # Supports:
      # - Null pattern → matches anything
      # - Exact value match
      # - Map pattern matching (partial map with null wildcards)
      def matches_pattern?(value : Value, pattern : Value) : Bool
        return true if pattern.is_null? # Wildcard: match any message

        if pattern.is_map? && value.is_map?
          pattern_map = pattern.to_h
          value_map = value.to_h

          pattern_map.all? do |k, v|
            value_map.has_key?(k) && (v.is_null? || value_map[k] == v)
          end
        else
          value == pattern
        end
      end

      # Is the mailbox empty?
      def empty? : Bool
        @mailbox_mutex.synchronize do
          @messages.empty?
        end
      end

      # Current number of messages
      def size : Int32
        @mailbox_mutex.synchronize do
          @messages.size
        end
      end

      # Remove all expired messages (based on TTL)
      # Returns number of messages removed
      def cleanup_expired_messages : Int32
        @mailbox_mutex.synchronize do
          initial_size = @messages.size
          @messages.reject!(&.expired?)
          initial_size - @messages.size
        end
      end

      # Store a message acknowledgment (delivery/processed)
      def add_ack(ack : MessageAcknowledgment)
        @mailbox_mutex.synchronize do
          @acks << ack
        end
      end
    end
  end
end
