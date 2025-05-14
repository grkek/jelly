module Jelly
  module VirtualMachine
    # Thread-safe mailbox implementation
    class Mailbox
      Log = ::Log.for(self)

      property messages : Array(Message)
      property acks : Array(MessageAcknowledgment)
      property capacity : Int32
      property mailbox_mutex : Mutex

      def initialize(@capacity : Int32)
        @messages = [] of Message
        @acks = [] of MessageAcknowledgment
        @mailbox_mutex = Mutex.new
      end

      def push(message : Message) : Bool
        @mailbox_mutex.synchronize do
          if @messages.size >= @capacity
            return false # Indicates mailbox is full
          end
          @messages.push(message)
          true
        end
      end

      def shift : Message?
        @mailbox_mutex.synchronize do
          @messages.shift?
        end
      end

      def peek : Message?
        @mailbox_mutex.synchronize do
          @messages.first?
        end
      end

      # Select first message matching a pattern
      def select(pattern : Value) : Message?
        @mailbox_mutex.synchronize do
          index = @messages.index do |msg|
            matches_pattern?(msg.value, pattern)
          end

          if index
            msg = @messages[index]
            @messages.delete_at(index)
            return msg
          end

          nil
        end
      end

      # Check if a message matches a pattern
      def matches_pattern?(value : Value, pattern : Value) : Bool
        # Simple pattern matching - can be extended for more complex patterns
        return true if pattern.is_null? # Null pattern matches any message

        if pattern.is_map? && value.is_map?
          pattern_map = pattern.to_h
          value_map = value.to_h

          # Check if value contains all keys+values in pattern
          pattern_map.all? do |k, v|
            value_map.has_key?(k) && (v.is_null? || value_map[k] == v)
          end
        else
          value == pattern
        end
      end

      def empty? : Bool
        @mailbox_mutex.synchronize do
          @messages.empty?
        end
      end

      def size : Int32
        @mailbox_mutex.synchronize do
          @messages.size
        end
      end

      # Remove expired messages
      def cleanup_expired : Int32
        @mailbox_mutex.synchronize do
          initial_size = @messages.size
          @messages.reject! { |msg| msg.expired? }
          initial_size - @messages.size
        end
      end

      # Add acknowledgment
      def add_ack(ack : MessageAcknowledgment)
        @mailbox_mutex.synchronize do
          @acks.push(ack)
        end
      end
    end
  end
end
