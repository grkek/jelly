require "log"
require "json"

# Adjust this path to match your project structure
require "./virtual_machine/**"

module Jelly
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end

# Initialize the engine
engine = Jelly::VirtualMachine::Engine.new

# Create the main process (address 1)
main_process = engine.process_manager.create_process
engine.processes.push(main_process)

# Instructions for the main process (address 1)
main_instructions = [
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::SPAWN),
  Jelly::VirtualMachine::Instruction.new(
    Jelly::VirtualMachine::Code::SEND,
    Jelly::VirtualMachine::Value.new({2_u64, Jelly::VirtualMachine::Value.new("Hello from #{main_process.address}")})
  ),
]

# Instructions for the spawned process (address 2)
child_instructions = [
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::RECEIVE),
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT)
]

main_instructions.each do |instruction|
  engine.execute(engine.processes.first, instruction)
end

child_instructions.each do |instruction|
  engine.execute(engine.processes.last, instruction)
end
