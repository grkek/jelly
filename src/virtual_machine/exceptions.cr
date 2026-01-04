module Jelly
  module VirtualMachine
    # Base exception class for all Virtual Machine errors
    class EmulationException < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end

    # Raised when an instruction receives a value of the wrong type
    class TypeMismatchException < EmulationException
    end

    # Raised when an instruction attempts to access an invalid process address
    class InvalidAddressException < EmulationException
    end

    # Raised when a process's mailbox is full and cannot accept more messages
    class MailboxOverflowException < EmulationException
    end

    # Raised when the VM detects a deadlock situation
    class DeadlockException < EmulationException
    end

    # Raised when an unknown or unsupported instruction is encountered
    class InvalidInstructionException < EmulationException
    end
  end
end
