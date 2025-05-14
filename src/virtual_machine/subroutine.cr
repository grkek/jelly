module Jelly
  module VirtualMachine
    class Subroutine
      getter name : String
      getter instructions : Array(Instruction)
      getter start_address : UInt64

      def initialize(@name : String, @instructions : Array(Instruction), @start_address : UInt64)
      end
    end
  end
end
