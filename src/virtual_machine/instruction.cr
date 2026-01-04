module Jelly
  module VirtualMachine
    class Instruction
      Log = ::Log.for(self)

      getter code : Code
      getter value : Value

      def initialize(@code : Code, @value : Value = Value.new(nil))
      end

      def clone : Instruction
        Instruction.new(@code, @value.clone)
      end
    end
  end
end
