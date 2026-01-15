require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

server_instructions = [
  # Bind UDP socket to localhost:9000
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("127.0.0.1")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(9000_i64)),
  VM::Instruction.new(VM::Code::UDP_BIND),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(43_i64)), # Jump to failure

  # Store socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("UDP Server listening on 127.0.0.1:9000")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive loop start (instruction 10)
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Waiting for datagram...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive datagram (pushes addr_info then data)
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::UDP_RECEIVE),

  # Stack now: [addr_info, data]
  # Store data
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_u64)),

  # Store addr_info (it's underneath)
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),

  # Print sender info
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Received from: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("host")),
  VM::Instruction.new(VM::Code::MAP_GET),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Print message
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Message: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send response back using UDP_SEND_TO
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),  # socket_id
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Echo: ")),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_u64)),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),               # data
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("host")),
  VM::Instruction.new(VM::Code::MAP_GET),                          # host
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("port")),
  VM::Instruction.new(VM::Code::MAP_GET),                          # port
  VM::Instruction.new(VM::Code::UDP_SEND_TO),
  VM::Instruction.new(VM::Code::POP),

  # Loop back
  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-33_i64)),

  # Failure path
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Failed to bind UDP socket")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:error)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

process = engine.process_manager.create_process(instructions: server_instructions)
engine.processes.push(process)
engine.run
