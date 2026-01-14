# spec/spec_helper.cr
require "spec"
require "../src/jelly"

# Type aliases for cleaner test code
alias EngineWrapper = Jelly::VirtualMachine::Engine
alias ProcessWrapper = Jelly::VirtualMachine::Process
alias InstructionWrapper = Jelly::VirtualMachine::Instruction
alias CodeWrapper = Jelly::VirtualMachine::Code
alias ValueWrapper = Jelly::VirtualMachine::Value
alias SubroutineWrapper = Jelly::VirtualMachine::Subroutine
alias MessageWrapper = Jelly::VirtualMachine::Message
alias MailboxWrapper = Jelly::VirtualMachine::Mailbox
alias ConfigurationWrapper = Jelly::VirtualMachine::Configuration
alias ProcessRegistryWrapper = Jelly::VirtualMachine::ProcessRegistry
alias EmulationExceptionWrapper = Jelly::VirtualMachine::EmulationException
alias TypeMismatchExceptionWrapper = Jelly::VirtualMachine::TypeMismatchException
alias InvalidAddressExceptionWrapper = Jelly::VirtualMachine::InvalidAddressException
alias ExitReasonWrapper = Jelly::VirtualMachine::Process::ExitReason

module TestHelpers
  # Create a test engine with default configuration
  def self.create_engine : EngineWrapper
    EngineWrapper.new
  end

  # Create a test process with given instructions
  def self.create_process(engine : EngineWrapper, instructions : Array(InstructionWrapper)) : ProcessWrapper
    process = engine.process_manager.create_process(instructions: instructions)
    engine.processes << process
    process
  end

  # Create a process with pre-populated stack
  def self.create_process_with_stack(engine : EngineWrapper, instructions : Array(InstructionWrapper), stack : Array(ValueWrapper)) : ProcessWrapper
    process = create_process(engine, instructions)
    stack.each { |v| process.stack.push(v) }
    process
  end

  # Execute instruction and return result
  def self.execute(engine : EngineWrapper, process : ProcessWrapper, instruction : InstructionWrapper) : ValueWrapper
    engine.execute(process, instruction)
  end

  # Execute all instructions until halt or dead
  def self.run_until_halt(engine : EngineWrapper, process : ProcessWrapper, max_iterations : Int32 = 1000) : Nil
    iterations = 0
    while process.state == ProcessWrapper::State::ALIVE && process.counter < process.instructions.size && iterations < max_iterations
      engine.execute(process, process.instructions[process.counter])
      iterations += 1
    end
  end

  # Create a simple instruction
  def self.inst(code : CodeWrapper, value : ValueWrapper = ValueWrapper.new) : InstructionWrapper
    InstructionWrapper.new(code, value)
  end

  # Create an integer value
  def self.int(n : Int64) : ValueWrapper
    ValueWrapper.new(n)
  end

  # Create an unsigned integer value
  def self.uint(n : UInt64) : ValueWrapper
    ValueWrapper.new(n)
  end

  # Create a float value
  def self.float(n : Float64) : ValueWrapper
    ValueWrapper.new(n)
  end

  # Create a string value
  def self.str(s : String) : ValueWrapper
    ValueWrapper.new(s)
  end

  # Create a boolean value
  def self.bool(b : Bool) : ValueWrapper
    ValueWrapper.new(b)
  end

  # Create a null value
  def self.null : ValueWrapper
    ValueWrapper.new
  end

  # Create a map value
  def self.map(h : Hash(String, ValueWrapper)) : ValueWrapper
    ValueWrapper.new(h)
  end

  # Create an array value
  def self.arr(a : Array(ValueWrapper)) : ValueWrapper
    ValueWrapper.new(a)
  end
end
