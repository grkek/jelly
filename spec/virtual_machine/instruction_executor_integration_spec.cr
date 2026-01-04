# spec/virtual_machine/instruction_executor_integration_spec.cr
require "../spec_helper"

describe "InstructionExecutor Integration" do
  describe "arithmetic sequences" do
    it "computes (10 + 5) * 3" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(10_i64)),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(5_i64)),
        InstructionWrapper.new(CodeWrapper::ADD),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(3_i64)),
        InstructionWrapper.new(CodeWrapper::MULTIPLY),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(45_i64)
    end

    it "computes factorial of 5 using a loop" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
        InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(5_i64)),
        InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(1_u64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(1_u64)),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(0_i64)),
        InstructionWrapper.new(CodeWrapper::GREATER_THAN),
        InstructionWrapper.new(CodeWrapper::JUMP_UNLESS, ValueWrapper.new(9_i64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(1_u64)),
        InstructionWrapper.new(CodeWrapper::MULTIPLY),
        InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(1_u64)),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
        InstructionWrapper.new(CodeWrapper::SUBTRACT),
        InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(1_u64)),
        InstructionWrapper.new(CodeWrapper::JUMP, ValueWrapper.new(-13_i64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(120_i64)
    end
  end

  describe "string manipulation sequences" do
    it "builds and measures a string" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("Hello")),
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new(", ")),
        InstructionWrapper.new(CodeWrapper::CONCATENATE),
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("World!")),
        InstructionWrapper.new(CodeWrapper::CONCATENATE),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::STRING_LENGTH),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.size.should eq(2)
      process.stack[0].to_s.should eq("Hello, World!")
      process.stack[1].to_u64.should eq(13_u64)
    end
  end

  describe "conditional logic sequences" do
    it "computes absolute value of negative number" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(-42_i64)),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(0_i64)),
        InstructionWrapper.new(CodeWrapper::LESS_THAN),
        InstructionWrapper.new(CodeWrapper::JUMP_UNLESS, ValueWrapper.new(2_i64)),
        InstructionWrapper.new(CodeWrapper::NEGATE),
        InstructionWrapper.new(CodeWrapper::JUMP, ValueWrapper.new(0_i64)),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(42_i64)
    end

    it "computes max of two numbers" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(10_i64)),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(25_i64)),
        InstructionWrapper.new(CodeWrapper::OVER),
        InstructionWrapper.new(CodeWrapper::OVER),
        InstructionWrapper.new(CodeWrapper::GREATER_THAN),
        InstructionWrapper.new(CodeWrapper::JUMP_IF, ValueWrapper.new(2_i64)),
        InstructionWrapper.new(CodeWrapper::SWAP),
        InstructionWrapper.new(CodeWrapper::POP),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(25_i64)
    end
  end

  describe "data structure sequences" do
    it "builds and manipulates a map" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::MAP_NEW),
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("name")),
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("Alice")),
        InstructionWrapper.new(CodeWrapper::MAP_SET),
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("age")),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(30_i64)),
        InstructionWrapper.new(CodeWrapper::MAP_SET),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::MAP_SIZE),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.size.should eq(2)
      map = process.stack[0].to_h
      map["name"].to_s.should eq("Alice")
      map["age"].to_i64.should eq(30_i64)
      process.stack[1].to_u64.should eq(2_u64)
    end

    it "builds and iterates an array" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::ARRAY_NEW),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
        InstructionWrapper.new(CodeWrapper::ARRAY_PUSH),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(2_i64)),
        InstructionWrapper.new(CodeWrapper::ARRAY_PUSH),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(3_i64)),
        InstructionWrapper.new(CodeWrapper::ARRAY_PUSH),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::ARRAY_LENGTH),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.size.should eq(2)
      arr = process.stack[0].to_a
      arr.size.should eq(3)
      arr[0].to_i64.should eq(1_i64)
      arr[1].to_i64.should eq(2_i64)
      arr[2].to_i64.should eq(3_i64)
      process.stack[1].to_u64.should eq(3_u64)
    end
  end

  describe "subroutine sequences" do
    it "calls subroutine to double a number" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(21_i64)),
        InstructionWrapper.new(CodeWrapper::CALL, ValueWrapper.new("double")),
        InstructionWrapper.new(CodeWrapper::HALT),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::ADD),
        InstructionWrapper.new(CodeWrapper::RETURN),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      process.subroutines["double"] = SubroutineWrapper.new("double", instructions[3..5], 3_u64)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(42_i64)
    end

    it "handles nested subroutine calls" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(5_i64)),
        InstructionWrapper.new(CodeWrapper::CALL, ValueWrapper.new("triple_double")),
        InstructionWrapper.new(CodeWrapper::HALT),
        InstructionWrapper.new(CodeWrapper::CALL, ValueWrapper.new("double")),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(3_i64)),
        InstructionWrapper.new(CodeWrapper::MULTIPLY),
        InstructionWrapper.new(CodeWrapper::RETURN),
        InstructionWrapper.new(CodeWrapper::DUPLICATE),
        InstructionWrapper.new(CodeWrapper::ADD),
        InstructionWrapper.new(CodeWrapper::RETURN),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      process.subroutines["triple_double"] = SubroutineWrapper.new("triple_double", instructions[3..6], 3_u64)
      process.subroutines["double"] = SubroutineWrapper.new("double", instructions[7..9], 7_u64)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(30_i64)
    end
  end

  describe "global variable sequences" do
    it "uses global variables across instructions" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(100_i64)),
        InstructionWrapper.new(CodeWrapper::STORE_GLOBAL, ValueWrapper.new("counter")),
        InstructionWrapper.new(CodeWrapper::LOAD_GLOBAL, ValueWrapper.new("counter")),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(50_i64)),
        InstructionWrapper.new(CodeWrapper::ADD),
        InstructionWrapper.new(CodeWrapper::STORE_GLOBAL, ValueWrapper.new("counter")),
        InstructionWrapper.new(CodeWrapper::LOAD_GLOBAL, ValueWrapper.new("counter")),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.last.to_i64.should eq(150_i64)
      process.globals["counter"].to_i64.should eq(150_i64)
    end
  end

  describe "inter-process communication sequences" do
    it "sends and receives messages between processes" do
      engine = EngineWrapper.new
      receiver_instructions = [
        InstructionWrapper.new(CodeWrapper::RECEIVE),
        InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(0_u64)),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      receiver = engine.process_manager.create_process(instructions: receiver_instructions)
      engine.processes << receiver
      tuple = {receiver.address, ValueWrapper.new("Hello from sender")}
      sender_instructions = [
        InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple)),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      sender = engine.process_manager.create_process(instructions: sender_instructions)
      engine.processes << sender
      engine.execute(sender, sender_instructions[0])
      engine.execute(sender, sender_instructions[1])
      TestHelpers.run_until_halt(engine, receiver)
      receiver.locals[0].to_s.should eq("Hello from sender")
    end

    it "uses process registry for named messaging" do
      engine = EngineWrapper.new
      receiver_instructions = [
        InstructionWrapper.new(CodeWrapper::REGISTER_PROCESS, ValueWrapper.new("worker")),
        InstructionWrapper.new(CodeWrapper::RECEIVE),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      receiver = engine.process_manager.create_process(instructions: receiver_instructions)
      engine.processes << receiver
      engine.execute(receiver, receiver_instructions[0])
      sender_instructions = [
        InstructionWrapper.new(CodeWrapper::WHEREIS_PROCESS, ValueWrapper.new("worker")),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      sender = engine.process_manager.create_process(instructions: sender_instructions)
      engine.processes << sender
      engine.execute(sender, sender_instructions[0])
      sender.stack.last.to_i64.should eq(receiver.address.to_i64)
    end
  end

  describe "print sequences" do
    it "prints multiple values in sequence" do
      engine = EngineWrapper.new
      instructions = [
        InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("Count: ")),
        InstructionWrapper.new(CodeWrapper::PRINT_LINE),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
        InstructionWrapper.new(CodeWrapper::PRINT_LINE),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(2_i64)),
        InstructionWrapper.new(CodeWrapper::PRINT_LINE),
        InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(3_i64)),
        InstructionWrapper.new(CodeWrapper::PRINT_LINE),
        InstructionWrapper.new(CodeWrapper::HALT),
      ]
      process = engine.process_manager.create_process(instructions: instructions)
      engine.processes << process
      TestHelpers.run_until_halt(engine, process)
      process.stack.should be_empty
      process.state.should eq(ProcessWrapper::State::DEAD)
    end
  end
end
