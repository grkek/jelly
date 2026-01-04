# spec/virtual_machine/instruction_executor_spec.cr
require "../spec_helper"

describe Jelly::VirtualMachine::InstructionExecutor do
  describe "stack manipulation" do
    describe "PUSH_INTEGER" do
      it "pushes an integer onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_i64.should eq(42_i64)
      end

      it "pushes an unsigned integer onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_UNSIGNED_INTEGER, ValueWrapper.new(42_u64))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_i64.should eq(42_u64)
      end

      it "increments the program counter" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64))]
        process = TestHelpers.create_process(engine, instructions)
        initial_counter = process.counter
        engine.execute(process, instructions[0])
        process.counter.should eq(initial_counter + 1)
      end

      it "raises TypeMismatchException for non-integer value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new("not an integer"))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "PUSH_FLOAT" do
      it "pushes a float onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_FLOAT, ValueWrapper.new(3.14))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_f64.should eq(3.14)
      end

      it "raises TypeMismatchException for non-float value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_FLOAT, ValueWrapper.new(42_i64))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "PUSH_STRING" do
      it "pushes a string onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("hello"))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_s.should eq("hello")
      end
    end

    describe "PUSH_BOOLEAN" do
      it "pushes true onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(true))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_b.should be_true
      end

      it "pushes false onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(false))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_b.should be_false
      end
    end

    describe "PUSH_NULL" do
      it "pushes null onto the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PUSH_NULL)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.is_null?.should be_true
      end
    end

    describe "POP" do
      it "removes the top value from the stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::POP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end

      it "raises on empty stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::POP)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "DUPLICATE" do
      it "duplicates the top value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DUPLICATE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, instructions[0])
        process.stack.size.should eq(2)
        process.stack[0].to_i64.should eq(42_i64)
        process.stack[1].to_i64.should eq(42_i64)
      end

      it "creates independent copies" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DUPLICATE)]
        hash = {"key" => ValueWrapper.new("value")}
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(hash)])
        engine.execute(process, instructions[0])
        hash["key"] = ValueWrapper.new("modified")
        process.stack[1].to_h["key"].to_s.should eq("value")
      end
    end

    describe "SWAP" do
      it "swaps the top two values" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SWAP)]
        stack = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack[0].to_i64.should eq(2_i64)
        process.stack[1].to_i64.should eq(1_i64)
      end

      it "raises on insufficient stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SWAP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(1_i64)])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "ROT" do
      it "rotates top three values: [a, b, c] → [b, c, a]" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ROT)]
        stack = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64), ValueWrapper.new(3_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack[0].to_i64.should eq(2_i64)
        process.stack[1].to_i64.should eq(3_i64)
        process.stack[2].to_i64.should eq(1_i64)
      end

      it "raises on insufficient stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ROT)]
        stack = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "OVER" do
      it "copies second value to top: [a, b] → [a, b, a]" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::OVER)]
        stack = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(3)
        process.stack[0].to_i64.should eq(1_i64)
        process.stack[1].to_i64.should eq(2_i64)
        process.stack[2].to_i64.should eq(1_i64)
      end
    end

    describe "DROP" do
      it "behaves like POP" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DROP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end
    end
  end

  describe "arithmetic operations" do
    describe "ADD" do
      it "adds two integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ADD)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.to_i64.should eq(15_i64)
      end

      it "adds two floats" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ADD)]
        stack = [ValueWrapper.new(1.5), ValueWrapper.new(2.5)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_f64.should eq(4.0)
      end

      it "returns float when mixing integer and float" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ADD)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(0.5)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.is_float?.should be_true
        process.stack.last.to_f64.should eq(10.5)
      end

      it "raises for non-numeric values" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ADD)]
        stack = [ValueWrapper.new("a"), ValueWrapper.new("b")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "SUBTRACT" do
      it "subtracts second from first: [a, b] → [a - b]" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SUBTRACT)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(3_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(7_i64)
      end

      it "handles negative results" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SUBTRACT)]
        stack = [ValueWrapper.new(3_i64), ValueWrapper.new(10_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(-7_i64)
      end
    end

    describe "MULTIPLY" do
      it "multiplies two integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::MULTIPLY)]
        stack = [ValueWrapper.new(6_i64), ValueWrapper.new(7_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(42_i64)
      end

      it "multiplies by zero" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::MULTIPLY)]
        stack = [ValueWrapper.new(100_i64), ValueWrapper.new(0_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(0_i64)
      end
    end

    describe "DIVIDE" do
      it "divides two integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DIVIDE)]
        stack = [ValueWrapper.new(20_i64), ValueWrapper.new(4_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(5_i64)
      end

      it "performs integer division for integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DIVIDE)]
        stack = [ValueWrapper.new(7_i64), ValueWrapper.new(2_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(3_i64)
      end

      it "raises on division by zero" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::DIVIDE)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(0_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "MODULO" do
      it "computes remainder" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::MODULO)]
        stack = [ValueWrapper.new(17_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(2_i64)
      end

      it "raises on modulo by zero" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::MODULO)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(0_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "NEGATE" do
      it "negates positive integer" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NEGATE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(-42_i64)
      end

      it "negates negative integer" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NEGATE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(-42_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(42_i64)
      end

      it "negates float" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NEGATE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(3.14)])
        engine.execute(process, instructions[0])
        process.stack.last.to_f64.should eq(-3.14)
      end

      it "raises for non-numeric value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NEGATE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("hello")])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end
  end

  describe "string operations" do
    describe "CONCATENATE" do
      it "concatenates two strings" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::CONCATENATE)]
        stack = [ValueWrapper.new("Hello, "), ValueWrapper.new("World!")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("Hello, World!")
      end

      it "handles empty strings" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::CONCATENATE)]
        stack = [ValueWrapper.new("Hello"), ValueWrapper.new("")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("Hello")
      end

      it "raises for non-string values" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::CONCATENATE)]
        stack = [ValueWrapper.new("Hello"), ValueWrapper.new(42_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "STRING_LENGTH" do
      it "returns length of string" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::STRING_LENGTH)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("Hello")])
        engine.execute(process, instructions[0])
        process.stack.last.to_u64.should eq(5_u64)
      end

      it "returns zero for empty string" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::STRING_LENGTH)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("")])
        engine.execute(process, instructions[0])
        process.stack.last.to_u64.should eq(0_u64)
      end
    end

    describe "SUBSTRING" do
      it "extracts substring" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SUBSTRING)]
        stack = [ValueWrapper.new("Hello, World!"), ValueWrapper.new(0_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("Hello")
      end

      it "extracts middle substring" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SUBSTRING)]
        stack = [ValueWrapper.new("Hello, World!"), ValueWrapper.new(7_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("World")
      end

      it "raises for out of bounds start" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SUBSTRING)]
        stack = [ValueWrapper.new("Hello"), ValueWrapper.new(10_i64), ValueWrapper.new(2_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end
  end

  describe "comparison operations" do
    describe "LESS_THAN" do
      it "returns true when first is less than second" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LESS_THAN)]
        stack = [ValueWrapper.new(5_i64), ValueWrapper.new(10_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns false when first is greater than second" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LESS_THAN)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "returns false when equal" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LESS_THAN)]
        stack = [ValueWrapper.new(5_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end
    end

    describe "GREATER_THAN" do
      it "returns true when first is greater than second" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::GREATER_THAN)]
        stack = [ValueWrapper.new(10_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end

    describe "LESS_THAN_OR_EQUAL" do
      it "returns true when equal" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LESS_THAN_OR_EQUAL)]
        stack = [ValueWrapper.new(5_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns true when less than" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LESS_THAN_OR_EQUAL)]
        stack = [ValueWrapper.new(3_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end

    describe "GREATER_THAN_OR_EQUAL" do
      it "returns true when equal" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::GREATER_THAN_OR_EQUAL)]
        stack = [ValueWrapper.new(5_i64), ValueWrapper.new(5_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end

    describe "EQUAL" do
      it "returns true for equal integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::EQUAL)]
        stack = [ValueWrapper.new(42_i64), ValueWrapper.new(42_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns false for different integers" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::EQUAL)]
        stack = [ValueWrapper.new(42_i64), ValueWrapper.new(43_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "returns true for equal strings" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::EQUAL)]
        stack = [ValueWrapper.new("hello"), ValueWrapper.new("hello")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns false for different types" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::EQUAL)]
        stack = [ValueWrapper.new(42_i64), ValueWrapper.new("42")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end
    end

    describe "NOT_EQUAL" do
      it "returns false for equal values" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NOT_EQUAL)]
        stack = [ValueWrapper.new(42_i64), ValueWrapper.new(42_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "returns true for different values" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NOT_EQUAL)]
        stack = [ValueWrapper.new(42_i64), ValueWrapper.new(43_i64)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end
  end

  describe "logical operations" do
    describe "AND" do
      it "returns true when both are true" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::AND)]
        stack = [ValueWrapper.new(true), ValueWrapper.new(true)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns false when first is false" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::AND)]
        stack = [ValueWrapper.new(false), ValueWrapper.new(true)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "returns false when second is false" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::AND)]
        stack = [ValueWrapper.new(true), ValueWrapper.new(false)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "treats truthy values as true" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::AND)]
        stack = [ValueWrapper.new(1_i64), ValueWrapper.new("hello")]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end

    describe "OR" do
      it "returns true when at least one is true" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::OR)]
        stack = [ValueWrapper.new(false), ValueWrapper.new(true)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns false when both are false" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::OR)]
        stack = [ValueWrapper.new(false), ValueWrapper.new(false)]
        process = TestHelpers.create_process_with_stack(engine, instructions, stack)
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end
    end

    describe "NOT" do
      it "returns false for true" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NOT)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(true)])
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end

      it "returns true for false" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NOT)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(false)])
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end

      it "returns true for falsy value (zero)" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::NOT)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(0_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
      end
    end
  end

  describe "variable operations" do
    describe "STORE_LOCAL and LOAD_LOCAL" do
      it "stores and loads local variable" do
        engine = TestHelpers.create_engine
        store_instruction = InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(0_u64))
        load_instruction = InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(0_u64))
        instructions = [store_instruction, load_instruction]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, store_instruction)
        process.stack.should be_empty
        engine.execute(process, load_instruction)
        process.stack.last.to_i64.should eq(42_i64)
      end

      it "expands locals array as needed" do
        engine = TestHelpers.create_engine
        store_instruction = InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(5_u64))
        instructions = [store_instruction]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(99_i64)])
        engine.execute(process, store_instruction)
        process.locals.size.should eq(6)
        process.locals[5].to_i64.should eq(99_i64)
      end

      it "raises for invalid load index" do
        engine = TestHelpers.create_engine
        load_instruction = InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(10_u64))
        instructions = [load_instruction]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, load_instruction)
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "STORE_GLOBAL and LOAD_GLOBAL" do
      it "stores and loads global variable" do
        engine = TestHelpers.create_engine
        store_instruction = InstructionWrapper.new(CodeWrapper::STORE_GLOBAL, ValueWrapper.new("counter"))
        load_instruction = InstructionWrapper.new(CodeWrapper::LOAD_GLOBAL, ValueWrapper.new("counter"))
        instructions = [store_instruction, load_instruction]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(100_i64)])
        engine.execute(process, store_instruction)
        process.stack.should be_empty
        engine.execute(process, load_instruction)
        process.stack.last.to_i64.should eq(100_i64)
      end

      it "raises for undefined global" do
        engine = TestHelpers.create_engine
        load_instruction = InstructionWrapper.new(CodeWrapper::LOAD_GLOBAL, ValueWrapper.new("undefined_var"))
        instructions = [load_instruction]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, load_instruction)
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end
  end

  describe "flow control" do
    describe "JUMP" do
      it "jumps to specified offset" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::JUMP, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(2_i64)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        engine.execute(process, instructions[1])
        process.counter.should eq(3_u64)
      end

      it "raises for invalid jump address" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::JUMP, ValueWrapper.new(100_i64))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "JUMP_IF" do
      it "jumps when condition is true" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(true)),
          InstructionWrapper.new(CodeWrapper::JUMP_IF, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        engine.execute(process, instructions[1])
        process.counter.should eq(3_u64)
        process.stack.should be_empty
      end

      it "does not jump when condition is false" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(false)),
          InstructionWrapper.new(CodeWrapper::JUMP_IF, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        engine.execute(process, instructions[1])
        process.counter.should eq(2_u64)
      end
    end

    describe "JUMP_UNLESS" do
      it "jumps when condition is false" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(false)),
          InstructionWrapper.new(CodeWrapper::JUMP_UNLESS, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        engine.execute(process, instructions[1])
        process.counter.should eq(3_u64)
      end

      it "does not jump when condition is true" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(true)),
          InstructionWrapper.new(CodeWrapper::JUMP_UNLESS, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        engine.execute(process, instructions[1])
        process.counter.should eq(2_u64)
      end
    end

    describe "HALT" do
      it "marks process as dead" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::HALT)]
        process = TestHelpers.create_process(engine, instructions)
        process.state.should eq(ProcessWrapper::State::ALIVE)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "CALL and RETURN" do
      it "calls subroutine and returns" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(10_i64)),
          InstructionWrapper.new(CodeWrapper::CALL, ValueWrapper.new("add_five")),
          InstructionWrapper.new(CodeWrapper::HALT),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(5_i64)),
          InstructionWrapper.new(CodeWrapper::ADD),
          InstructionWrapper.new(CodeWrapper::RETURN),
        ]
        process = TestHelpers.create_process(engine, instructions)
        process.subroutines["add_five"] = SubroutineWrapper.new("add_five", instructions[3..5], 3_u64)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(10_i64)
        engine.execute(process, instructions[1])
        process.counter.should eq(3_u64)
        process.call_stack.size.should eq(1)
        engine.execute(process, instructions[3])
        engine.execute(process, instructions[4])
        process.stack.last.to_i64.should eq(15_i64)
        engine.execute(process, instructions[5])
        process.counter.should eq(2_u64)
        process.stack.last.to_i64.should eq(15_i64)
      end

      it "terminates process on return with empty call stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::RETURN)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end
  end

  describe "map operations" do
    describe "MAP_NEW" do
      it "creates empty map" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::MAP_NEW)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.is_map?.should be_true
        process.stack.last.to_h.should be_empty
      end
    end

    describe "MAP_SET and MAP_GET" do
      it "sets and gets map value" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::MAP_NEW),
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("key")),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64)),
          InstructionWrapper.new(CodeWrapper::MAP_SET),
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("key")),
          InstructionWrapper.new(CodeWrapper::MAP_GET),
        ]
        process = TestHelpers.create_process(engine, instructions)
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.to_i64.should eq(42_i64)
      end
    end

    describe "MAP_DELETE" do
      it "deletes key from map" do
        engine = TestHelpers.create_engine
        hash = {"key" => ValueWrapper.new(42_i64)}
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("key")),
          InstructionWrapper.new(CodeWrapper::MAP_DELETE),
        ]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(hash)])
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.to_h.has_key?("key").should be_false
      end
    end

    describe "MAP_KEYS" do
      it "returns array of keys" do
        engine = TestHelpers.create_engine
        hash = {"a" => ValueWrapper.new(1_i64), "b" => ValueWrapper.new(2_i64)}
        instructions = [InstructionWrapper.new(CodeWrapper::MAP_KEYS)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(hash)])
        engine.execute(process, instructions[0])
        process.stack.last.is_array?.should be_true
        keys = process.stack.last.to_a.map(&.to_s)
        keys.should contain("a")
        keys.should contain("b")
      end
    end

    describe "MAP_SIZE" do
      it "returns number of entries" do
        engine = TestHelpers.create_engine
        hash = {"a" => ValueWrapper.new(1_i64), "b" => ValueWrapper.new(2_i64)}
        instructions = [InstructionWrapper.new(CodeWrapper::MAP_SIZE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(hash)])
        engine.execute(process, instructions[0])
        process.stack.last.to_u64.should eq(2_u64)
      end
    end
  end

  describe "array operations" do
    describe "ARRAY_NEW" do
      it "creates empty array" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ARRAY_NEW)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(1)
        process.stack.last.is_array?.should be_true
        process.stack.last.to_a.should be_empty
      end

      it "creates array with initial size" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::ARRAY_NEW, ValueWrapper.new(3_i64))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.last.to_a.size.should eq(3)
      end
    end

    describe "ARRAY_PUSH and ARRAY_GET" do
      it "pushes and gets array element" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::ARRAY_NEW),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64)),
          InstructionWrapper.new(CodeWrapper::ARRAY_PUSH),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(0_i64)),
          InstructionWrapper.new(CodeWrapper::ARRAY_GET),
        ]
        process = TestHelpers.create_process(engine, instructions)
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.to_i64.should eq(42_i64)
      end
    end

    describe "ARRAY_SET" do
      it "sets array element at index" do
        engine = TestHelpers.create_engine
        arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64), ValueWrapper.new(3_i64)]
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(99_i64)),
          InstructionWrapper.new(CodeWrapper::ARRAY_SET),
        ]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(arr)])
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.to_a[1].to_i64.should eq(99_i64)
      end

      it "raises for out of bounds index" do
        engine = TestHelpers.create_engine
        arr = [ValueWrapper.new(1_i64)]
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(10_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(99_i64)),
          InstructionWrapper.new(CodeWrapper::ARRAY_SET),
        ]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(arr)])
        instructions.each { |inst| engine.execute(process, inst) }
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "ARRAY_POP" do
      it "pops last element" do
        engine = TestHelpers.create_engine
        arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64), ValueWrapper.new(3_i64)]
        instructions = [InstructionWrapper.new(CodeWrapper::ARRAY_POP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(arr)])
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(3_i64)
        process.stack[0].to_a.size.should eq(2)
      end

      it "raises for empty array" do
        engine = TestHelpers.create_engine
        arr = Array(ValueWrapper).new
        instructions = [InstructionWrapper.new(CodeWrapper::ARRAY_POP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(arr)])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "ARRAY_LENGTH" do
      it "returns array length" do
        engine = TestHelpers.create_engine
        arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64), ValueWrapper.new(3_i64)]
        instructions = [InstructionWrapper.new(CodeWrapper::ARRAY_LENGTH)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(arr)])
        engine.execute(process, instructions[0])
        process.stack.last.to_u64.should eq(3_u64)
      end
    end
  end

  describe "concurrency / actor model" do
    describe "SPAWN" do
      it "creates a new process and pushes its address" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SPAWN)]
        process = TestHelpers.create_process(engine, instructions)
        initial_process_count = engine.processes.size
        engine.execute(process, instructions[0])
        engine.processes.size.should eq(initial_process_count + 1)
        process.stack.size.should eq(1)
        new_address = process.stack.last.to_i64
        new_address.should be > 0
      end
    end

    describe "SELF" do
      it "pushes own process address" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SELF)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(process.address.to_i64)
      end
    end

    describe "SEND" do
      it "sends message to another process" do
        engine = TestHelpers.create_engine
        receiver_instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE), InstructionWrapper.new(CodeWrapper::HALT)]
        receiver = TestHelpers.create_process(engine, receiver_instructions)
        tuple = {receiver.address, ValueWrapper.new("hello")}
        sender_instructions = [InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple)), InstructionWrapper.new(CodeWrapper::HALT)]
        sender = TestHelpers.create_process(engine, sender_instructions)
        engine.execute(sender, sender_instructions[0])
        receiver.mailbox.size.should eq(1)
        message = receiver.mailbox.peek
        message.should_not be_nil
        message.not_nil!.value.to_s.should eq("hello")
      end

      it "raises for invalid target address" do
        engine = TestHelpers.create_engine
        tuple = {9999_u64, ValueWrapper.new("hello")}
        instructions = [InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end

      it "sends message to named process" do
        engine = TestHelpers.create_engine
        receiver_instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE), InstructionWrapper.new(CodeWrapper::HALT)]
        receiver = TestHelpers.create_process(engine, receiver_instructions)
        engine.process_registry.register("receiver", receiver.address)
        tuple = {0_u64, ValueWrapper.new("receiver")}
        sender_instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("hello from named send")),
          InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple)),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        sender = TestHelpers.create_process(engine, sender_instructions)
        engine.execute(sender, sender_instructions[0])
        engine.execute(sender, sender_instructions[1])
        receiver.mailbox.size.should eq(1)
        receiver.mailbox.peek.not_nil!.value.to_s.should eq("hello from named send")
      end
    end

    describe "RECEIVE" do
      it "receives message from mailbox" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE)]
        process = TestHelpers.create_process(engine, instructions)
        message = MessageWrapper.new(0_u64, ValueWrapper.new("hello"))
        process.mailbox.push(message)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("hello")
      end

      it "sets process to WAITING when mailbox is empty" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::WAITING)
      end
    end

    describe "RECEIVE_SELECT" do
      it "receives message matching pattern" do
        engine = TestHelpers.create_engine
        pattern = ValueWrapper.new({"type" => ValueWrapper.new("greeting")})
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_SELECT, pattern)]
        process = TestHelpers.create_process(engine, instructions)
        non_matching = MessageWrapper.new(0_u64, ValueWrapper.new({"type" => ValueWrapper.new("farewell")}))
        matching = MessageWrapper.new(0_u64, ValueWrapper.new({"type" => ValueWrapper.new("greeting"), "text" => ValueWrapper.new("hello")}))
        process.mailbox.push(non_matching)
        process.mailbox.push(matching)
        engine.execute(process, instructions[0])
        process.stack.last.to_h["text"].to_s.should eq("hello")
        process.mailbox.size.should eq(1)
      end

      it "sets process to WAITING when no match found" do
        engine = TestHelpers.create_engine
        pattern = ValueWrapper.new({"type" => ValueWrapper.new("greeting")})
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_SELECT, pattern)]
        process = TestHelpers.create_process(engine, instructions)
        non_matching = MessageWrapper.new(0_u64, ValueWrapper.new({"type" => ValueWrapper.new("farewell")}))
        process.mailbox.push(non_matching)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::WAITING)
        process.waiting_for.should_not be_nil
      end

      it "receives from stack when operand is null" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_SELECT, ValueWrapper.new)]
        pattern = ValueWrapper.new({"cmd" => ValueWrapper.new("start")})
        process = TestHelpers.create_process_with_stack(engine, instructions, [pattern])
        matching = MessageWrapper.new(0_u64, ValueWrapper.new({"cmd" => ValueWrapper.new("start"), "data" => ValueWrapper.new(42_i64)}))
        process.mailbox.push(matching)
        engine.execute(process, instructions[0])
        process.stack.last.to_h["data"].to_i64.should eq(42_i64)
      end

      it "matches any message with null pattern" do
        engine = TestHelpers.create_engine
        sender = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << sender
        null_pattern = ValueWrapper.new
        instructions = [
          InstructionWrapper.new(CodeWrapper::RECEIVE_SELECT, null_pattern),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        message = MessageWrapper.new(sender.address, ValueWrapper.new("any message"))
        process.mailbox.push(message)
        engine.processes << process
        TestHelpers.run_until_halt(engine, process)
        process.stack.last.to_s.should eq("any message")
      end
    end

    describe "RECEIVE_TIMEOUT" do
      it "receives message before timeout" do
        engine = TestHelpers.create_engine
        tuple = {ValueWrapper.new, 1.0}
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_TIMEOUT, ValueWrapper.new(tuple))]
        process = TestHelpers.create_process(engine, instructions)
        message = MessageWrapper.new(0_u64, ValueWrapper.new("timely message"))
        process.mailbox.push(message)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(2)
        process.stack[0].to_s.should eq("timely message")
        process.stack[1].to_b.should be_true
      end

      it "sets process to WAITING with timeout when no message" do
        engine = TestHelpers.create_engine
        tuple = {ValueWrapper.new, 5.0}
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_TIMEOUT, ValueWrapper.new(tuple))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::WAITING)
        process.waiting_timeout.should_not be_nil
        process.waiting_timeout.not_nil!.should eq(5.seconds)
      end

      it "returns false immediately with zero timeout and no message" do
        engine = TestHelpers.create_engine
        tuple = {ValueWrapper.new, 0.0}
        instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE_TIMEOUT, ValueWrapper.new(tuple))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::ALIVE)
        process.stack.last.to_b.should be_false
      end
    end

    describe "SEND_AFTER" do
      it "schedules delayed message" do
        engine = TestHelpers.create_engine
        receiver_instructions = [InstructionWrapper.new(CodeWrapper::RECEIVE), InstructionWrapper.new(CodeWrapper::HALT)]
        receiver = TestHelpers.create_process(engine, receiver_instructions)
        tuple = {receiver.address, ValueWrapper.new("delayed hello"), 0.1}
        sender_instructions = [InstructionWrapper.new(CodeWrapper::SEND_AFTER, ValueWrapper.new(tuple)), InstructionWrapper.new(CodeWrapper::HALT)]
        sender = TestHelpers.create_process(engine, sender_instructions)
        engine.execute(sender, sender_instructions[0])
        engine.delayed_messages.size.should eq(1)
        delayed = engine.delayed_messages.first
        delayed[1].should eq(sender.address)
        delayed[2].should eq(receiver.address)
        delayed[3].to_s.should eq("delayed hello")
      end

      it "raises for invalid target address" do
        engine = TestHelpers.create_engine
        tuple = {9999_u64, ValueWrapper.new("delayed"), 1.0}
        instructions = [InstructionWrapper.new(CodeWrapper::SEND_AFTER, ValueWrapper.new(tuple))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "REGISTER_PROCESS" do
      it "registers process with a name" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::REGISTER_PROCESS, ValueWrapper.new("my_process"))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.registered_name.should eq("my_process")
        engine.process_registry.lookup("my_process").should eq(process.address)
      end

      it "returns false when name is already taken" do
        engine = TestHelpers.create_engine
        instructions1 = [InstructionWrapper.new(CodeWrapper::REGISTER_PROCESS, ValueWrapper.new("shared_name")), InstructionWrapper.new(CodeWrapper::HALT)]
        process1 = TestHelpers.create_process(engine, instructions1)
        engine.execute(process1, instructions1[0])
        instructions2 = [InstructionWrapper.new(CodeWrapper::REGISTER_PROCESS, ValueWrapper.new("shared_name")), InstructionWrapper.new(CodeWrapper::HALT)]
        process2 = TestHelpers.create_process(engine, instructions2)
        result = engine.execute(process2, instructions2[0])
        result.to_b.should be_false
        process2.registered_name.should be_nil
      end
    end

    describe "WHEREIS_PROCESS" do
      it "finds registered process address" do
        engine = TestHelpers.create_engine
        target_instructions = [InstructionWrapper.new(CodeWrapper::HALT)]
        target = TestHelpers.create_process(engine, target_instructions)
        engine.process_registry.register("target_process", target.address)
        instructions = [InstructionWrapper.new(CodeWrapper::WHEREIS_PROCESS, ValueWrapper.new("target_process"))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.last.to_i64.should eq(target.address.to_i64)
      end

      it "pushes null for unregistered name" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::WHEREIS_PROCESS, ValueWrapper.new("nonexistent"))]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.last.is_null?.should be_true
      end
    end

    describe "KILL" do
      it "kills another process" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::KILL),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        target_process = TestHelpers.create_process(engine, [] of InstructionWrapper)
        target_address = target_process.address
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(target_address.to_i64)])
        engine.processes << target_process
        engine.processes << process
        TestHelpers.run_until_halt(engine, process)
        target_process.state.should eq(ProcessWrapper::State::DEAD)
        process.stack.last.to_b.should be_true
      end

      it "returns false for non-existent process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::KILL)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(9999_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end
    end

    describe "PEEK_MAILBOX" do
      it "peeks at message without consuming" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PEEK_MAILBOX)]
        process = TestHelpers.create_process(engine, instructions)
        message = MessageWrapper.new(0_u64, ValueWrapper.new("peek me"))
        process.mailbox.push(message)
        engine.execute(process, instructions[0])
        process.stack.last.to_s.should eq("peek me")
        process.mailbox.size.should eq(1)
      end

      it "pushes null when mailbox is empty" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PEEK_MAILBOX)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.last.is_null?.should be_true
      end
    end

    describe "SLEEP" do
      it "sleeps for specified duration" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SLEEP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(0.001)])
        start_time = Time.monotonic
        engine.execute(process, instructions[0])
        elapsed = Time.monotonic - start_time
        elapsed.should be >= 0.001.seconds
        process.state.should eq(ProcessWrapper::State::ALIVE)
      end

      it "handles zero sleep duration" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SLEEP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(0.0)])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::ALIVE)
      end

      it "raises for non-numeric value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SLEEP)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("not a number")])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end
  end

  describe "I/O operations" do
    describe "PRINT_LINE" do
      it "pops and prints value from stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("Hello, World!")])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
        process.state.should eq(ProcessWrapper::State::ALIVE)
      end

      it "raises on empty stack" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end

      it "prints integer value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(42_i64)])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end

      it "prints float value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(3.14)])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end

      it "prints boolean value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(true)])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end

      it "prints null value" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PRINT_LINE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new])
        engine.execute(process, instructions[0])
        process.stack.should be_empty
      end
    end
  end

  describe "error handling" do
    describe "THROW" do
      it "marks process as dead" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::THROW)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("Error message")])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "TRY_CATCH" do
      it "catches exception and jumps to handler" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::TRY_CATCH, ValueWrapper.new(3_i64)), # offset to END_TRY +1
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("error")),
          InstructionWrapper.new(CodeWrapper::THROW),
          InstructionWrapper.new(CodeWrapper::END_TRY),
          InstructionWrapper.new(CodeWrapper::CATCH),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        TestHelpers.run_until_halt(engine, process)
        process.counter.should eq(6_u64) # HALT
        process.stack.last.to_h["message"].to_s.should eq("THROW: error")
      end

      it "executes normally without exception" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::TRY_CATCH, ValueWrapper.new(3_i64)),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64)),
          InstructionWrapper.new(CodeWrapper::END_TRY),
          InstructionWrapper.new(CodeWrapper::HALT),
          InstructionWrapper.new(CodeWrapper::CATCH),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        TestHelpers.run_until_halt(engine, process)
        process.counter.should eq(4_u64) # first HALT
        process.stack.last.to_i64.should eq(42_i64)
      end
    end

    describe "RETHROW" do
      it "rethows exception to outer handler" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::TRY_CATCH, ValueWrapper.new(9_i64)), # outer catch
          InstructionWrapper.new(CodeWrapper::TRY_CATCH, ValueWrapper.new(3_i64)), # inner catch
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("error")),
          InstructionWrapper.new(CodeWrapper::THROW),
          InstructionWrapper.new(CodeWrapper::END_TRY),
          InstructionWrapper.new(CodeWrapper::CATCH),
          InstructionWrapper.new(CodeWrapper::RETHROW),
          InstructionWrapper.new(CodeWrapper::END_TRY),
          InstructionWrapper.new(CodeWrapper::CATCH),
          InstructionWrapper.new(CodeWrapper::HALT),
        ]
        process = TestHelpers.create_process(engine, instructions)
        TestHelpers.run_until_halt(engine, process)
        process.counter.should eq(10_u64) # outer HALT
        process.stack.last.to_h["message"].to_s.should eq("THROW: error")
      end
    end
  end

  describe "fault tolerance" do
    describe "LINK" do
      it "links to another process" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        instructions = [InstructionWrapper.new(CodeWrapper::LINK)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(target.address.to_i64)])
        engine.execute(process, instructions[0])
        engine.process_links.linked?(process.address, target.address).should be_true
      end

      it "raises for invalid process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::LINK)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(9999_i64)])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
      end
    end

    describe "UNLINK" do
      it "unlinks from another process" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        process = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        engine.processes << process
        engine.process_links.link(process.address, target.address)
        instructions = [InstructionWrapper.new(CodeWrapper::UNLINK)]
        process.stack.push(ValueWrapper.new(target.address.to_i64))
        engine.execute(process, instructions[0])
        engine.process_links.linked?(process.address, target.address).should be_false
        process.stack.last.to_b.should be_true
      end
    end

    describe "MONITOR" do
      it "monitors another process" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        instructions = [InstructionWrapper.new(CodeWrapper::MONITOR)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(target.address.to_i64)])
        engine.execute(process, instructions[0])
        ref_id = process.stack.last.to_i64.to_u64
        engine.process_links.get_monitors(process.address).map(&.id).should contain(ref_id)
      end
    end

    describe "DEMONITOR" do
      it "demonitors a reference" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        process = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        engine.processes << process
        ref = engine.process_links.monitor(process.address, target.address)
        instructions = [InstructionWrapper.new(CodeWrapper::DEMONITOR)]
        process.stack.push(ValueWrapper.new(ref.id.to_i64))
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
        engine.process_links.get_monitors(process.address).should be_empty
      end
    end

    describe "TRAP_EXIT" do
      it "enables/disables trap_exit" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::TRAP_EXIT)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(true)])
        engine.execute(process, instructions[0])
        engine.process_links.traps_exit?(process.address).should be_true
        process.stack.last.to_b.should be_false # old value
      end
    end

    describe "EXIT_SELF" do
      it "exits current process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::EXIT_SELF)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new("normal")])
        engine.execute(process, instructions[0])
        process.state.should eq(ProcessWrapper::State::DEAD)
        process.exit_reason.not_nil!.type.should eq(ExitReasonWrapper::Type::Normal)
      end
    end

    describe "SPAWN_LINK" do
      it "spawns and links new process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SPAWN_LINK)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        child_address = process.stack.last.to_i64.to_u64
        child = engine.processes.find { |p| p.address == child_address }
        child.should_not be_nil
        engine.process_links.linked?(process.address, child_address).should be_true
      end
    end

    describe "SPAWN_MONITOR" do
      it "spawns and monitors new process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::SPAWN_MONITOR)]
        process = TestHelpers.create_process(engine, instructions)
        engine.execute(process, instructions[0])
        process.stack.size.should eq(2)
        ref_id = process.stack.pop.to_i64.to_u64
        child_address = process.stack.last.to_i64.to_u64
        engine.process_links.get_monitors(process.address).map(&.id).should contain(ref_id)
      end
    end

    describe "IS_ALIVE" do
      it "checks if process is alive" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        instructions = [InstructionWrapper.new(CodeWrapper::IS_ALIVE)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(target.address.to_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_true
        target.state = ProcessWrapper::State::DEAD
        process.stack.pop
        process.stack.push(ValueWrapper.new(target.address.to_i64))
        engine.execute(process, instructions[0])
        process.stack.last.to_b.should be_false
      end
    end

    describe "PROCESS_INFO" do
      it "gets process info" do
        engine = TestHelpers.create_engine
        target = TestHelpers.create_process(engine, [] of InstructionWrapper)
        engine.processes << target
        instructions = [InstructionWrapper.new(CodeWrapper::PROCESS_INFO)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(target.address.to_i64)])
        engine.execute(process, instructions[0])
        info = process.stack.last.to_h
        info["address"].to_i64.to_u64.should eq(target.address)
        info["state"].to_s.should eq("ALIVE")
      end

      it "returns null for non-existent process" do
        engine = TestHelpers.create_engine
        instructions = [InstructionWrapper.new(CodeWrapper::PROCESS_INFO)]
        process = TestHelpers.create_process_with_stack(engine, instructions, [ValueWrapper.new(9999_i64)])
        engine.execute(process, instructions[0])
        process.stack.last.is_null?.should be_true
      end
    end
  end

  describe "process flags" do
    describe "SET_FLAG and GET_FLAG" do
      it "sets and gets flag" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("my_flag")),
          InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64)),
          InstructionWrapper.new(CodeWrapper::SET_FLAG),
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("my_flag")),
          InstructionWrapper.new(CodeWrapper::GET_FLAG),
        ]
        process = TestHelpers.create_process(engine, instructions)
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.to_i64.should eq(42_i64)
      end

      it "returns null for undefined flag" do
        engine = TestHelpers.create_engine
        instructions = [
          InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("undefined")),
          InstructionWrapper.new(CodeWrapper::GET_FLAG),
        ]
        process = TestHelpers.create_process(engine, instructions)
        instructions.each { |inst| engine.execute(process, inst) }
        process.stack.last.is_null?.should be_true
      end
    end
  end

  describe "dead process handling" do
    it "does not execute instructions for dead process" do
      engine = TestHelpers.create_engine
      instructions = [InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64))]
      process = TestHelpers.create_process(engine, instructions)
      process.state = ProcessWrapper::State::DEAD
      initial_stack_size = process.stack.size
      engine.execute(process, instructions[0])
      process.stack.size.should eq(initial_stack_size)
    end
  end

  describe "stack overflow protection" do
    it "raises on stack overflow" do
      engine = TestHelpers.create_engine
      engine.configuration.max_stack_size = 5
      instructions = [InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(1_i64))]
      process = TestHelpers.create_process(engine, instructions)
      5.times { process.stack.push(ValueWrapper.new(0_i64)) }
      engine.execute(process, instructions[0])
      process.state.should eq(ProcessWrapper::State::DEAD)
    end
  end
end
