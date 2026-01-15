require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Attach debugger
debugger = engine.attach_debugger do |process, instruction|
  puts "Break: Process <#{process.address}> at #{process.counter}"
  puts "Stack: #{process.stack.map(&.to_s)}"

  print "debug (c/s/q)> "
  case gets.try(&.chomp)
  when "s" then VM::Engine::Debugger::Action::Step
  when "q" then VM::Engine::Debugger::Action::Abort
  else          VM::Engine::Debugger::Action::Continue
  end
end

# Break at instruction 0
debugger.add_breakpoint_at(0_u64)

# Simple program
instructions = [
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(10_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(20_i64)),
  VM::Instruction.new(VM::Code::ADD),
  VM::Instruction.new(VM::Code::PRINT_LINE), # Breakpoint here
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes << process
engine.run
