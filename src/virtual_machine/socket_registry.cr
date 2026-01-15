module Jelly
  module VirtualMachine
    # Union type for all supported socket types
    alias Socket = TCPSocket | UDPSocket | TCPServer | UNIXSocket | UNIXServer

    class SocketRegistry
      Log = ::Log.for(self)

      enum Type
        TCP
        TCPServer
        UDP
        UNIX
        UNIXServer
      end

      record SocketEntry, socket : Socket, type : Type

      def initialize
        @sockets = Hash(UInt64, SocketEntry).new
        @next_id = 1_u64
        @mutex = Mutex.new(:reentrant)
      end

      # Register a TCP client socket
      def register(socket : TCPSocket) : UInt64
        register_socket(socket, Type::TCP)
      end

      # Register a TCP server socket
      def register(socket : TCPServer) : UInt64
        register_socket(socket, Type::TCPServer)
      end

      # Register a UDP socket
      def register(socket : UDPSocket) : UInt64
        register_socket(socket, Type::UDP)
      end

      # Register a UNIX client socket
      def register(socket : UNIXSocket) : UInt64
        register_socket(socket, Type::UNIX)
      end

      # Register a UNIX server socket
      def register(socket : UNIXServer) : UInt64
        register_socket(socket, Type::UNIXServer)
      end

      private def register_socket(socket : Socket, type : Type) : UInt64
        @mutex.synchronize do
          id = @next_id
          @next_id += 1
          @sockets[id] = SocketEntry.new(socket, type)
          Log.debug { "Registered #{type} socket #{id}" }
          id
        end
      end

      # Get the socket type for an ID
      def socket_type(id : UInt64) : Type?
        @mutex.synchronize { @sockets[id]?.try(&.type) }
      end

      # Execute a block with any socket
      def with_socket(id : UInt64, & : Socket -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        yield entry.socket
      end

      # Execute a block with any socket, raises if socket doesn't exist
      def with_socket!(id : UInt64, & : Socket -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        yield entry.socket
      end

      # Execute a block with a TCP socket
      def with_tcp_socket(id : UInt64, & : TCPSocket -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        socket = entry.socket
        return nil unless socket.is_a?(TCPSocket)
        yield socket
      end

      # Execute a block with a TCP socket, raises if not found or wrong type
      def with_tcp_socket!(id : UInt64, & : TCPSocket -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        socket = entry.socket
        raise EmulationException.new("Socket #{id} is not a TCP socket") unless socket.is_a?(TCPSocket)
        yield socket
      end

      # Execute a block with a TCP server socket
      def with_tcp_server(id : UInt64, & : TCPServer -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        socket = entry.socket
        return nil unless socket.is_a?(TCPServer)
        yield socket
      end

      # Execute a block with a TCP server socket, raises if not found or wrong type
      def with_tcp_server!(id : UInt64, & : TCPServer -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        socket = entry.socket
        raise EmulationException.new("Socket #{id} is not a TCP server") unless socket.is_a?(TCPServer)
        yield socket
      end

      # Execute a block with a UDP socket
      def with_udp_socket(id : UInt64, & : UDPSocket -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        socket = entry.socket
        return nil unless socket.is_a?(UDPSocket)
        yield socket
      end

      # Execute a block with a UDP socket, raises if not found or wrong type
      def with_udp_socket!(id : UInt64, & : UDPSocket -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        socket = entry.socket
        raise EmulationException.new("Socket #{id} is not a UDP socket") unless socket.is_a?(UDPSocket)
        yield socket
      end

      # Execute a block with a UNIX socket
      def with_unix_socket(id : UInt64, & : UNIXSocket -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        socket = entry.socket
        return nil unless socket.is_a?(UNIXSocket)
        yield socket
      end

      # Execute a block with a UNIX socket, raises if not found or wrong type
      def with_unix_socket!(id : UInt64, & : UNIXSocket -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        socket = entry.socket
        raise EmulationException.new("Socket #{id} is not a UNIX socket") unless socket.is_a?(UNIXSocket)
        yield socket
      end

      # Execute a block with a UNIX server socket
      def with_unix_server(id : UInt64, & : UNIXServer -> T) : T? forall T
        entry = @mutex.synchronize { @sockets[id]? }
        return nil unless entry
        socket = entry.socket
        return nil unless socket.is_a?(UNIXServer)
        yield socket
      end

      # Execute a block with a UNIX server socket, raises if not found or wrong type
      def with_unix_server!(id : UInt64, & : UNIXServer -> T) : T forall T
        entry = @mutex.synchronize { @sockets[id]? }
        raise EmulationException.new("Invalid socket ID: #{id}") unless entry
        socket = entry.socket
        raise EmulationException.new("Socket #{id} is not a UNIX server") unless socket.is_a?(UNIXServer)
        yield socket
      end

      # Remove and close a socket, returns true if it existed
      def close(id : UInt64) : Bool
        entry = @mutex.synchronize { @sockets.delete(id) }
        if entry
          begin
            entry.socket.close
            Log.debug { "Closed #{entry.type} socket #{id}" }
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
          @sockets.each do |id, entry|
            begin
              entry.socket.close
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

      # Get count of sockets by type
      def count_by_type(type : Type) : Int32
        @mutex.synchronize do
          @sockets.values.count { |entry| entry.type == type }
        end
      end

      # Get all socket IDs of a specific type
      def ids_by_type(type : Type) : Array(UInt64)
        @mutex.synchronize do
          @sockets.select { |_, entry| entry.type == type }.keys
        end
      end
    end
  end
end
