require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Add custom instruction handler with a block
engine.on_instruction(VM::Code::DUPLICATE) do |process, instruction|
  process.counter += 1
  process.stack.push(VM::Value.new("custom result"))

  VM::Value.new
end

process = engine.process_manager.create_process(instructions: [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Hello, World!")),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PRINT_LINE)
])

engine.processes.push(process)

engine.run
