require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

socket_path = "/tmp/jelly.sock"

# Clean up old socket file if it exists
File.delete(socket_path) if File.exists?(socket_path)

server_instructions = [
  # Create UNIX server socket
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new(socket_path)),
  VM::Instruction.new(VM::Code::UNIX_LISTEN),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(33_i64)), # Jump to failure

  # Store server socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("UNIX Server listening on #{socket_path}")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept loop start (instruction 9)
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Waiting for connection...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Accept connection
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::UNIX_ACCEPT),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(-8_i64)), # Retry on failure

  # Store client socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Client connected!")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive data
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::UNIX_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),

  # Print received message
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Received: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send response
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Hello from UNIX server!")),
  VM::Instruction.new(VM::Code::UNIX_SEND),
  VM::Instruction.new(VM::Code::POP),

  # Close client socket
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::UNIX_CLOSE),
  VM::Instruction.new(VM::Code::POP),

  # Loop back
  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-27_i64)),

  # Failure path
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Failed to create UNIX server socket")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:error)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

process = engine.process_manager.create_process(instructions: server_instructions)
engine.processes.push(process)
engine.run
