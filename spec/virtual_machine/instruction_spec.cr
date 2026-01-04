require "spec"
require "../spec_helper"

describe Jelly::VirtualMachine::Instruction do
  describe "#initialize" do
    it "creates instruction with code only" do
      instruction = InstructionWrapper.new(CodeWrapper::POP)
      instruction.code.should eq(CodeWrapper::POP)
      instruction.value.is_null?.should be_true
    end

    it "creates instruction with code and integer value" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64))
      instruction.code.should eq(CodeWrapper::PUSH_INTEGER)
      instruction.value.to_i64.should eq(42_i64)
    end

    it "creates instruction with code and unsigned integer value" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_UNSIGNED_INTEGER, ValueWrapper.new(42_u64))
      instruction.code.should eq(CodeWrapper::PUSH_UNSIGNED_INTEGER)
      instruction.value.to_i64.should eq(42_u64)
    end

    it "creates instruction with code and string value" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("hello"))
      instruction.code.should eq(CodeWrapper::PUSH_STRING)
      instruction.value.to_s.should eq("hello")
    end

    it "creates instruction with code and float value" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_FLOAT, ValueWrapper.new(3.14))
      instruction.code.should eq(CodeWrapper::PUSH_FLOAT)
      instruction.value.to_f64.should eq(3.14)
    end

    it "creates instruction with code and boolean value" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(true))
      instruction.code.should eq(CodeWrapper::PUSH_BOOLEAN)
      instruction.value.to_b.should be_true
    end

    it "creates instruction with Tuple(UInt64, Value) for SEND" do
      tuple = {1_u64, ValueWrapper.new("message")}
      instruction = InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::SEND)
      instruction.value.type.should eq("Tuple(UInt64, Jelly::VirtualMachine::Value)")
    end

    it "creates instruction with Tuple(Value, Float64) for RECEIVE_TIMEOUT" do
      tuple = {ValueWrapper.new("pattern"), 5.0}
      instruction = InstructionWrapper.new(CodeWrapper::RECEIVE_TIMEOUT, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::RECEIVE_TIMEOUT)
      instruction.value.type.should eq("Tuple(Value, Float64)")
    end

    it "creates instruction with Tuple(UInt64, Value, Float64) for SEND_AFTER" do
      tuple = {1_u64, ValueWrapper.new("delayed"), 2.5}
      instruction = InstructionWrapper.new(CodeWrapper::SEND_AFTER, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::SEND_AFTER)
      instruction.value.type.should eq("Tuple(UInt64, Value, Float64)")
    end
  end

  describe "#code" do
    it "returns the instruction code" do
      instruction = InstructionWrapper.new(CodeWrapper::ADD)
      instruction.code.should eq(CodeWrapper::ADD)
    end
  end

  describe "#value" do
    it "returns the instruction value" do
      value = ValueWrapper.new(100_i64)
      instruction = InstructionWrapper.new(CodeWrapper::JUMP, value)
      instruction.value.to_i64.should eq(100_i64)
    end

    it "returns null value when not provided" do
      instruction = InstructionWrapper.new(CodeWrapper::HALT)
      instruction.value.is_null?.should be_true
    end
  end

  describe "stack manipulation instructions" do
    it "creates POP instruction" do
      InstructionWrapper.new(CodeWrapper::POP).code.should eq(CodeWrapper::POP)
    end

    it "creates DUPLICATE instruction" do
      InstructionWrapper.new(CodeWrapper::DUPLICATE).code.should eq(CodeWrapper::DUPLICATE)
    end

    it "creates SWAP instruction" do
      InstructionWrapper.new(CodeWrapper::SWAP).code.should eq(CodeWrapper::SWAP)
    end

    it "creates ROT instruction" do
      InstructionWrapper.new(CodeWrapper::ROT).code.should eq(CodeWrapper::ROT)
    end

    it "creates OVER instruction" do
      InstructionWrapper.new(CodeWrapper::OVER).code.should eq(CodeWrapper::OVER)
    end

    it "creates DROP instruction" do
      InstructionWrapper.new(CodeWrapper::DROP).code.should eq(CodeWrapper::DROP)
    end
  end

  describe "push instructions" do
    it "creates PUSH_INTEGER instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_INTEGER, ValueWrapper.new(42_i64))
      instruction.code.should eq(CodeWrapper::PUSH_INTEGER)
      instruction.value.is_integer?.should be_true
    end

    it "creates PUSH_FLOAT instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_FLOAT, ValueWrapper.new(3.14))
      instruction.code.should eq(CodeWrapper::PUSH_FLOAT)
      instruction.value.is_float?.should be_true
    end

    it "creates PUSH_STRING instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_STRING, ValueWrapper.new("test"))
      instruction.code.should eq(CodeWrapper::PUSH_STRING)
      instruction.value.is_string?.should be_true
    end

    it "creates PUSH_BOOLEAN instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_BOOLEAN, ValueWrapper.new(true))
      instruction.code.should eq(CodeWrapper::PUSH_BOOLEAN)
      instruction.value.is_boolean?.should be_true
    end

    it "creates PUSH_NULL instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::PUSH_NULL)
      instruction.code.should eq(CodeWrapper::PUSH_NULL)
    end
  end

  describe "arithmetic instructions" do
    it "creates ADD instruction" do
      InstructionWrapper.new(CodeWrapper::ADD).code.should eq(CodeWrapper::ADD)
    end

    it "creates SUBTRACT instruction" do
      InstructionWrapper.new(CodeWrapper::SUBTRACT).code.should eq(CodeWrapper::SUBTRACT)
    end

    it "creates MULTIPLY instruction" do
      InstructionWrapper.new(CodeWrapper::MULTIPLY).code.should eq(CodeWrapper::MULTIPLY)
    end

    it "creates DIVIDE instruction" do
      InstructionWrapper.new(CodeWrapper::DIVIDE).code.should eq(CodeWrapper::DIVIDE)
    end

    it "creates MODULO instruction" do
      InstructionWrapper.new(CodeWrapper::MODULO).code.should eq(CodeWrapper::MODULO)
    end

    it "creates NEGATE instruction" do
      InstructionWrapper.new(CodeWrapper::NEGATE).code.should eq(CodeWrapper::NEGATE)
    end
  end

  describe "comparison instructions" do
    it "creates LESS_THAN instruction" do
      InstructionWrapper.new(CodeWrapper::LESS_THAN).code.should eq(CodeWrapper::LESS_THAN)
    end

    it "creates GREATER_THAN instruction" do
      InstructionWrapper.new(CodeWrapper::GREATER_THAN).code.should eq(CodeWrapper::GREATER_THAN)
    end

    it "creates LESS_THAN_OR_EQUAL instruction" do
      InstructionWrapper.new(CodeWrapper::LESS_THAN_OR_EQUAL).code.should eq(CodeWrapper::LESS_THAN_OR_EQUAL)
    end

    it "creates GREATER_THAN_OR_EQUAL instruction" do
      InstructionWrapper.new(CodeWrapper::GREATER_THAN_OR_EQUAL).code.should eq(CodeWrapper::GREATER_THAN_OR_EQUAL)
    end

    it "creates EQUAL instruction" do
      InstructionWrapper.new(CodeWrapper::EQUAL).code.should eq(CodeWrapper::EQUAL)
    end

    it "creates NOT_EQUAL instruction" do
      InstructionWrapper.new(CodeWrapper::NOT_EQUAL).code.should eq(CodeWrapper::NOT_EQUAL)
    end
  end

  describe "logical instructions" do
    it "creates AND instruction" do
      InstructionWrapper.new(CodeWrapper::AND).code.should eq(CodeWrapper::AND)
    end

    it "creates OR instruction" do
      InstructionWrapper.new(CodeWrapper::OR).code.should eq(CodeWrapper::OR)
    end

    it "creates NOT instruction" do
      InstructionWrapper.new(CodeWrapper::NOT).code.should eq(CodeWrapper::NOT)
    end
  end

  describe "variable instructions" do
    it "creates LOAD_LOCAL instruction with index" do
      instruction = InstructionWrapper.new(CodeWrapper::LOAD_LOCAL, ValueWrapper.new(0_u64))
      instruction.code.should eq(CodeWrapper::LOAD_LOCAL)
      instruction.value.to_u64.should eq(0_u64)
    end

    it "creates STORE_LOCAL instruction with index" do
      instruction = InstructionWrapper.new(CodeWrapper::STORE_LOCAL, ValueWrapper.new(0_u64))
      instruction.code.should eq(CodeWrapper::STORE_LOCAL)
      instruction.value.to_u64.should eq(0_u64)
    end

    it "creates LOAD_GLOBAL instruction with name" do
      instruction = InstructionWrapper.new(CodeWrapper::LOAD_GLOBAL, ValueWrapper.new("counter"))
      instruction.code.should eq(CodeWrapper::LOAD_GLOBAL)
      instruction.value.to_s.should eq("counter")
    end

    it "creates STORE_GLOBAL instruction with name" do
      instruction = InstructionWrapper.new(CodeWrapper::STORE_GLOBAL, ValueWrapper.new("counter"))
      instruction.code.should eq(CodeWrapper::STORE_GLOBAL)
      instruction.value.to_s.should eq("counter")
    end
  end

  describe "flow control instructions" do
    it "creates CALL instruction with subroutine name" do
      instruction = InstructionWrapper.new(CodeWrapper::CALL, ValueWrapper.new("my_function"))
      instruction.code.should eq(CodeWrapper::CALL)
      instruction.value.to_s.should eq("my_function")
    end

    it "creates RETURN instruction" do
      InstructionWrapper.new(CodeWrapper::RETURN).code.should eq(CodeWrapper::RETURN)
    end

    it "creates JUMP instruction with offset" do
      instruction = InstructionWrapper.new(CodeWrapper::JUMP, ValueWrapper.new(10_i64))
      instruction.code.should eq(CodeWrapper::JUMP)
      instruction.value.to_i64.should eq(10_i64)
    end

    it "creates JUMP_IF instruction with offset" do
      instruction = InstructionWrapper.new(CodeWrapper::JUMP_IF, ValueWrapper.new(5_i64))
      instruction.code.should eq(CodeWrapper::JUMP_IF)
      instruction.value.to_i64.should eq(5_i64)
    end

    it "creates JUMP_UNLESS instruction with offset" do
      instruction = InstructionWrapper.new(CodeWrapper::JUMP_UNLESS, ValueWrapper.new(-3_i64))
      instruction.code.should eq(CodeWrapper::JUMP_UNLESS)
      instruction.value.to_i64.should eq(-3_i64)
    end

    it "creates HALT instruction" do
      InstructionWrapper.new(CodeWrapper::HALT).code.should eq(CodeWrapper::HALT)
    end
  end

  describe "string operation instructions" do
    it "creates CONCATENATE instruction" do
      InstructionWrapper.new(CodeWrapper::CONCATENATE).code.should eq(CodeWrapper::CONCATENATE)
    end

    it "creates STRING_LENGTH instruction" do
      InstructionWrapper.new(CodeWrapper::STRING_LENGTH).code.should eq(CodeWrapper::STRING_LENGTH)
    end

    it "creates SUBSTRING instruction" do
      InstructionWrapper.new(CodeWrapper::SUBSTRING).code.should eq(CodeWrapper::SUBSTRING)
    end
  end

  describe "map operation instructions" do
    it "creates MAP_NEW instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_NEW).code.should eq(CodeWrapper::MAP_NEW)
    end

    it "creates MAP_GET instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_GET).code.should eq(CodeWrapper::MAP_GET)
    end

    it "creates MAP_SET instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_SET).code.should eq(CodeWrapper::MAP_SET)
    end

    it "creates MAP_DELETE instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_DELETE).code.should eq(CodeWrapper::MAP_DELETE)
    end

    it "creates MAP_KEYS instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_KEYS).code.should eq(CodeWrapper::MAP_KEYS)
    end

    it "creates MAP_SIZE instruction" do
      InstructionWrapper.new(CodeWrapper::MAP_SIZE).code.should eq(CodeWrapper::MAP_SIZE)
    end
  end

  describe "array operation instructions" do
    it "creates ARRAY_NEW instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_NEW).code.should eq(CodeWrapper::ARRAY_NEW)
    end

    it "creates ARRAY_NEW instruction with initial size" do
      instruction = InstructionWrapper.new(CodeWrapper::ARRAY_NEW, ValueWrapper.new(10_i64))
      instruction.code.should eq(CodeWrapper::ARRAY_NEW)
      instruction.value.to_i64.should eq(10_i64)
    end

    it "creates ARRAY_GET instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_GET).code.should eq(CodeWrapper::ARRAY_GET)
    end

    it "creates ARRAY_SET instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_SET).code.should eq(CodeWrapper::ARRAY_SET)
    end

    it "creates ARRAY_PUSH instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_PUSH).code.should eq(CodeWrapper::ARRAY_PUSH)
    end

    it "creates ARRAY_POP instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_POP).code.should eq(CodeWrapper::ARRAY_POP)
    end

    it "creates ARRAY_LENGTH instruction" do
      InstructionWrapper.new(CodeWrapper::ARRAY_LENGTH).code.should eq(CodeWrapper::ARRAY_LENGTH)
    end
  end

  describe "I/O instructions" do
    it "creates PRINT_LINE instruction" do
      InstructionWrapper.new(CodeWrapper::PRINT_LINE).code.should eq(CodeWrapper::PRINT_LINE)
    end

    it "creates READ_LINE instruction" do
      InstructionWrapper.new(CodeWrapper::READ_LINE).code.should eq(CodeWrapper::READ_LINE)
    end
  end

  describe "error handling instructions" do
    it "creates THROW instruction" do
      InstructionWrapper.new(CodeWrapper::THROW).code.should eq(CodeWrapper::THROW)
    end
  end

  describe "concurrency instructions" do
    it "creates SPAWN instruction" do
      InstructionWrapper.new(CodeWrapper::SPAWN).code.should eq(CodeWrapper::SPAWN)
    end

    it "creates SELF instruction" do
      InstructionWrapper.new(CodeWrapper::SELF).code.should eq(CodeWrapper::SELF)
    end

    it "creates SEND instruction" do
      tuple = {1_u64, ValueWrapper.new("msg")}
      instruction = InstructionWrapper.new(CodeWrapper::SEND, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::SEND)
    end

    it "creates RECEIVE instruction" do
      InstructionWrapper.new(CodeWrapper::RECEIVE).code.should eq(CodeWrapper::RECEIVE)
    end

    it "creates RECEIVE_SELECT instruction" do
      InstructionWrapper.new(CodeWrapper::RECEIVE_SELECT).code.should eq(CodeWrapper::RECEIVE_SELECT)
    end

    it "creates RECEIVE_TIMEOUT instruction" do
      tuple = {ValueWrapper.new("pattern"), 5.0}
      instruction = InstructionWrapper.new(CodeWrapper::RECEIVE_TIMEOUT, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::RECEIVE_TIMEOUT)
    end

    it "creates SEND_AFTER instruction" do
      tuple = {1_u64, ValueWrapper.new("delayed"), 2.5}
      instruction = InstructionWrapper.new(CodeWrapper::SEND_AFTER, ValueWrapper.new(tuple))
      instruction.code.should eq(CodeWrapper::SEND_AFTER)
    end

    it "creates REGISTER_PROCESS instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::REGISTER_PROCESS, ValueWrapper.new("my_process"))
      instruction.code.should eq(CodeWrapper::REGISTER_PROCESS)
    end

    it "creates WHEREIS_PROCESS instruction" do
      instruction = InstructionWrapper.new(CodeWrapper::WHEREIS_PROCESS, ValueWrapper.new("my_process"))
      instruction.code.should eq(CodeWrapper::WHEREIS_PROCESS)
    end

    it "creates KILL instruction" do
      InstructionWrapper.new(CodeWrapper::KILL).code.should eq(CodeWrapper::KILL)
    end

    it "creates SLEEP instruction" do
      InstructionWrapper.new(CodeWrapper::SLEEP).code.should eq(CodeWrapper::SLEEP)
    end

    it "creates PEEK_MAILBOX instruction" do
      InstructionWrapper.new(CodeWrapper::PEEK_MAILBOX).code.should eq(CodeWrapper::PEEK_MAILBOX)
    end
  end
end
