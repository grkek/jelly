require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Attach debugger with interactive handler
debugger = engine.attach_debugger do |process, instruction|
  puts "═" * 50
  puts "Break at Process <#{process.address}>, counter: #{process.counter}"
  puts "Instruction: #{instruction.try(&.code) || "none"}"
  puts "Stack: #{process.stack.map(&.to_s)}"
  puts "Locals: #{process.locals.map(&.to_s)}"
  puts "═" * 50

  print "] "
  input = gets.try(&.chomp) || "c"

  case input
  when "c", "continue" then VM::Engine::Debugger::Action::Continue
  when "s", "step"     then VM::Engine::Debugger::Action::Step
  when "n", "next"     then VM::Engine::Debugger::Action::StepOver
  when "q", "quit"     then VM::Engine::Debugger::Action::Abort
  else                      VM::Engine::Debugger::Action::Continue
  end
end

# Add breakpoints
debugger.add_breakpoint_at(2_u64) # Break at instruction 5

debugger.add_breakpoint { |p| p.stack.size > 10 } # Break on large stack

breakpoint = debugger.add_breakpoint { |p| p.counter == 10 }

# Disable a breakpoint temporarily
breakpoint.disable

# Check breakpoint stats
puts "Breakpoint #{breakpoint.id} hit #{breakpoint.hit_count} times"

worker_instructions = [
  # Connect to icanhazip.com
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("icanhazip.com")), # 0
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(80_i64)),         # 1
  VM::Instruction.new(VM::Code::TCP_CONNECT),                                 # 2
  VM::Instruction.new(VM::Code::DUPLICATE),                                   # 3
  VM::Instruction.new(VM::Code::PUSH_NULL),                                   # 4
  VM::Instruction.new(VM::Code::EQUAL),                                       # 5
  VM::Instruction.new(VM::Code::JUMP_IF, VM::Value.new(37_i64)),              # 6 -> jump to failure path

  # Success path - store socket in local 0
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_i64)),           # 7

  # Send HTTP request
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),                                                                 # 8
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("GET / HTTP/1.1\r\nHost: icanhazip.com\r\nConnection: close\r\n\r\n")), # 9
  VM::Instruction.new(VM::Code::TCP_SEND),                                                                                         # 10
  VM::Instruction.new(VM::Code::POP),                                                                                              # 11

  # Receive response and convert to string
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),                  # 12
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(2048_i64)),             # 13
  VM::Instruction.new(VM::Code::TCP_RECEIVE),                                       # 14
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),                                  # 15
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_i64)),                 # 16 - store response in local 1

  # Find "\r\n\r\n" (end of headers)
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_i64)),                  # 17
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("\r\n\r\n")),            # 18
  VM::Instruction.new(VM::Code::STRING_INDEX),                                      # 19 - find index of blank line
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(4_i64)),                # 20 - add 4 to skip past \r\n\r\n
  VM::Instruction.new(VM::Code::ADD),                                               # 21
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_i64)),                 # 22 - store body start index

  # Extract body (from body_start to end)
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_i64)),                  # 23 - load response
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_i64)),                  # 24 - load body start index
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(50_i64)),               # 25 - length (50 chars is plenty for an IP)
  VM::Instruction.new(VM::Code::STRING_SUBSTRING),                                  # 26
  VM::Instruction.new(VM::Code::STRING_TRIM),                                       # 27 - trim whitespace

  # Print the IP
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Your IP: ")),           # 28
  VM::Instruction.new(VM::Code::SWAP),                                              # 29
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),                                # 30
  VM::Instruction.new(VM::Code::PRINT_LINE),                                        # 31

  # Close socket
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),                  # 32
  VM::Instruction.new(VM::Code::TCP_CLOSE),                                         # 33
  VM::Instruction.new(VM::Code::POP),                                               # 34
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:normal)),               # 35
  VM::Instruction.new(VM::Code::EXIT_SELF),                                         # 36

  # Failure path (index 37)
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Connection failed")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:error)), # Non-normal exit
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

# Create supervisor
supervisor = engine.create_supervisor(
  strategy: VM::Supervisor::RestartStrategy::OneForOne,
  max_restarts: 3,
  restart_window: 5.seconds
)

Log.info { "Supervisor created with address <#{supervisor.address}>" }

worker = VM::Supervisor::Child::Specification.new(
  id: "worker",
  instructions: worker_instructions,
  restart: VM::Supervisor::RestartType::Transient,
  max_restarts: 3,
  restart_window: 5.seconds
)

supervisor.add_child(worker)

Log.info { "Starting VM with properly supervised worker..." }

# Run the engine
engine.run

# Detach debugger when done
engine.detach_debugger

Log.info { "Final fault tolerance stats: #{engine.fault_tolerance_statistics}" }
Log.info { "Supervisor child status: #{supervisor.child_status}" }

sleep 5.seconds
