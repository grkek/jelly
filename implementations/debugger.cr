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
breakpoint.ignore_count = 3 # Skip first 3 hits

# Disable a breakpoint temporarily
breakpoint.disable

# Check breakpoint stats
puts "Breakpoint #{breakpoint.id} hit #{breakpoint.hit_count} times"

instructions = [
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(10_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(5_i64)),
  VM::Instruction.new(VM::Code::ADD), # Stack: [15]
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(3_i64)),
  VM::Instruction.new(VM::Code::MULTIPLY), # Stack: [45]
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)

# Run the engine
engine.run

# Detach debugger when done
engine.detach_debugger
