require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

client_instructions = [
  # Create connected UDP socket
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("127.0.0.1")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(9000_i64)),
  VM::Instruction.new(VM::Code::UDP_CONNECT),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PUSH_NULL),
  VM::Instruction.new(VM::Code::EQUAL),
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(27_i64)), # Jump to failure

  # Store socket
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("UDP client ready")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send message
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Hello from UDP client!")),
  VM::Instruction.new(VM::Code::UDP_SEND),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Message sent, waiting for response...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Receive response
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1024_i64)),
  VM::Instruction.new(VM::Code::UDP_RECEIVE),

  # Stack: [addr_info, data]
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Server response: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::POP), # Pop addr_info

  # Close socket
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::UDP_CLOSE),
  VM::Instruction.new(VM::Code::POP),

  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:normal)),
  VM::Instruction.new(VM::Code::EXIT_SELF),

  # Failure path
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Failed to create UDP socket")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:error)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

process = engine.process_manager.create_process(instructions: client_instructions)
engine.processes.push(process)
engine.run
