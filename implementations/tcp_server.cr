require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

instructions = [
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

# Attach debugger (same as before)
debugger = engine.attach_debugger do |process, instruction|
  puts "═" * 80
  puts "Break at Process <#{process.address}>, counter: #{process.counter}"
  puts "Call stack depth: #{process.call_stack.size}"
  puts "Instruction: #{instruction.try(&.code) || "none"}"
  puts "Stack (top 10): #{process.stack.reverse.first(10).reverse.map(&.to_s)}"
  puts "Locals: #{process.locals.map(&.to_s)}"
  puts "═" * 80

  print "debug(s=step/c=continue/q=quit)> "
  input = gets.try(&.chomp) || "s"

  case input
  when "s", "step"     then VM::Engine::Debugger::Action::Step
  when "c", "continue" then VM::Engine::Debugger::Action::Continue
  when "q", "quit"     then VM::Engine::Debugger::Action::Abort
  else                      VM::Engine::Debugger::Action::Step
  end
end

breakpoint = debugger.add_breakpoint { |p| p.counter == 24 }

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)

engine.configuration.iteration_limit = 1000000

engine.run

# Check breakpoint stats
Log.info { "Breakpoint #{breakpoint.id} hit #{breakpoint.hit_count} times" }
Log.info { "Final fault tolerance stats: #{engine.fault_tolerance_statistics}" }
