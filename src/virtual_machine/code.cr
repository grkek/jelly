module Jelly
  module VirtualMachine
    enum Code : UInt8
      # Stack manipulation
      POP
      DUPLICATE
      SWAP

      # Type-specific push instructions
      PUSH_INTEGER
      PUSH_FLOAT
      PUSH_STRING
      PUSH_BOOLEAN
      PUSH_NULL

      # Arithmetic/string operations
      ADD
      SUBTRACT
      CONCATENATE
      LESS_THAN
      EQUAL

      # Flow control
      CALL
      RETURN
      JUMP
      JUMP_IF

      # Concurrency
      SPAWN
      SEND
      RECEIVE
      RECEIVE_SELECT
      RECEIVE_TIMEOUT
      SEND_AFTER
      REGISTER_PROCESS
      WHEREIS_PROCESS
      PEEK_MAILBOX

      # I/O
      PRINT
    end
  end
end
