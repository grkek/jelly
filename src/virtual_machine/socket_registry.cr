module Jelly
  module VirtualMachine
    class SocketRegistry
      Log = ::Log.for(self)

      def initialize
        @sockets = Hash(UInt64, TCPSocket).new
        @next_id = 1_u64
        @mutex = Mutex.new(:reentrant)
      end

      # Register a new socket and return its ID
      def register(socket : TCPSocket) : UInt64
        @mutex.synchronize do
          id = @next_id
          @next_id += 1
          @sockets[id] = socket
          Log.debug { "Registered socket #{id}" }
          id
        end
      end

      # Execute a block with the socket, returns nil if socket doesn't exist
      def with_socket(id : UInt64, & : TCPSocket -> T) : T? forall T
        socket = @mutex.synchronize { @sockets[id]? }
        return nil unless socket
        yield socket
      end

      # Execute a block with the socket, raises if socket doesn't exist
      def with_socket!(id : UInt64, & : TCPSocket -> T) : T forall T
        socket = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless socket
        yield socket
      end

      # Remove and close a socket, returns true if it existed
      def close(id : UInt64) : Bool
        socket = @mutex.synchronize { @sockets.delete(id) }
        if socket
          begin
            socket.close
            Log.debug { "Closed socket #{id}" }
          rescue ex
            Log.warn { "Error closing socket #{id}: #{ex.message}" }
          end
          true
        else
          false
        end
      end

      # Close all sockets (for cleanup)
      def close_all
        @mutex.synchronize do
          @sockets.each do |id, socket|
            begin
              socket.close
            rescue ex
              Log.warn { "Error closing socket #{id}: #{ex.message}" }
            end
          end
          @sockets.clear
          Log.debug { "Closed all sockets" }
        end
      end

      # Check if a socket exists
      def exists?(id : UInt64) : Bool
        @mutex.synchronize { @sockets.has_key?(id) }
      end

      # Get count of open sockets
      def size : Int32
        @mutex.synchronize { @sockets.size }
      end
    end
  end
end
