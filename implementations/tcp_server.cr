require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

server_instructions = [
  # Create TCP server on localhost:8080
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("127.0.0.1")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(8080_i64)),
  VM::Instruction.new(VM::Code::TCP_LISTEN),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(35_i64)), # Jump to failure

  # Store server socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("TCP Server listening on 127.0.0.1:8080")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept loop start (instruction 10)
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Waiting for connection...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept connection
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::TCP_ACCEPT),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(-8_i64)), # Retry accept on failure

  # Store client socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Client connected!")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive data from client
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::TCP_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),

  # Print received message
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Received: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send response
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, World!")),
  VM::Instruction.new(VM::Code::TCP_SEND),
  VM::Instruction.new(VM::Code::POP),

  # Close client socket
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::TCP_CLOSE),
  VM::Instruction.new(VM::Code::POP),

  # Loop back to accept more connections
  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-27_i64)),

  # Failure path (instruction 45)
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Failed to start server")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:error)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

process = engine.process_manager.create_process(instructions: server_instructions)
engine.processes.push(process)
engine.run
