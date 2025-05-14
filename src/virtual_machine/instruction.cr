module Jelly
  module VirtualMachine
    class Instruction
      Log = ::Log.for(self)

      getter code : Code
      getter value : Value

      def initialize(@code : Code, @value : Value = Value.new(nil))
      end
    end
  end
end
