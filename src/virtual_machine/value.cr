module Jelly
  module VirtualMachine
    class Value
      Log = ::Log.for(self)

      property type : String
      property pointer : Pointer(Void)

      # Regular constructor (fallback for unsupported types)
      def initialize(object : Object)
        @type = object.class.to_s
        @pointer = Box.box(object)
      end

      # Type-specific constructors
      def initialize(object : Int32)
        @type = "Integer"
        @pointer = Box.box(object)
      end

      def initialize(object : Float64)
        @type = "Float"
        @pointer = Box.box(object)
      end

      def initialize(object : String)
        @type = "String"
        @pointer = Box.box(object)
      end

      def initialize(object : Bool)
        @type = "Boolean"
        @pointer = Box.box(object)
      end

      def initialize(object : Hash(String, Value))
        @type = "Map"
        @pointer = Box.box(object)
      end

      def initialize
        @type = "Null"
        @pointer = Box.box(nil)
      end

      # Type checkers
      def is_integer? : Bool
        type == "Integer"
      end

      def is_float? : Bool
        type == "Float"
      end

      def is_string? : Bool
        type == "String"
      end

      def is_boolean? : Bool
        type == "Boolean"
      end

      def is_map? : Bool
        type == "Map"
      end

      def is_null? : Bool
        type == "Null" || pointer.null?
      end

      def is_numeric? : Bool
        is_integer? || is_float?
      end

      # Value converters
      def to_i : Int32
        if is_integer?
          Box(Int32).unbox(pointer).to_i
        elsif is_float?
          Box(Float64).unbox(pointer).to_f.to_i
        elsif is_boolean?
          Box(Bool).unbox(pointer) ? 1 : 0
        else
          raise VMException.new("Cannot convert #{type} to integer")
        end
      end

      def to_f : Float64
        if is_float?
          Box(Float64).unbox(pointer).to_f
        elsif is_integer?
          Box(Int32).unbox(pointer).to_i.to_f
        elsif is_boolean?
          Box(Bool).unbox(pointer) ? 1.0 : 0.0
        else
          raise VMException.new("Cannot convert #{type} to float")
        end
      end

      def to_s : String
        if pointer.null? || is_null?
          "null"
        elsif is_float?
          Box(Float64).unbox(pointer).to_s
        elsif is_integer?
          Box(Int32).unbox(pointer).to_s
        elsif is_boolean?
          Box(Bool).unbox(pointer).to_s
        elsif is_string?
          Box(String).unbox(pointer)
        elsif is_map?
          hash = Box(Hash(String, Value)).unbox(pointer)
          "{#{hash.map { |k, v| "#{k}: #{v.to_s}" }.join(", ")}}"
        else
          raise VMException.new("Cannot convert #{type} to string")
        end
      end

      def to_b : Bool
        if is_boolean?
          Box(Bool).unbox(pointer)
        elsif is_integer?
          to_i != 0
        elsif is_float?
          to_f != 0.0
        elsif is_string?
          str = Box(String).unbox(pointer)
          !str.empty?
        elsif is_map?
          hash = Box(Hash(String, Value)).unbox(pointer)
          !hash.empty?
        else
          false
        end
      end

      def to_h : Hash(String, Value)
        if is_map?
          Box(Hash(String, Value)).unbox(pointer)
        else
          raise VMException.new("Cannot convert #{type} to hash")
        end
      end

      # Creates a deep copy of the Value instance
      def clone : Value
        case type
        when "Integer"
          Value.new(to_i)
        when "Float"
          Value.new(to_f)
        when "String"
          Value.new(to_s.dup)
        when "Boolean"
          Value.new(to_b)
        when "Map"
          hash = to_h
          cloned_hash = Hash(String, Value).new
          hash.each { |k, v| cloned_hash[k] = v.clone }
          Value.new(cloned_hash)
        when "Null"
          Value.new
        else
          raise VMException.new("Cannot clone unsupported Value type: #{type}")
        end
      end
    end
  end
end
