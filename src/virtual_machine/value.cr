module Jelly
  module VirtualMachine
    # Represents a dynamically-typed value in the virtual machine with support for primitive types and extensible custom types
    class Value
      # Enum for efficient type identification of primitive types
      enum PrimitiveType : UInt8
        Null
        Integer
        UnsignedInteger
        Float
        String
        Boolean
        Map
        Array
        Custom
      end

      getter primitive_type : PrimitiveType
      getter pointer : Pointer(Void)
      getter custom_type : ::String?

      # Create a null value
      def initialize
        @primitive_type = PrimitiveType::Null
        @pointer = Pointer(Void).null
        @custom_type = nil
      end

      # Create an integer value
      def initialize(object : Int64)
        @primitive_type = PrimitiveType::Integer
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create an unsigned integer value
      def initialize(object : UInt64)
        @primitive_type = PrimitiveType::UnsignedInteger
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a float value
      def initialize(object : Float64)
        @primitive_type = PrimitiveType::Float
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a string value
      def initialize(object : String)
        @primitive_type = PrimitiveType::String
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a boolean value
      def initialize(object : Bool)
        @primitive_type = PrimitiveType::Boolean
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a map value
      def initialize(object : Hash(::String, Value))
        @primitive_type = PrimitiveType::Map
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create an array value
      def initialize(object : ::Array(Value))
        @primitive_type = PrimitiveType::Array
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a null value from nil
      def initialize(object : Nil)
        @primitive_type = PrimitiveType::Null
        @pointer = Pointer(Void).null
        @custom_type = nil
      end

      # Create a tuple value for (UInt64, Value) - used by SEND
      def initialize(object : Tuple(UInt64, Value))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(UInt64, Jelly::VirtualMachine::Value)"
      end

      # Create a tuple value for (Value, Float64) - used by RECEIVE_TIMEOUT
      def initialize(object : Tuple(Value, Float64))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(Value, Float64)"
      end

      # Create a tuple value for (UInt64, Value, Float64) - used by SEND_AFTER
      def initialize(object : Tuple(UInt64, Value, Float64))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(UInt64, Value, Float64)"
      end

      # Create a custom/generic value for any other type
      def initialize(object : Object)
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = object.class.to_s
      end

      # Returns the type as a string for backward compatibility
      def type : ::String
        case @primitive_type
        when .null?
          "Null"
        when .integer?
          "Integer"
        when .unsigned_integer?
          "UnsignedInteger"
        when .float?
          "Float"
        when .string?
          "String"
        when .boolean?
          "Boolean"
        when .map?
          "Map"
        when .array?
          "Array"
        when .custom?
          @custom_type || "Unknown"
        else
          "Unknown"
        end
      end

      # Check if value is an array
      def is_array? : Bool
        @primitive_type.array?
      end

      # Check if value is an integer
      def is_integer? : Bool
        @primitive_type.integer?
      end

      # Check if value is an unsigned integer
      def is_unsigned_integer? : Bool
        @primitive_type.unsigned_integer?
      end

      # Check if value is a float
      def is_float? : Bool
        @primitive_type.float?
      end

      # Check if value is a string
      def is_string? : Bool
        @primitive_type.string?
      end

      # Check if value is a boolean
      def is_boolean? : Bool
        @primitive_type.boolean?
      end

      # Check if value is a map
      def is_map? : Bool
        @primitive_type.map?
      end

      # Check if value is null
      def is_null? : Bool
        @primitive_type.null?
      end

      # Check if value is a custom type
      def is_custom? : Bool
        @primitive_type.custom?
      end

      # Check if value is numeric (integer, unsigned integer, or float)
      def is_numeric? : Bool
        @primitive_type.integer? || @primitive_type.unsigned_integer? || @primitive_type.float?
      end

      # Check if value is a tuple type
      def is_tuple? : Bool
        @primitive_type.custom? && @custom_type.try(&.starts_with?("Tuple")) || false
      end

      # Convert value to Int64
      def to_i64 : Int64
        case @primitive_type
        when .integer?
          Box(Int64).unbox(@pointer)
        when .unsigned_integer?
          Box(UInt64).unbox(@pointer).to_i64
        when .float?
          Box(Float64).unbox(@pointer).to_i64
        when .boolean?
          Box(Bool).unbox(@pointer) ? 1_i64 : 0_i64
        else
          raise EmulationException.new("Cannot convert #{type} to integer")
        end
      end

      # Convert value to UInt64
      def to_u64 : UInt64
        case @primitive_type
        when .unsigned_integer?
          Box(UInt64).unbox(@pointer)
        when .integer?
          value = Box(Int64).unbox(@pointer)
          raise EmulationException.new("Cannot convert negative integer to unsigned integer") if value < 0
          value.to_u64
        when .float?
          value = Box(Float64).unbox(@pointer)
          raise EmulationException.new("Cannot convert negative float to unsigned integer") if value < 0
          value.to_u64
        when .boolean?
          Box(Bool).unbox(@pointer) ? 1_u64 : 0_u64
        else
          raise EmulationException.new("Cannot convert #{type} to unsigned integer")
        end
      end

      # Convert value to Float64
      def to_f64 : Float64
        case @primitive_type
        when .float?
          Box(Float64).unbox(@pointer)
        when .integer?
          Box(Int64).unbox(@pointer).to_f64
        when .unsigned_integer?
          Box(UInt64).unbox(@pointer).to_f64
        when .boolean?
          Box(Bool).unbox(@pointer) ? 1.0 : 0.0
        else
          raise EmulationException.new("Cannot convert #{type} to float")
        end
      end

      # Convert value to String
      def to_s : ::String
        case @primitive_type
        when .null?
          "null"
        when .integer?
          Box(Int64).unbox(@pointer).to_s
        when .unsigned_integer?
          Box(UInt64).unbox(@pointer).to_s
        when .float?
          Box(Float64).unbox(@pointer).to_s
        when .boolean?
          Box(Bool).unbox(@pointer).to_s
        when .string?
          Box(::String).unbox(@pointer)
        when .map?
          hash = Box(Hash(::String, Value)).unbox(@pointer)
          "{#{hash.map { |k, v| "#{k}: #{v.to_s}" }.join(", ")}}"
        when .array?
          arr = Box(::Array(Value)).unbox(@pointer)
          "[#{arr.map(&.to_s).join(", ")}]"
        when .custom?
          "<#{@custom_type}>"
        else
          "<unknown>"
        end
      end

      # Convert value to Bool
      def to_b : Bool
        case @primitive_type
        when .boolean?
          Box(Bool).unbox(@pointer)
        when .integer?
          Box(Int64).unbox(@pointer) != 0_i64
        when .unsigned_integer?
          Box(UInt64).unbox(@pointer) != 0_u64
        when .float?
          Box(Float64).unbox(@pointer) != 0.0
        when .string?
          !Box(::String).unbox(@pointer).empty?
        when .map?
          !Box(Hash(::String, Value)).unbox(@pointer).empty?
        when .array?
          !Box(::Array(Value)).unbox(@pointer).empty?
        when .null?
          false
        when .custom?
          true
        else
          false
        end
      end

      # Convert value to Hash
      def to_h : Hash(::String, Value)
        raise EmulationException.new("Cannot convert #{type} to hash") unless @primitive_type.map?
        Box(Hash(::String, Value)).unbox(@pointer)
      end

      # Convert value to Array
      def to_a : ::Array(Value)
        raise EmulationException.new("Cannot convert #{type} to array") unless @primitive_type.array?
        Box(::Array(Value)).unbox(@pointer)
      end

      # Unbox as Tuple(UInt64, Value)
      def to_send_tuple : Tuple(UInt64, Value)
        unless @custom_type == "Tuple(UInt64, Jelly::VirtualMachine::Value)"
          raise EmulationException.new("Cannot convert #{type} to Tuple(UInt64, Value)")
        end
        Box(Tuple(UInt64, Value)).unbox(@pointer)
      end

      # Unbox as Tuple(Value, Float64)
      def to_receive_timeout_tuple : Tuple(Value, Float64)
        unless @custom_type == "Tuple(Value, Float64)"
          raise EmulationException.new("Cannot convert #{type} to Tuple(Value, Float64)")
        end
        Box(Tuple(Value, Float64)).unbox(@pointer)
      end

      # Unbox as Tuple(UInt64, Value, Float64)
      def to_send_after_tuple : Tuple(UInt64, Value, Float64)
        unless @custom_type == "Tuple(UInt64, Value, Float64)"
          raise EmulationException.new("Cannot convert #{type} to Tuple(UInt64, Value, Float64)")
        end
        Box(Tuple(UInt64, Value, Float64)).unbox(@pointer)
      end

      # Create a deep copy of the value
      def clone : Value
        case @primitive_type
        when .null?
          Value.new
        when .integer?
          Value.new(to_i64)
        when .unsigned_integer?
          Value.new(to_u64)
        when .float?
          Value.new(to_f64)
        when .string?
          Value.new(Box(::String).unbox(@pointer).dup)
        when .boolean?
          Value.new(to_b)
        when .map?
          cloned_hash = Hash(::String, Value).new
          to_h.each { |k, v| cloned_hash[k] = v.clone }
          Value.new(cloned_hash)
        when .array?
          Value.new(to_a.map(&.clone))
        when .custom?
          self
        else
          raise EmulationException.new("Cannot clone unsupported value type: #{type}")
        end
      end

      # Check equality between two values
      def ==(other : Value) : Bool
        return false unless @primitive_type == other.primitive_type
        case @primitive_type
        when .null?
          true
        when .integer?
          to_i64 == other.to_i64
        when .unsigned_integer?
          to_u64 == other.to_u64
        when .float?
          to_f64 == other.to_f64
        when .string?
          to_s == other.to_s
        when .boolean?
          to_b == other.to_b
        when .map?
          to_h == other.to_h
        when .array?
          to_a == other.to_a
        when .custom?
          @custom_type == other.custom_type && @pointer == other.pointer
        else
          false
        end
      end

      # Return the raw string value for inspection
      def inspect : ::String
        "Value(#{type}: #{to_s})"
      end
    end
  end
end
