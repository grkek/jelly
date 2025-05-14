require "concurrent"

module Jelly
  module VirtualMachine
    class Message
      property sender : UInt64
      property value : Value
      property id : UInt64      # Unique message ID for tracking
      property needs_ack : Bool # Whether message requires acknowledgment
      property timestamp : Time # When the message was sent
      property ttl : Time::Span # Time to live

      @@next_id : UInt64 = 1
      @@id_mutex = Mutex.new

      def initialize(@sender : UInt64, @value : Value, @needs_ack = false, @ttl = 30.seconds)
        @id = @@id_mutex.synchronize do
          id = @@next_id
          @@next_id += 1
          id
        end
        @timestamp = Time.utc
      end

      def expired? : Bool
        Time.utc - @timestamp > @ttl
      end
    end
  end
end
