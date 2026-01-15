require "../src/jelly"

alias VM = Jelly::VirtualMachine

puts "Currently there is no true concurrency for the Jelly VM, I will deliver."

exit(1)

engine = VM::Engine.new

socket_path = "/tmp/jelly_echo.sock"
File.delete(socket_path) if File.exists?(socket_path)

# TCP Echo Handler Process
tcp_server_instructions = [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("127.0.0.1")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(8080_i64)),
  VM::Instruction.new(VM::Code::TCP_LISTEN),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[TCP] Listening on 127.0.0.1:8080")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept loop
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::TCP_ACCEPT),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::TCP_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[TCP] Received: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("TCP Echo: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::TCP_SEND),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::TCP_CLOSE),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-21_i64)),
]

# UDP Echo Handler Process
udp_server_instructions = [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("127.0.0.1")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(9000_i64)),
  VM::Instruction.new(VM::Code::UDP_BIND),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[UDP] Listening on 127.0.0.1:9000")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive loop
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::UDP_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)), # addr_info

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[UDP] Received: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("UDP Echo: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("host")),
  VM::Instruction.new(VM::Code::MAP_GET),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("port")),
  VM::Instruction.new(VM::Code::MAP_GET),
  VM::Instruction.new(VM::Code::UDP_SEND_TO),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-22_i64)),
]

# UNIX Echo Handler Process
unix_server_instructions = [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new(socket_path)),
  VM::Instruction.new(VM::Code::UNIX_LISTEN),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[UNIX] Listening on #{socket_path}")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept loop
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::UNIX_ACCEPT),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::UNIX_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("[UNIX] Received: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("UNIX Echo: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::UNIX_SEND),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::UNIX_CLOSE),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-18_i64)),
]

# Create supervisor for all servers
supervisor = engine.create_supervisor(
  strategy: VM::Supervisor::RestartStrategy::OneForOne,
  max_restarts: 5,
  restart_window: 10.seconds
)

tcp_specification = VM::Supervisor::Child::Specification.new(
  id: "tcp_server",
  instructions: tcp_server_instructions,
  restart: VM::Supervisor::RestartType::Permanent,
  max_restarts: 3,
  restart_window: 5.seconds
)

udp_specification = VM::Supervisor::Child::Specification.new(
  id: "udp_server",
  instructions: udp_server_instructions,
  restart: VM::Supervisor::RestartType::Permanent,
  max_restarts: 3,
  restart_window: 5.seconds
)

unix_specification = VM::Supervisor::Child::Specification.new(
  id: "unix_server",
  instructions: unix_server_instructions,
  restart: VM::Supervisor::RestartType::Permanent,
  max_restarts: 3,
  restart_window: 5.seconds
)

supervisor.add_child(tcp_specification)
supervisor.add_child(udp_specification)
supervisor.add_child(unix_specification)

puts "Starting multi-protocol echo server..."
puts "  TCP:  127.0.0.1:8080"
puts "  UDP:  127.0.0.1:9000"
puts "  UNIX: #{socket_path}"
puts ""

engine.run
