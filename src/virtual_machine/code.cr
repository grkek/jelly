module Jelly
  module VirtualMachine
    enum Code : UInt8
      # Stack manipulation

      POP # Pop top value off stack and discard
      # Stack: [a] → []

      DUPLICATE # Duplicate the top value
      # Stack: [a] → [a, a]

      SWAP # Swap the top two values
      # Stack: [a, b] → [b, a]

      ROT # Rotate top three values
      # Stack: [a, b, c] → [b, c, a]

      OVER # Copy the second value to the top
      # Stack: [a, b] → [a, b, a]

      DROP # Alias for POP (clearer intent for discarding)
      # Stack: [a] → []

      # Push instructions (type-specific)

      PUSH_INSTRUCTIONS # Push an instruction array onto the stack
      # Operand: Array(Instruction)
      # Stack: [] → [instructions]

      PUSH_INTEGER # Push an integer value onto the stack
      # Operand: Int64
      # Stack: [] → [int]

      PUSH_UNSIGNED_INTEGER # Push an unsigned integer value onto the stack
      # Operand: UInt64
      # Stack: [] → [int]

      PUSH_FLOAT # Push a float value onto the stack
      # Operand: Float64
      # Stack: [] → [float]

      PUSH_STRING # Push a string value onto the stack
      # Operand: String
      # Stack: [] → [string]

      PUSH_BOOLEAN # Push a boolean value onto the stack
      # Operand: Bool
      # Stack: [] → [bool]

      PUSH_NULL # Push a null value onto the stack
      # Stack: [] → [null]

      # Arithmetic operations

      ADD # Add top two numeric values
      # Stack: [a, b] → [a + b]
      # Returns Float64 if either operand is float

      SUBTRACT # Subtract top from second
      # Stack: [a, b] → [a - b]

      MULTIPLY # Multiply top two numeric values
      # Stack: [a, b] → [a * b]

      DIVIDE # Divide second by top
      # Stack: [a, b] → [a / b]
      # Raises EmulationException on division by zero

      MODULO # Modulo (remainder) of second divided by top
      # Stack: [a, b] → [a % b]

      NEGATE # Negate top numeric value (unary minus)
      # Stack: [a] → [-a]

      # String operations

      CONCATENATE # Concatenate two strings
      # Stack: [str1, str2] → [str1 + str2]

      STRING_LENGTH # Get length of string
      # Stack: [str] → [length]

      SUBSTRING # Extract substring
      # Stack: [str, start, length] → [substring]

      # Comparison operations
      # All comparisons push a boolean result

      LESS_THAN # Check if second < top
      # Stack: [a, b] → [a < b]

      GREATER_THAN # Check if second > top
      # Stack: [a, b] → [a > b]

      LESS_THAN_OR_EQUAL # Check if second <= top
      # Stack: [a, b] → [a <= b]

      GREATER_THAN_OR_EQUAL # Check if second >= top
      # Stack: [a, b] → [a >= b]

      EQUAL # Check if two values are equal (any type)
      # Stack: [a, b] → [a == b]

      NOT_EQUAL # Check if two values are not equal
      # Stack: [a, b] → [a != b]

      # Logical operators

      AND # Logical AND of top two values
      # Stack: [a, b] → [a && b]

      OR # Logical OR of top two values
      # Stack: [a, b] → [a || b]

      NOT # Logical NOT of top value
      # Stack: [a] → [!a]

      # Variable operators

      LOAD_LOCAL # Push local variable onto stack
      # Operand: variable index (Int64)
      # Stack: [] → [value]

      STORE_LOCAL # Pop stack into local variable
      # Operand: variable index (Int64)
      # Stack: [value] → []

      LOAD_GLOBAL # Push global variable onto stack
      # Operand: variable name (String)
      # Stack: [] → [value]

      STORE_GLOBAL # Pop stack into global variable
      # Operand: variable name (String)
      # Stack: [value] → []

      # Flow control

      CALL # Call a subroutine
      # Operand: subroutine name (String)
      # Pushes return address to call stack

      RETURN # Return from subroutine
      # Pops return address from call stack
      # If call stack empty, terminates process

      JUMP # Unconditional jump to absolute address
      # Operand: target address (Int64)

      JUMP_IF # Jump if top of stack is truthy
      # Operand: relative offset (Int64)
      # Stack: [condition] → []

      JUMP_UNLESS # Jump if top of stack is falsy
      # Operand: relative offset (Int64)
      # Stack: [condition] → []

      HALT # Stop process execution cleanly
      # Sets process state to DEAD

      # Concurrency / actor model

      SPAWN # Spawn a new process
      # Stack: [] → [new_process_address]

      SELF # Push current process address onto stack
      # Stack: [] → [self_address]

      SEND # Send message to another process
      # Operand: Tuple(UInt64, Value) - (target_address, message)
      # Stack unchanged (message in operand)

      RECEIVE # Receive any message from mailbox (blocking)
      # Stack: [] → [message]
      # Sets process to WAITING if mailbox empty

      RECEIVE_SELECT # Receive message matching pattern
      # Operand: pattern (Value) or null to use stack
      # Stack: [pattern?] → [message]
      # Sets process to WAITING if no match

      RECEIVE_TIMEOUT # Receive with timeout
      # Operand: Tuple(Value, Float64) - (pattern, timeout_seconds)
      # Stack: [] → [message, success_bool]

      SEND_AFTER # Schedule delayed message
      # Operand: Tuple(UInt64, Value, Float64) - (target, message, delay)

      REGISTER_PROCESS # Register process with a name
      # Operand: name (String)
      # Returns bool success

      WHEREIS_PROCESS # Look up process by registered name
      # Operand: name (String)
      # Stack: [] → [address or null]

      PEEK_MAILBOX # Peek at next message without consuming
      # Stack: [] → [message or null]

      KILL # Terminate a process
      # Stack: [process_address] → []

      SLEEP # Pause execution for duration
      # Stack: [seconds] → []

      # Map operations

      MAP_NEW # Create empty map
      # Stack: [] → [{}]

      MAP_GET # Get value by key
      # Stack: [map, key] → [value]

      MAP_SET # Set value by key
      # Stack: [map, key, value] → [map]

      MAP_DELETE # Delete key from map
      # Stack: [map, key] → [map]

      MAP_KEYS # Get all keys as array
      # Stack: [map] → [keys_array]

      MAP_SIZE # Get number of entries
      # Stack: [map] → [size]

      # Array operations

      ARRAY_NEW # Create empty array (or with size)
      # Stack: [] → [[]]
      # Operand: optional initial size

      ARRAY_GET # Get element by index
      # Stack: [array, index] → [value]

      ARRAY_SET # Set element by index
      # Stack: [array, index, value] → [array]

      ARRAY_PUSH # Append element to array
      # Stack: [array, value] → [array]

      ARRAY_POP # Remove and return last element
      # Stack: [array] → [array, value]

      ARRAY_LENGTH # Get array length
      # Stack: [array] → [length]

      # I/O operations

      PRINT_LINE # Print top of stack to stdout
      # Stack: [value] → []

      READ_LINE # Read line from stdin
      # Stack: [] → [string]

      # Error handling

      THROW # Raise an exception
      # Stack: [error_value] → (process dies)

      # Process linking (bidirectional)
      LINK # Link two processes
      # Stack: [other_pid] → []
      # Links current process with other_pid

      UNLINK # Unlink two processes
      # Stack: [other_pid] → []
      # Removes link between current process and other_pid

      # Process monitoring (unidirectional)
      MONITOR # Monitor a process
      # Stack: [target_pid] → [monitor_ref]
      # Returns a reference that can be used to demonitor

      DEMONITOR # Stop monitoring a process
      # Stack: [monitor_ref] → [success_bool]
      # Removes the monitor

      # Exit handling
      TRAP_EXIT # Enable/disable exit trapping
      # Stack: [bool] → []
      # When true, exit signals become messages

      EXIT # Send exit signal to a process
      # Stack: [target_pid, reason_string] → []
      # Sends exit signal with given reason

      EXIT_SELF # Exit current process with reason
      # Stack: [reason_string] → (terminates)
      # Cleanly terminates current process

      # Spawn variants
      SPAWN_LINK # Spawn and link atomically
      # Stack: [] → [new_pid]
      # Same as SPAWN but creates a link

      SPAWN_MONITOR # Spawn and monitor atomically
      # Stack: [] → [new_pid, monitor_ref]
      # Same as SPAWN but creates a monitor

      # Process info
      IS_ALIVE # Check if a process is alive
      # Stack: [pid] → [bool]
      # Returns true if process exists and is not DEAD

      PROCESS_INFO # Get process information
      # Stack: [pid] → [info_map]
      # Returns map with process details

      # Supervisor operations
      START_CHILD # Start a child under supervisor
      # Stack: [supervisor_pid, child_spec] → [child_pid]
      # Starts a supervised child

      STOP_CHILD # Stop a supervised child
      # Stack: [supervisor_pid, child_id] → [success_bool]
      # Stops a child process

      RESTART_CHILD # Restart a supervised child
      # Stack: [supervisor_pid, child_id] → [new_pid]
      # Restarts a child process

      WHICH_CHILDREN # List supervisor's children
      # Stack: [supervisor_pid] → [children_array]
      # Returns array of child info

      # Error handling
      TRY_CATCH # Begin try-catch block
      # Operand: catch_offset (Int64)
      # Marks start of try block

      END_TRY # End try block
      # Pops exception handler from stack

      CATCH # Catch exception
      # Stack: [] → [exception_value]
      # Entry point for exception handler

      RETHROW # Rethrow current exception
      # Must be in exception handler

      # Process flags
      SET_FLAG # Set a process flag
      # Stack: [flag_name, value] → [old_value]
      # Sets process-specific flag

      GET_FLAG # Get a process flag
      # Stack: [flag_name] → [value]
      # Gets process-specific flag
    end

    # Exception handler frame for try-catch
    struct ExceptionHandler
      getter catch_address : UInt64
      getter stack_size : Int32
      getter call_stack_size : Int32

      def initialize(@catch_address : UInt64, @stack_size : Int32, @call_stack_size : Int32)
      end
    end
  end
end
