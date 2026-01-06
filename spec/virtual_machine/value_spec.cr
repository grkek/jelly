# spec/virtual_machine/value_spec.cr
require "../spec_helper"

describe Jelly::VirtualMachine::Value do
  describe "#initialize" do
    it "creates a null value with no arguments" do
      value = ValueWrapper.new
      value.is_null?.should be_true
      value.type.should eq("Null")
    end

    it "creates a null value from nil" do
      value = ValueWrapper.new(nil)
      value.is_null?.should be_true
    end

    it "creates an integer value" do
      value = ValueWrapper.new(42_i64)
      value.is_integer?.should be_true
      value.type.should eq("Integer")
      value.to_i64.should eq(42_i64)
    end

    it "creates an unsigned integer value" do
      value = ValueWrapper.new(42_u64)
      value.is_unsigned_integer?.should be_true
      value.type.should eq("UnsignedInteger")
      value.to_u64.should eq(42_u64)
    end

    it "creates a float value" do
      value = ValueWrapper.new(3.14)
      value.is_float?.should be_true
      value.type.should eq("Float")
      value.to_f64.should eq(3.14)
    end

    it "creates a string value" do
      value = ValueWrapper.new("hello")
      value.is_string?.should be_true
      value.type.should eq("String")
      value.to_s.should eq("hello")
    end

    it "creates a boolean true value" do
      value = ValueWrapper.new(true)
      value.is_boolean?.should be_true
      value.type.should eq("Boolean")
      value.to_bool.should be_true
    end

    it "creates a boolean false value" do
      value = ValueWrapper.new(false)
      value.is_boolean?.should be_true
      value.to_bool.should be_false
    end

    it "creates a map value" do
      hash = {"key" => ValueWrapper.new("value")}
      value = ValueWrapper.new(hash)
      value.is_map?.should be_true
      value.type.should eq("Map")
      value.to_h["key"].to_s.should eq("value")
    end

    it "creates an array value" do
      arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      value = ValueWrapper.new(arr)
      value.is_array?.should be_true
      value.type.should eq("Array")
      value.to_a.size.should eq(2)
    end

    it "creates a Tuple(UInt64, Value) for SEND" do
      tuple = {1_u64, ValueWrapper.new("message")}
      value = ValueWrapper.new(tuple)
      value.is_custom?.should be_true
      value.is_tuple?.should be_true
      value.type.should eq("Tuple(UInt64, Jelly::VirtualMachine::Value)")
    end

    it "creates a Tuple(Value, Float64) for RECEIVE_TIMEOUT" do
      tuple = {ValueWrapper.new("pattern"), 5.0}
      value = ValueWrapper.new(tuple)
      value.is_custom?.should be_true
      value.is_tuple?.should be_true
      value.type.should eq("Tuple(Value, Float64)")
    end

    it "creates a Tuple(UInt64, Value, Float64) for SEND_AFTER" do
      tuple = {1_u64, ValueWrapper.new("delayed"), 2.5}
      value = ValueWrapper.new(tuple)
      value.is_custom?.should be_true
      value.is_tuple?.should be_true
      value.type.should eq("Tuple(UInt64, Value, Float64)")
    end

    it "creates a custom value for arbitrary objects" do
      value = ValueWrapper.new(Exception.new("test"))
      value.is_custom?.should be_true
      value.type.should eq("Exception")
    end
  end

  describe "#is_numeric?" do
    it "returns true for integer" do
      ValueWrapper.new(1_i64).is_numeric?.should be_true
    end

    it "returns true for unsigned integer" do
      ValueWrapper.new(1_u64).is_numeric?.should be_true
    end

    it "returns true for float" do
      ValueWrapper.new(1.0).is_numeric?.should be_true
    end

    it "returns false for string" do
      ValueWrapper.new("1").is_numeric?.should be_false
    end

    it "returns false for boolean" do
      ValueWrapper.new(true).is_numeric?.should be_false
    end

    it "returns false for null" do
      ValueWrapper.new.is_numeric?.should be_false
    end
  end

  describe "#to_i64" do
    it "converts integer to i64" do
      ValueWrapper.new(42_i64).to_i64.should eq(42_i64)
    end

    it "converts unsigned integer to i64" do
      ValueWrapper.new(42_u64).to_i64.should eq(42_i64)
    end

    it "converts float to i64 by truncation" do
      ValueWrapper.new(3.9).to_i64.should eq(3_i64)
    end

    it "converts true to 1" do
      ValueWrapper.new(true).to_i64.should eq(1_i64)
    end

    it "converts false to 0" do
      ValueWrapper.new(false).to_i64.should eq(0_i64)
    end

    it "raises for string" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new("42").to_i64
      end
    end

    it "raises for null" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new.to_i64
      end
    end

    it "raises for map" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(Hash(String, ValueWrapper).new).to_i64
      end
    end

    it "raises for array" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(Array(ValueWrapper).new).to_i64
      end
    end
  end

  describe "#to_u64" do
    it "converts unsigned integer to u64" do
      ValueWrapper.new(42_u64).to_u64.should eq(42_u64)
    end

    it "converts positive integer to u64" do
      ValueWrapper.new(42_i64).to_u64.should eq(42_u64)
    end

    it "raises for negative integer" do
      expect_raises(EmulationExceptionWrapper, /negative/) do
        ValueWrapper.new(-1_i64).to_u64
      end
    end

    it "converts positive float to u64" do
      ValueWrapper.new(3.9).to_u64.should eq(3_u64)
    end

    it "raises for negative float" do
      expect_raises(EmulationExceptionWrapper, /negative/) do
        ValueWrapper.new(-1.0).to_u64
      end
    end

    it "converts true to 1" do
      ValueWrapper.new(true).to_u64.should eq(1_u64)
    end

    it "converts false to 0" do
      ValueWrapper.new(false).to_u64.should eq(0_u64)
    end

    it "raises for string" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new("42").to_u64
      end
    end
  end

  describe "#to_f64" do
    it "converts float to f64" do
      ValueWrapper.new(3.14).to_f64.should eq(3.14)
    end

    it "converts integer to f64" do
      ValueWrapper.new(42_i64).to_f64.should eq(42.0)
    end

    it "converts unsigned integer to f64" do
      ValueWrapper.new(42_u64).to_f64.should eq(42.0)
    end

    it "converts true to 1.0" do
      ValueWrapper.new(true).to_f64.should eq(1.0)
    end

    it "converts false to 0.0" do
      ValueWrapper.new(false).to_f64.should eq(0.0)
    end

    it "raises for string" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new("3.14").to_f64
      end
    end
  end

  describe "#to_s" do
    it "converts null to 'null'" do
      ValueWrapper.new.to_s.should eq("null")
    end

    it "converts integer to string" do
      ValueWrapper.new(42_i64).to_s.should eq("42")
    end

    it "converts unsigned integer to string" do
      ValueWrapper.new(42_u64).to_s.should eq("42")
    end

    it "converts float to string" do
      ValueWrapper.new(3.14).to_s.should eq("3.14")
    end

    it "converts boolean true to string" do
      ValueWrapper.new(true).to_s.should eq("true")
    end

    it "converts boolean false to string" do
      ValueWrapper.new(false).to_s.should eq("false")
    end

    it "returns string as-is" do
      ValueWrapper.new("hello").to_s.should eq("hello")
    end

    it "converts empty map to string" do
      ValueWrapper.new(Hash(String, ValueWrapper).new).to_s.should eq("{}")
    end

    it "converts map with values to string" do
      hash = {"a" => ValueWrapper.new(1_i64), "b" => ValueWrapper.new(2_i64)}
      result = ValueWrapper.new(hash).to_s
      result.should contain("a: 1")
      result.should contain("b: 2")
    end

    it "converts empty array to string" do
      ValueWrapper.new(Array(ValueWrapper).new).to_s.should eq("[]")
    end

    it "converts array with values to string" do
      arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      ValueWrapper.new(arr).to_s.should eq("[1, 2]")
    end

    it "converts custom type to type tag" do
      tuple = {1_u64, ValueWrapper.new("msg")}
      value = ValueWrapper.new(tuple)
      value.to_s.should eq("<Tuple(UInt64, Jelly::VirtualMachine::Value)>")
    end
  end

  describe "#to_bool" do
    it "returns true for true boolean" do
      ValueWrapper.new(true).to_bool.should be_true
    end

    it "returns false for false boolean" do
      ValueWrapper.new(false).to_bool.should be_false
    end

    it "returns true for non-zero integer" do
      ValueWrapper.new(42_i64).to_bool.should be_true
    end

    it "returns false for zero integer" do
      ValueWrapper.new(0_i64).to_bool.should be_false
    end

    it "returns true for non-zero unsigned integer" do
      ValueWrapper.new(42_u64).to_bool.should be_true
    end

    it "returns false for zero unsigned integer" do
      ValueWrapper.new(0_u64).to_bool.should be_false
    end

    it "returns true for non-zero float" do
      ValueWrapper.new(0.1).to_bool.should be_true
    end

    it "returns false for zero float" do
      ValueWrapper.new(0.0).to_bool.should be_false
    end

    it "returns true for non-empty string" do
      ValueWrapper.new("hello").to_bool.should be_true
    end

    it "returns false for empty string" do
      ValueWrapper.new("").to_bool.should be_false
    end

    it "returns true for non-empty map" do
      ValueWrapper.new({"a" => ValueWrapper.new(1_i64)}).to_bool.should be_true
    end

    it "returns false for empty map" do
      ValueWrapper.new(Hash(String, ValueWrapper).new).to_bool.should be_false
    end

    it "returns true for non-empty array" do
      ValueWrapper.new([ValueWrapper.new(1_i64)]).to_bool.should be_true
    end

    it "returns false for empty array" do
      ValueWrapper.new(Array(ValueWrapper).new).to_bool.should be_false
    end

    it "returns false for null" do
      ValueWrapper.new.to_bool.should be_false
    end

    it "returns true for custom types" do
      ValueWrapper.new({1_u64, ValueWrapper.new("msg")}).to_bool.should be_true
    end
  end

  describe "#to_h" do
    it "returns hash for map value" do
      hash = {"key" => ValueWrapper.new("value")}
      ValueWrapper.new(hash).to_h.should eq(hash)
    end

    it "raises for non-map value" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(42_i64).to_h
      end
    end
  end

  describe "#to_a" do
    it "returns array for array value" do
      arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      ValueWrapper.new(arr).to_a.should eq(arr)
    end

    it "raises for non-array value" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(42_i64).to_a
      end
    end
  end

  describe "#to_send_tuple" do
    it "unboxes Tuple(UInt64, Value)" do
      original = {42_u64, ValueWrapper.new("hello")}
      value = ValueWrapper.new(original)
      addr, msg = value.to_send_tuple
      addr.should eq(42_u64)
      msg.to_s.should eq("hello")
    end

    it "raises for wrong type" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(42_i64).to_send_tuple
      end
    end
  end

  describe "#to_receive_timeout_tuple" do
    it "unboxes Tuple(Value, Float64)" do
      original = {ValueWrapper.new("pattern"), 5.0}
      value = ValueWrapper.new(original)
      pattern, timeout = value.to_receive_timeout_tuple
      pattern.to_s.should eq("pattern")
      timeout.should eq(5.0)
    end

    it "raises for wrong type" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(42_i64).to_receive_timeout_tuple
      end
    end
  end

  describe "#to_send_after_tuple" do
    it "unboxes Tuple(UInt64, Value, Float64)" do
      original = {42_u64, ValueWrapper.new("delayed"), 2.5}
      value = ValueWrapper.new(original)
      addr, msg, delay = value.to_send_after_tuple
      addr.should eq(42_u64)
      msg.to_s.should eq("delayed")
      delay.should eq(2.5)
    end

    it "raises for wrong type" do
      expect_raises(EmulationExceptionWrapper, /Cannot convert/) do
        ValueWrapper.new(42_i64).to_send_after_tuple
      end
    end
  end

  describe "#clone" do
    it "clones null value" do
      original = ValueWrapper.new
      cloned = original.clone
      cloned.is_null?.should be_true
    end

    it "clones integer value" do
      original = ValueWrapper.new(42_i64)
      cloned = original.clone
      cloned.to_i64.should eq(42_i64)
    end

    it "clones unsigned integer value" do
      original = ValueWrapper.new(42_u64)
      cloned = original.clone
      cloned.to_u64.should eq(42_u64)
    end

    it "clones float value" do
      original = ValueWrapper.new(3.14)
      cloned = original.clone
      cloned.to_f64.should eq(3.14)
    end

    it "clones string value" do
      original = ValueWrapper.new("hello")
      cloned = original.clone
      cloned.to_s.should eq("hello")
    end

    it "clones boolean value" do
      original = ValueWrapper.new(true)
      cloned = original.clone
      cloned.to_bool.should be_true
    end

    it "deep clones map value" do
      inner = {"nested" => ValueWrapper.new("value")}
      original = ValueWrapper.new(inner)
      cloned = original.clone
      inner["nested"] = ValueWrapper.new("modified")
      cloned.to_h["nested"].to_s.should eq("value")
    end

    it "deep clones array value" do
      arr = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      original = ValueWrapper.new(arr)
      cloned = original.clone
      arr << ValueWrapper.new(3_i64)
      cloned.to_a.size.should eq(2)
    end

    it "returns self for custom types" do
      tuple = {1_u64, ValueWrapper.new("msg")}
      original = ValueWrapper.new(tuple)
      cloned = original.clone
      cloned.should eq(original)
    end
  end

  describe "#==" do
    it "returns true for equal null values" do
      (ValueWrapper.new == ValueWrapper.new).should be_true
    end

    it "returns true for equal integer values" do
      (ValueWrapper.new(42_i64) == ValueWrapper.new(42_i64)).should be_true
    end

    it "returns false for different integer values" do
      (ValueWrapper.new(42_i64) == ValueWrapper.new(43_i64)).should be_false
    end

    it "returns true for equal unsigned integer values" do
      (ValueWrapper.new(42_u64) == ValueWrapper.new(42_u64)).should be_true
    end

    it "returns true for equal float values" do
      (ValueWrapper.new(3.14) == ValueWrapper.new(3.14)).should be_true
    end

    it "returns true for equal string values" do
      (ValueWrapper.new("hello") == ValueWrapper.new("hello")).should be_true
    end

    it "returns false for different string values" do
      (ValueWrapper.new("hello") == ValueWrapper.new("world")).should be_false
    end

    it "returns true for equal boolean values" do
      (ValueWrapper.new(true) == ValueWrapper.new(true)).should be_true
      (ValueWrapper.new(false) == ValueWrapper.new(false)).should be_true
    end

    it "returns false for different boolean values" do
      (ValueWrapper.new(true) == ValueWrapper.new(false)).should be_false
    end

    it "returns false for different types with same representation" do
      (ValueWrapper.new(42_i64) == ValueWrapper.new(42_u64)).should be_false
      (ValueWrapper.new(1_i64) == ValueWrapper.new(true)).should be_false
      (ValueWrapper.new("42") == ValueWrapper.new(42_i64)).should be_false
    end

    it "returns true for equal map values" do
      hash1 = {"a" => ValueWrapper.new(1_i64)}
      hash2 = {"a" => ValueWrapper.new(1_i64)}
      (ValueWrapper.new(hash1) == ValueWrapper.new(hash2)).should be_true
    end

    it "returns false for different map values" do
      hash1 = {"a" => ValueWrapper.new(1_i64)}
      hash2 = {"a" => ValueWrapper.new(2_i64)}
      (ValueWrapper.new(hash1) == ValueWrapper.new(hash2)).should be_false
    end

    it "returns true for equal array values" do
      arr1 = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      arr2 = [ValueWrapper.new(1_i64), ValueWrapper.new(2_i64)]
      (ValueWrapper.new(arr1) == ValueWrapper.new(arr2)).should be_true
    end

    it "returns false for different array values" do
      arr1 = [ValueWrapper.new(1_i64)]
      arr2 = [ValueWrapper.new(2_i64)]
      (ValueWrapper.new(arr1) == ValueWrapper.new(arr2)).should be_false
    end
  end

  describe "#inspect" do
    it "returns formatted string for integer" do
      ValueWrapper.new(42_i64).inspect.should eq("Value(Integer: 42)")
    end

    it "returns formatted string for null" do
      ValueWrapper.new.inspect.should eq("Value(Null: null)")
    end

    it "returns formatted string for tuple" do
      tuple = {1_u64, ValueWrapper.new("msg")}
      ValueWrapper.new(tuple).inspect.should eq("Value(Tuple(UInt64, Jelly::VirtualMachine::Value): <Tuple(UInt64, Jelly::VirtualMachine::Value)>)")
    end
  end
end
