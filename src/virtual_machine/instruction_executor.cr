module Jelly
  module VirtualMachine
    class InstructionExecutor
      Log = ::Log.for(self)

      def initialize(@engine : Engine)
      end

      # Executes a single instruction for the given process
      def execute(process : Process, instruction : Instruction) : Value
        return Value.new if process.state != Process::State::ALIVE

        Log.debug { "Process <#{process.address}>: Executing #{instruction.code}" }

        begin
          case instruction.code
          # Stack manipulation
          when Code::POP       then execute_pop(process)
          when Code::DUPLICATE then execute_duplicate(process)
          when Code::SWAP      then execute_swap(process)
          when Code::ROT       then execute_rot(process)
          when Code::OVER      then execute_over(process)
          when Code::DROP      then execute_pop(process)
            # Push instructions
          when Code::PUSH_INTEGER          then execute_push_integer(process, instruction)
          when Code::PUSH_UNSIGNED_INTEGER then execute_push_unsigned_integer(process, instruction)
          when Code::PUSH_FLOAT            then execute_push_float(process, instruction)
          when Code::PUSH_STRING           then execute_push_string(process, instruction)
          when Code::PUSH_BOOLEAN          then execute_push_boolean(process, instruction)
          when Code::PUSH_NULL             then execute_push_null(process)
            # Arithmetic
          when Code::ADD      then execute_add(process)
          when Code::SUBTRACT then execute_subtract(process)
          when Code::MULTIPLY then execute_multiply(process)
          when Code::DIVIDE   then execute_divide(process)
          when Code::MODULO   then execute_modulo(process)
          when Code::NEGATE   then execute_negate(process)
            # String operations
          when Code::CONCATENATE   then execute_concatenate(process)
          when Code::STRING_LENGTH then execute_string_length(process)
          when Code::SUBSTRING     then execute_substring(process)
            # Comparisons
          when Code::LESS_THAN             then execute_less_than(process)
          when Code::GREATER_THAN          then execute_greater_than(process)
          when Code::LESS_THAN_OR_EQUAL    then execute_less_than_or_equal(process)
          when Code::GREATER_THAN_OR_EQUAL then execute_greater_than_or_equal(process)
          when Code::EQUAL                 then execute_equal(process)
          when Code::NOT_EQUAL             then execute_not_equal(process)
            # Logical
          when Code::AND then execute_and(process)
          when Code::OR  then execute_or(process)
          when Code::NOT then execute_not(process)
            # Variables
          when Code::LOAD_LOCAL   then execute_load_local(process, instruction)
          when Code::STORE_LOCAL  then execute_store_local(process, instruction)
          when Code::LOAD_GLOBAL  then execute_load_global(process, instruction)
          when Code::STORE_GLOBAL then execute_store_global(process, instruction)
            # Flow control
          when Code::CALL        then execute_call(process, instruction)
          when Code::RETURN      then execute_return(process)
          when Code::JUMP        then execute_jump(process, instruction)
          when Code::JUMP_IF     then execute_jump_if(process, instruction)
          when Code::JUMP_UNLESS then execute_jump_unless(process, instruction)
          when Code::HALT        then execute_halt(process)
            # Concurrency
          when Code::SPAWN            then execute_spawn(process)
          when Code::SELF             then execute_self(process)
          when Code::SEND             then execute_send(process, instruction)
          when Code::RECEIVE          then execute_receive(process)
          when Code::RECEIVE_SELECT   then execute_receive_select(process, instruction)
          when Code::RECEIVE_TIMEOUT  then execute_receive_timeout(process, instruction)
          when Code::SEND_AFTER       then execute_send_after(process, instruction)
          when Code::REGISTER_PROCESS then execute_register_process(process, instruction)
          when Code::WHEREIS_PROCESS  then execute_whereis_process(process, instruction)
          when Code::PEEK_MAILBOX     then execute_peek_mailbox(process)
          when Code::KILL             then execute_kill(process)
          when Code::SLEEP            then execute_sleep(process)
            # Map operations
          when Code::MAP_NEW    then execute_map_new(process)
          when Code::MAP_GET    then execute_map_get(process)
          when Code::MAP_SET    then execute_map_set(process)
          when Code::MAP_DELETE then execute_map_delete(process)
          when Code::MAP_KEYS   then execute_map_keys(process)
          when Code::MAP_SIZE   then execute_map_size(process)
            # Array operations
          when Code::ARRAY_NEW    then execute_array_new(process, instruction)
          when Code::ARRAY_GET    then execute_array_get(process)
          when Code::ARRAY_SET    then execute_array_set(process)
          when Code::ARRAY_PUSH   then execute_array_push(process)
          when Code::ARRAY_POP    then execute_array_pop(process)
          when Code::ARRAY_LENGTH then execute_array_length(process)
            # I/O
          when Code::PRINT_LINE then execute_print_line(process)
          when Code::READ_LINE  then execute_read_line(process)
            # Error handling
          when Code::THROW then execute_throw(process)
            # Fault tolerance
          when Code::LINK          then execute_link(process)
          when Code::UNLINK        then execute_unlink(process)
          when Code::MONITOR       then execute_monitor(process)
          when Code::DEMONITOR     then execute_demonitor(process)
          when Code::TRAP_EXIT     then execute_trap_exit(process)
          when Code::EXIT          then execute_exit(process)
          when Code::EXIT_SELF     then execute_exit_self(process)
          when Code::SPAWN_LINK    then execute_spawn_link(process)
          when Code::SPAWN_MONITOR then execute_spawn_monitor(process)
          when Code::IS_ALIVE      then execute_is_alive(process)
          when Code::PROCESS_INFO  then execute_process_info(process)
          when Code::TRY_CATCH     then execute_try_catch(process, instruction)
          when Code::END_TRY       then execute_end_try(process)
          when Code::CATCH         then execute_catch(process)
          when Code::RETHROW       then execute_rethrow(process)
          when Code::SET_FLAG      then execute_set_flag(process)
          when Code::GET_FLAG      then execute_get_flag(process)
          else
            if handler = @engine.custom_handlers[instruction.code]?
              handler.call(process, instruction)
            else
              raise InvalidInstructionException.new("Unknown instruction: #{instruction.code}")
            end
          end
        rescue ex : EmulationException | Exception
          if handle_exception(process, ex)
            Value.new
          else
            Log.error { "Process <#{process.address}>: #{ex.class.name == "EmulationException" ? ex.message : "Unhandled error: #{ex.message}"}" }
            process.state = Process::State::DEAD
            Value.new(ex)
          end
        end
      end

      # Push an integer value onto the stack
      private def execute_push_integer(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("PUSH_INTEGER requires an integer value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_i64)
        process.stack.push(value)
        value
      end

      # Push an integer value onto the stack
      private def execute_push_unsigned_integer(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_unsigned_integer?
          raise TypeMismatchException.new("PUSH_UNSIGNED_INTEGER requires an unsigned integer value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_u64)
        process.stack.push(value)
        value
      end

      # Push a float value onto the stack
      private def execute_push_float(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_float?
          raise TypeMismatchException.new("PUSH_FLOAT requires a float value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_f64)
        process.stack.push(value)
        value
      end

      # Push a string value onto the stack
      private def execute_push_string(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("PUSH_STRING requires a string value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_s)
        process.stack.push(value)
        value
      end

      # Push a boolean value onto the stack
      private def execute_push_boolean(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_boolean?
          raise TypeMismatchException.new("PUSH_BOOLEAN requires a boolean value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_b)
        process.stack.push(value)
        value
      end

      # Push a null value onto the stack
      private def execute_push_null(process : Process) : Value
        process.counter += 1
        check_stack_capacity(process)
        value = Value.new
        process.stack.push(value)
        value
      end

      # Pop a value from the stack
      private def execute_pop(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "POP")
        process.stack.pop
      end

      # Duplicate the top value on the stack
      private def execute_duplicate(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "DUPLICATE")
        check_stack_capacity(process)
        value = process.stack.last.clone
        process.stack.push(value)
        value
      end

      # Swap the top two values on the stack
      private def execute_swap(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "SWAP")
        a = process.stack.pop
        b = process.stack.pop
        process.stack.push(a)
        process.stack.push(b)
        Value.new
      end

      # Rotate top three values: [a, b, c] → [b, c, a]
      private def execute_rot(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 3, "ROT")
        c = process.stack.pop
        b = process.stack.pop
        a = process.stack.pop
        process.stack.push(b)
        process.stack.push(c)
        process.stack.push(a)
        Value.new
      end

      # Copy second value to top: [a, b] → [a, b, a]
      private def execute_over(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "OVER")
        check_stack_capacity(process)
        value = process.stack[process.stack.size - 2].clone
        process.stack.push(value)
        value
      end

      # Add the top two numeric values on the stack
      private def execute_add(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "ADD")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("ADD requires two numeric values")
        end
        check_stack_capacity(process)
        if a.is_float? || b.is_float?
          result = Value.new(a.to_f64 + b.to_f64)
        else
          result = Value.new(a.to_i64 + b.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Subtract the top value from the second value
      private def execute_subtract(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "SUBTRACT")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("SUBTRACT requires two numeric values")
        end
        check_stack_capacity(process)
        if a.is_float? || b.is_float?
          result = Value.new(a.to_f64 - b.to_f64)
        else
          result = Value.new(a.to_i64 - b.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Multiply the top two numeric values
      private def execute_multiply(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "MULTIPLY")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("MULTIPLY requires two numeric values")
        end
        check_stack_capacity(process)
        if a.is_float? || b.is_float?
          result = Value.new(a.to_f64 * b.to_f64)
        else
          result = Value.new(a.to_i64 * b.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Divide the second value by the top value
      private def execute_divide(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "DIVIDE")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("DIVIDE requires two numeric values")
        end
        if b.to_f64 == 0.0
          raise EmulationException.new("Division by zero")
        end
        check_stack_capacity(process)
        if a.is_float? || b.is_float?
          result = Value.new(a.to_f64 / b.to_f64)
        else
          result = Value.new(a.to_i64 // b.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Modulo of second value by top value
      private def execute_modulo(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "MODULO")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("MODULO requires two numeric values")
        end
        if b.to_f64 == 0.0
          raise EmulationException.new("Modulo by zero")
        end
        check_stack_capacity(process)
        if a.is_float? || b.is_float?
          result = Value.new(a.to_f64 % b.to_f64)
        else
          result = Value.new(a.to_i64 % b.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Negate the top numeric value (unary minus)
      private def execute_negate(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "NEGATE")
        a = process.stack.pop
        unless a.is_numeric?
          raise TypeMismatchException.new("NEGATE requires a numeric value")
        end
        check_stack_capacity(process)
        if a.is_float?
          result = Value.new(-a.to_f64)
        else
          result = Value.new(-a.to_i64)
        end
        process.stack.push(result)
        result
      end

      # Concatenate the top two string values on the stack
      private def execute_concatenate(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "CONCATENATE")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_string? && b.is_string?
          raise TypeMismatchException.new("CONCATENATE requires two String values")
        end
        check_stack_capacity(process)
        result = Value.new(a.to_s + b.to_s)
        process.stack.push(result)
        result
      end

      # Get length of string
      private def execute_string_length(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "STRING_LENGTH")
        str = process.stack.pop
        unless str.is_string?
          raise TypeMismatchException.new("STRING_LENGTH requires a String value")
        end
        check_stack_capacity(process)
        result = Value.new(str.to_s.size.to_u64)
        process.stack.push(result)
        result
      end

      # Extract substring: [str, start, length] → [substring]
      private def execute_substring(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 3, "SUBSTRING")
        length = process.stack.pop
        start = process.stack.pop
        str = process.stack.pop
        unless str.is_string?
          raise TypeMismatchException.new("SUBSTRING requires a String value")
        end
        unless start.is_integer? && length.is_integer?
          raise TypeMismatchException.new("SUBSTRING requires Integer start and length")
        end
        check_stack_capacity(process)
        s = str.to_s
        start_idx = start.to_i64
        len = length.to_i64
        if start_idx < 0 || start_idx > s.size
          raise EmulationException.new("SUBSTRING start index out of bounds")
        end
        result = Value.new(s[start_idx, len]? || "")
        process.stack.push(result)
        result
      end

      # Compare if the top value is less than the second value
      private def execute_less_than(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "LESS_THAN")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("LESS_THAN requires two numeric values")
        end
        check_stack_capacity(process)
        result = Value.new(a.to_f64 < b.to_f64)
        process.stack.push(result)
        result
      end

      # Compare if the second value is greater than the top value
      private def execute_greater_than(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "GREATER_THAN")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("GREATER_THAN requires two numeric values")
        end
        check_stack_capacity(process)
        result = Value.new(a.to_f64 > b.to_f64)
        process.stack.push(result)
        result
      end

      # Compare if the second value is less than or equal to the top value
      private def execute_less_than_or_equal(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "LESS_THAN_OR_EQUAL")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("LESS_THAN_OR_EQUAL requires two numeric values")
        end
        check_stack_capacity(process)
        result = Value.new(a.to_f64 <= b.to_f64)
        process.stack.push(result)
        result
      end

      # Compare if the second value is greater than or equal to the top value
      private def execute_greater_than_or_equal(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "GREATER_THAN_OR_EQUAL")
        b = process.stack.pop
        a = process.stack.pop
        unless a.is_numeric? && b.is_numeric?
          raise TypeMismatchException.new("GREATER_THAN_OR_EQUAL requires two numeric values")
        end
        check_stack_capacity(process)
        result = Value.new(a.to_f64 >= b.to_f64)
        process.stack.push(result)
        result
      end

      # Check if the top two values are equal
      private def execute_equal(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "EQUAL")
        b = process.stack.pop
        a = process.stack.pop
        check_stack_capacity(process)
        result = Value.new(a == b)
        process.stack.push(result)
        result
      end

      # Check if the top two values are not equal
      private def execute_not_equal(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "NOT_EQUAL")
        b = process.stack.pop
        a = process.stack.pop
        check_stack_capacity(process)
        result = Value.new(a != b)
        process.stack.push(result)
        result
      end

      # Logical AND of top two values
      private def execute_and(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "AND")
        b = process.stack.pop
        a = process.stack.pop
        check_stack_capacity(process)
        result = Value.new(a.to_b && b.to_b)
        process.stack.push(result)
        result
      end

      # Logical OR of top two values
      private def execute_or(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "OR")
        b = process.stack.pop
        a = process.stack.pop
        check_stack_capacity(process)
        result = Value.new(a.to_b || b.to_b)
        process.stack.push(result)
        result
      end

      # Logical NOT of top value
      private def execute_not(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "NOT")
        a = process.stack.pop
        check_stack_capacity(process)
        result = Value.new(!a.to_b)
        process.stack.push(result)
        result
      end

      # Load local variable onto stack
      private def execute_load_local(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_unsigned_integer?
          raise TypeMismatchException.new("LOAD_LOCAL requires an Integer index")
        end
        index = instruction.value.to_i64
        if index < 0 || index >= process.locals.size
          raise EmulationException.new("LOAD_LOCAL invalid index: #{index}")
        end
        check_stack_capacity(process)
        value = process.locals[index].clone
        process.stack.push(value)
        value
      end

      # Store top of stack into local variable
      private def execute_store_local(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_unsigned_integer?
          raise TypeMismatchException.new("STORE_LOCAL requires an Integer index")
        end
        check_stack_size(process, 1, "STORE_LOCAL")
        index = instruction.value.to_i64
        value = process.stack.pop

        while process.locals.size <= index
          process.locals.push(Value.new)
        end

        process.locals[index] = value
        value
      end

      # Load global variable onto stack
      private def execute_load_global(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("LOAD_GLOBAL requires a String name")
        end
        name = instruction.value.to_s
        value = process.globals[name]?
        unless value
          raise EmulationException.new("LOAD_GLOBAL undefined variable: #{name}")
        end
        check_stack_capacity(process)
        process.stack.push(value.clone)
        value
      end

      # Store top of stack into global variable
      private def execute_store_global(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("STORE_GLOBAL requires a String name")
        end
        check_stack_size(process, 1, "STORE_GLOBAL")
        name = instruction.value.to_s
        value = process.stack.pop
        process.globals[name] = value
        value
      end

      # Jump if the top stack value is true
      private def execute_jump_if(process : Process, instruction : Instruction) : Value
        process.counter += 1
        check_stack_size(process, 1, "JUMP_IF")
        condition = process.stack.pop
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("JUMP_IF requires an Integer offset")
        end
        offset = instruction.value.to_i64
        if condition.to_b
          new_counter = process.counter.to_i64 + offset
          if new_counter < 0 || new_counter >= process.instructions.size
            raise EmulationException.new("JUMP_IF to invalid address: #{new_counter}")
          end
          process.counter = new_counter.to_u64
        end
        Value.new
      end

      # Jump if the top stack value is false
      private def execute_jump_unless(process : Process, instruction : Instruction) : Value
        process.counter += 1
        check_stack_size(process, 1, "JUMP_UNLESS")
        condition = process.stack.pop
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("JUMP_UNLESS requires an Integer offset")
        end
        offset = instruction.value.to_i64
        unless condition.to_b
          new_counter = process.counter.to_i64 + offset
          if new_counter < 0 || new_counter >= process.instructions.size
            raise EmulationException.new("JUMP_UNLESS to invalid address: #{new_counter}")
          end
          process.counter = new_counter.to_u64
        end
        Value.new
      end

      # Unconditional jump to a specified address
      private def execute_jump(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("JUMP requires an Integer offset")
        end
        offset = instruction.value.to_i64

        # Allow negative offsets for relative backward jumps
        new_counter = process.counter.to_i64 + offset

        if new_counter < 0 || new_counter >= process.instructions.size
          raise EmulationException.new("JUMP to invalid address: #{new_counter} (offset #{offset})")
        end

        process.counter = new_counter.to_u64
        Value.new
      end

      # Print the top value on the stack
      private def execute_print_line(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "PRINT_LINE")
        value = process.stack.pop
        puts value.to_s
        Value.new(nil)
      end

      # Read a line from stdin
      private def execute_read_line(process : Process) : Value
        process.counter += 1
        check_stack_capacity(process)
        line = gets || ""
        result = Value.new(line.chomp)
        process.stack.push(result)
        result
      end

      # Call a subroutine
      private def execute_call(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("CALL requires a String subroutine name")
        end
        subroutine_name = instruction.value.to_s
        subroutine = process.subroutines[subroutine_name]?
        unless subroutine
          raise EmulationException.new("Subroutine not found: #{subroutine_name}")
        end
        check_stack_capacity(process)
        process.call_stack.push(process.counter)
        process.frame_pointer = process.stack.size
        process.counter = subroutine.start_address
        Value.new
      end

      # Return from a subroutine
      private def execute_return(process : Process) : Value
        process.counter += 1
        return_value = if process.stack.empty?
                         Value.new
                       else
                         process.stack.pop
                       end
        unless process.call_stack.empty?
          return_address = process.call_stack.pop
          process.stack = process.stack[0, process.frame_pointer]
          check_stack_capacity(process)
          process.stack.push(return_value)
          process.counter = return_address
        else
          process.state = Process::State::DEAD
        end
        return_value
      end

      # Halt process execution
      private def execute_halt(process : Process) : Value
        process.counter += 1
        process.state = Process::State::DEAD
        Log.debug { "Process <#{process.address}> halted" }
        Value.new
      end

      # Spawn a new process
      private def execute_spawn(process : Process) : Value
        process.counter += 1
        new_process = @engine.process_manager.create_process(instructions: process.instructions)
        @engine.processes << new_process
        check_stack_capacity(process)
        process.stack.push(Value.new(new_process.address.to_i64))
        Value.new(new_process.address.to_i64)
      end

      # Push own process address onto stack
      private def execute_self(process : Process) : Value
        process.counter += 1
        check_stack_capacity(process)
        value = Value.new(process.address.to_i64)
        process.stack.push(value)
        value
      end

      # Send a message to another process
      private def execute_send(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.type == "Tuple(UInt64, Jelly::VirtualMachine::Value)"
          raise TypeMismatchException.new("SEND requires Tuple(UInt64, Value)")
        end
        address, value = Box(Tuple(UInt64, Value)).unbox(instruction.value.pointer)
        if address == 0 && value.is_string?
          process_name = value.to_s
          address = @engine.process_registry.lookup(process_name) || 0
          raise InvalidAddressException.new("No process registered as #{process_name}") if address == 0
          check_stack_size(process, 1, "SEND to named process")
          value = process.stack.pop
        end
        target = @engine.processes.find { |p| p.address == address && p.state != Process::State::DEAD }
        unless target
          raise InvalidAddressException.new("SEND to invalid address #{address}")
        end
        needs_ack = @engine.configuration.enable_message_acks
        ttl = @engine.configuration.default_message_ttl
        message = Message.new(process.address, value, needs_ack, ttl)
        process.add_dependency(target.address)
        if target.mailbox.size >= @engine.configuration.max_mailbox_size
          case @engine.configuration.mailbox_full_behavior
          when :fail
            process.remove_dependency(target.address)
            raise MailboxOverflowException.new("Target mailbox is full")
          when :drop
            Log.warn { "Process <#{process.address}> message to <0.#{target.address}> dropped (mailbox full)" }
            process.remove_dependency(target.address)
            return Value.new(false)
          when :block
            process.state = Process::State::BLOCKED
            process.blocked_sends << {target.address, message}
            Log.debug { "Process <#{process.address}> blocked sending to <0.#{target.address}>" }
            return Value.new
          end
        end
        if target.mailbox.push(message)
          Log.debug { "Process <#{process.address}> sent message to <0.#{target.address}>" }
          if message.needs_ack
            ack = MessageAcknowledgment.new(message.id, target.address, :delivered)
            process.mailbox.add_ack(ack)
          end
          if (target.state == Process::State::WAITING ||
             (target.state == Process::State::STALE && @engine.configuration.auto_reactivate_processes))
            if target.waiting_for.nil? ||
               target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
              @engine.queue_process_for_reactivation(target)
            end
          end
          process.remove_dependency(target.address)
          Value.new(true)
        else
          process.remove_dependency(target.address)
          Value.new(false)
        end
      end

      # Receive a message from the mailbox
      private def execute_receive(process : Process) : Value
        process.counter += 1
        if process.mailbox.empty?
          process.state = Process::State::WAITING
          process.waiting_for = nil
          process.waiting_since = Time.utc
          process.waiting_timeout = nil
          Log.debug { "Process <#{process.address}> waiting for any message" }
          return Value.new
        else
          message = process.mailbox.shift
          return Value.new unless message
          check_stack_capacity(process)
          process.stack.push(message.value)
          if message.needs_ack && @engine.configuration.enable_message_acks
            ack = MessageAcknowledgment.new(message.id, process.address, :processed)
            target = @engine.processes.find { |p| p.address == message.sender }
            target.mailbox.add_ack(ack) if target
          end
          Log.debug { "Process <#{process.address}> received message: #{message.value.inspect}" }
          @engine.check_blocked_sends(process)
          message.value
        end
      end

      # Receive a message matching a pattern
      private def execute_receive_select(process : Process, instruction : Instruction) : Value
        process.counter += 1

        # Determine the pattern
        pattern = if instruction.value.is_null?
                    # Special case: null pattern in instruction means "match anything"
                    nil # we'll handle this specially below
                  else
                    instruction.value
                  end

        # Special handling for wildcard (null pattern)
        if pattern.nil?
          # Get first message, regardless of content
          message = process.mailbox.messages.first
        else
          message = process.mailbox.select(pattern)
        end

        if message
          check_stack_capacity(process)
          process.stack.push(message.value)

          if message.needs_ack && @engine.configuration.enable_message_acks
            ack = MessageAcknowledgment.new(message.id, process.address, :processed)
            target = @engine.processes.find { |p| p.address == message.sender }
            target.mailbox.add_ack(ack) if target
          end

          Log.debug { "Process <#{process.address}> received selected message: #{message.value.inspect}" }
          @engine.check_blocked_sends(process)

          return message.value
        else
          # No matching message → block
          process.state = Process::State::WAITING
          process.waiting_for = pattern
          process.waiting_since = Time.utc
          process.waiting_timeout = nil

          Log.debug { "Process <#{process.address}> waiting for message#{" matching pattern" unless pattern.nil?}" }

          Value.new
        end
      end

      # Receive a message with a timeout
      private def execute_receive_timeout(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.type == "Tuple(Value, Float64)"
          raise TypeMismatchException.new("RECEIVE_TIMEOUT requires Tuple(Value, Float64)")
        end
        pattern, timeout_seconds = Box(Tuple(Value, Float64)).unbox(instruction.value.pointer)
        timeout = timeout_seconds.seconds
        message = process.mailbox.select(pattern)
        if message
          check_stack_capacity(process)
          process.stack.push(message.value)
          if message.needs_ack && @engine.configuration.enable_message_acks
            ack = MessageAcknowledgment.new(message.id, process.address, :processed)
            target = @engine.processes.find { |p| p.address == message.sender }
            target.mailbox.add_ack(ack) if target
          end
          check_stack_capacity(process)
          process.stack.push(Value.new(true))
          Log.debug { "Process <#{process.address}> received message with timeout: #{message.value.inspect}" }
          @engine.check_blocked_sends(process)
          message.value
        else
          if timeout <= 0.seconds
            check_stack_capacity(process)
            process.stack.push(Value.new(false))
            return Value.new
          end
          process.state = Process::State::WAITING
          process.waiting_for = pattern
          process.waiting_since = Time.utc
          process.waiting_timeout = timeout
          Log.debug { "Process <#{process.address}> waiting with #{timeout} timeout" }
          Value.new
        end
      end

      # Schedule a delayed message
      private def execute_send_after(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.type == "Tuple(UInt64, Value, Float64)"
          raise TypeMismatchException.new("SEND_AFTER requires Tuple(UInt64, Value, Float64)")
        end
        address, value, delay_seconds = Box(Tuple(UInt64, Value, Float64)).unbox(instruction.value.pointer)
        target = @engine.processes.find { |p| p.address == address && p.state != Process::State::DEAD }
        unless target
          raise InvalidAddressException.new("SEND_AFTER to invalid address #{address}")
        end
        @engine.schedule_delayed_message(process.address, address, value, delay_seconds)
        Value.new(true)
      end

      # Register a process with a name
      private def execute_register_process(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.type == "String"
          raise TypeMismatchException.new("REGISTER requires a String name")
        end
        name = Box(String).unbox(instruction.value.pointer)
        if @engine.process_registry.register(name, process.address)
          process.registered_name = name
          Log.debug { "Process <#{process.address}> registered as '#{name}'" }
          Value.new(true)
        else
          Log.debug { "Process <#{process.address}> failed to register as '#{name}': name already taken" }
          Value.new(false)
        end
      end

      # Look up a registered process by name
      private def execute_whereis_process(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.type == "String"
          raise TypeMismatchException.new("WHEREIS requires a String name")
        end
        name = Box(String).unbox(instruction.value.pointer)
        if address = @engine.process_registry.lookup(name)
          check_stack_capacity(process)
          process.stack.push(Value.new(address.to_i64))
          Value.new(true)
        else
          check_stack_capacity(process)
          process.stack.push(Value.new)
          Value.new(false)
        end
      end

      # Peek at the next message in the mailbox
      private def execute_peek_mailbox(process : Process) : Value
        process.counter += 1
        if message = process.mailbox.peek
          check_stack_capacity(process)
          process.stack.push(message.value.clone)
          Value.new(true)
        else
          check_stack_capacity(process)
          process.stack.push(Value.new)
          Value.new(false)
        end
      end

      # Kill a process by address
      private def execute_kill(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "KILL")

        addr_value = process.stack.pop
        unless addr_value.is_integer?
          raise TypeMismatchException.new("KILL requires an Integer process address")
        end

        address = addr_value.to_i64.to_u64

        target = @engine.processes.find { |p| p.address == address }

        if target
          target.state = Process::State::DEAD
          Log.debug { "Process <#{process.address}> killed process <#{address}>" }

          # Push success onto the stack
          check_stack_capacity(process)
          process.stack.push(Value.new(true))

          Value.new(true) # optional: return value for consistency, though not used
        else
          # Push failure onto the stack
          check_stack_capacity(process)
          process.stack.push(Value.new(false))

          Value.new(false)
        end
      end

      # Sleep for a number of seconds
      private def execute_sleep(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "SLEEP")
        duration = process.stack.pop
        unless duration.is_numeric?
          raise TypeMismatchException.new("SLEEP requires a numeric value (seconds)")
        end
        seconds = duration.to_f64
        if seconds > 0
          sleep seconds.seconds
        end
        Value.new
      end

      # Create a new empty map
      private def execute_map_new(process : Process) : Value
        process.counter += 1
        check_stack_capacity(process)
        value = Value.new(Hash(String, Value).new)
        process.stack.push(value)
        value
      end

      # Get value from map by key
      private def execute_map_get(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "MAP_GET")
        key = process.stack.pop
        map_val = process.stack.pop
        unless map_val.is_map?
          raise TypeMismatchException.new("MAP_GET requires a Map")
        end
        unless key.is_string?
          raise TypeMismatchException.new("MAP_GET requires a String key")
        end
        check_stack_capacity(process)
        map = map_val.to_h
        result = map[key.to_s]? || Value.new
        process.stack.push(result.clone)
        result
      end

      # Set value in map by key
      private def execute_map_set(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 3, "MAP_SET")
        value = process.stack.pop
        key = process.stack.pop
        map_val = process.stack.pop
        unless map_val.is_map?
          raise TypeMismatchException.new("MAP_SET requires a Map")
        end
        unless key.is_string?
          raise TypeMismatchException.new("MAP_SET requires a String key")
        end
        check_stack_capacity(process)
        map = map_val.to_h
        map[key.to_s] = value
        result = Value.new(map)
        process.stack.push(result)
        result
      end

      # Delete key from map
      private def execute_map_delete(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "MAP_DELETE")
        key = process.stack.pop
        map_val = process.stack.pop
        unless map_val.is_map?
          raise TypeMismatchException.new("MAP_DELETE requires a Map")
        end
        unless key.is_string?
          raise TypeMismatchException.new("MAP_DELETE requires a String key")
        end
        check_stack_capacity(process)
        map = map_val.to_h
        map.delete(key.to_s)
        result = Value.new(map)
        process.stack.push(result)
        result
      end

      # Get all keys from map as array
      private def execute_map_keys(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "MAP_KEYS")
        map_val = process.stack.pop
        unless map_val.is_map?
          raise TypeMismatchException.new("MAP_KEYS requires a Map")
        end
        check_stack_capacity(process)
        map = map_val.to_h
        keys = map.keys.map { |k| Value.new(k) }
        result = Value.new(keys)
        process.stack.push(result)
        result
      end

      # Get size of map
      private def execute_map_size(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "MAP_SIZE")
        map_val = process.stack.pop
        unless map_val.is_map?
          raise TypeMismatchException.new("MAP_SIZE requires a Map")
        end
        check_stack_capacity(process)
        result = Value.new(map_val.to_h.size.to_u64)
        process.stack.push(result)
        result
      end

      # Create a new array
      private def execute_array_new(process : Process, instruction : Instruction) : Value
        process.counter += 1
        check_stack_capacity(process)
        size = if instruction.value.is_integer?
                 instruction.value.to_i64
               else
                 0
               end
        arr = Array(Value).new(size) { Value.new }
        result = Value.new(arr)
        process.stack.push(result)
        result
      end

      # Get element from array by index
      private def execute_array_get(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_GET")
        index = process.stack.pop
        arr_val = process.stack.pop
        unless arr_val.is_array?
          raise TypeMismatchException.new("ARRAY_GET requires an Array")
        end
        unless index.is_integer?
          raise TypeMismatchException.new("ARRAY_GET requires an Integer index")
        end
        check_stack_capacity(process)
        arr = arr_val.to_a
        idx = index.to_i64
        if idx < 0 || idx >= arr.size
          raise EmulationException.new("ARRAY_GET index out of bounds: #{idx}")
        end
        result = arr[idx].clone
        process.stack.push(result)
        result
      end

      # Set element in array by index
      private def execute_array_set(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 3, "ARRAY_SET")
        value = process.stack.pop
        index = process.stack.pop
        arr_val = process.stack.pop
        unless arr_val.is_array?
          raise TypeMismatchException.new("ARRAY_SET requires an Array")
        end
        unless index.is_integer?
          raise TypeMismatchException.new("ARRAY_SET requires an Integer index")
        end
        check_stack_capacity(process)
        arr = arr_val.to_a
        idx = index.to_i64
        if idx < 0 || idx >= arr.size
          raise EmulationException.new("ARRAY_SET index out of bounds: #{idx}")
        end
        arr[idx] = value
        result = Value.new(arr)
        process.stack.push(result)
        result
      end

      # Push element to end of array
      private def execute_array_push(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_PUSH")
        value = process.stack.pop
        arr_val = process.stack.pop
        unless arr_val.is_array?
          raise TypeMismatchException.new("ARRAY_PUSH requires an Array")
        end
        check_stack_capacity(process)
        arr = arr_val.to_a
        arr.push(value)
        result = Value.new(arr)
        process.stack.push(result)
        result
      end

      # Pop element from end of array
      private def execute_array_pop(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_POP")
        arr_val = process.stack.pop
        unless arr_val.is_array?
          raise TypeMismatchException.new("ARRAY_POP requires an Array")
        end
        arr = arr_val.to_a
        if arr.empty?
          raise EmulationException.new("ARRAY_POP on empty array")
        end
        check_stack_capacity(process)
        value = arr.pop
        result = Value.new(arr)
        process.stack.push(result)
        process.stack.push(value)
        value
      end

      # Get length of array
      private def execute_array_length(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_LENGTH")
        arr_val = process.stack.pop
        unless arr_val.is_array?
          raise TypeMismatchException.new("ARRAY_LENGTH requires an Array")
        end
        check_stack_capacity(process)
        result = Value.new(arr_val.to_a.size.to_u64)
        process.stack.push(result)
        result
      end

      # Throw an exception
      private def execute_throw(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "THROW")
        error_value = process.stack.pop
        raise EmulationException.new("THROW: #{error_value.to_s}")
      end

      # Link current process with another
      private def execute_link(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "LINK")

        other_pid_val = process.stack.pop
        unless other_pid_val.is_integer?
          raise TypeMismatchException.new("LINK requires an Integer process address")
        end

        other_pid = other_pid_val.to_i64.to_u64

        # Check if target process exists
        target = @engine.processes.find { |p| p.address == other_pid && p.state != Process::State::DEAD }
        unless target
          raise InvalidAddressException.new("LINK to invalid or dead process #{other_pid}")
        end

        @engine.process_links.link(process.address, other_pid)
        Log.debug { "Process <#{process.address}> linked with <#{other_pid}>" }

        Value.new(true)
      end

      # Remove link between current process and another
      private def execute_unlink(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "UNLINK")

        other_pid_val = process.stack.pop
        unless other_pid_val.is_integer?
          raise TypeMismatchException.new("UNLINK requires an Integer process address")
        end

        other_pid = other_pid_val.to_i64.to_u64
        result = @engine.process_links.unlink(process.address, other_pid)

        Log.debug { "Process <#{process.address}> unlinked from <#{other_pid}>: #{result}" }

        check_stack_capacity(process)
        process.stack.push(Value.new(result))
        Value.new(result)
      end

      # Monitor another process
      private def execute_monitor(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "MONITOR")

        target_pid_val = process.stack.pop
        unless target_pid_val.is_integer?
          raise TypeMismatchException.new("MONITOR requires an Integer process address")
        end

        target_pid = target_pid_val.to_i64.to_u64

        # Check if target exists
        target = @engine.processes.find { |p| p.address == target_pid }

        if target && target.state != Process::State::DEAD
          # Create monitor
          ref = @engine.process_links.monitor(process.address, target_pid)

          check_stack_capacity(process)
          process.stack.push(Value.new(ref.id.to_i64))

          Log.debug { "Process <#{process.address}> monitoring <#{target_pid}> (ref: #{ref.id})" }
          Value.new(ref.id.to_i64)
        else
          # Target doesn't exist - immediately send DOWN message
          ref = MonitorRef.new(process.address, target_pid)
          down = DownMessage.new(ref, target_pid, ExitReason.noproc)

          message = Message.new(target_pid, down.to_value)
          process.mailbox.push(message)

          check_stack_capacity(process)
          process.stack.push(Value.new(ref.id.to_i64))

          Log.debug { "Process <#{process.address}> monitoring dead process <#{target_pid}> - DOWN sent" }
          Value.new(ref.id.to_i64)
        end
      end

      # Stop monitoring a process
      private def execute_demonitor(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "DEMONITOR")

        ref_id_val = process.stack.pop
        unless ref_id_val.is_integer?
          raise TypeMismatchException.new("DEMONITOR requires an Integer reference")
        end

        ref_id = ref_id_val.to_i64.to_u64

        # Find the monitor ref
        monitors = @engine.process_links.get_monitors(process.address)
        ref = monitors.find { |r| r.id == ref_id }

        result = if ref
                   @engine.process_links.demonitor(ref)
                 else
                   false
                 end

        check_stack_capacity(process)
        process.stack.push(Value.new(result))
        Value.new(result)
      end

      # Enable/disable exit trapping
      private def execute_trap_exit(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "TRAP_EXIT")

        enable_val = process.stack.pop
        enable = enable_val.to_b

        old_value = @engine.process_links.traps_exit?(process.address)
        @engine.process_links.trap_exit(process.address, enable)

        check_stack_capacity(process)
        process.stack.push(Value.new(old_value))

        Log.debug { "Process <#{process.address}> trap_exit: #{old_value} -> #{enable}" }
        Value.new(old_value)
      end

      # Send exit signal to another process
      private def execute_exit(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "EXIT")

        reason_val = process.stack.pop
        target_val = process.stack.pop

        unless target_val.is_integer?
          raise TypeMismatchException.new("EXIT requires an Integer process address")
        end

        target_pid = target_val.to_i64.to_u64
        reason_str = reason_val.to_s

        reason = if reason_str == "kill"
                   ExitReason.kill
                 elsif reason_str == "normal"
                   ExitReason.normal
                 else
                   ExitReason.custom(reason_str)
                 end

        @engine.fault_handler.exit_process(process.address, target_pid, reason)

        Log.debug { "Process <#{process.address}> sent exit '#{reason}' to <#{target_pid}>" }
        Value.new(true)
      end

      # Exit current process
      private def execute_exit_self(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "EXIT_SELF")

        reason_val = process.stack.pop
        reason_str = reason_val.to_s

        reason = if reason_str == "normal"
                   ExitReason.normal
                 elsif reason_str == "shutdown"
                   ExitReason.shutdown
                 else
                   ExitReason.custom(reason_str)
                 end

        process.state = Process::State::DEAD
        process.exit_reason = reason

        @engine.fault_handler.handle_exit(process, reason)

        Log.debug { "Process <#{process.address}> exited: #{reason}" }
        Value.new
      end

      # Spawn and link atomically
      private def execute_spawn_link(process : Process) : Value
        process.counter += 1

        # Create new process
        new_process = @engine.process_manager.create_process(instructions: process.instructions)
        @engine.processes << new_process

        # Atomically link
        @engine.process_links.link(process.address, new_process.address)

        check_stack_capacity(process)
        process.stack.push(Value.new(new_process.address.to_i64))

        Log.debug { "Process <#{process.address}> spawn_linked <#{new_process.address}>" }
        Value.new(new_process.address.to_i64)
      end

      # Spawn and monitor atomically
      private def execute_spawn_monitor(process : Process) : Value
        process.counter += 1

        # Create new process
        new_process = @engine.process_manager.create_process(instructions: process.instructions)
        @engine.processes << new_process

        # Atomically monitor
        ref = @engine.process_links.monitor(process.address, new_process.address)

        check_stack_capacity(process)
        process.stack.push(Value.new(new_process.address.to_i64))
        process.stack.push(Value.new(ref.id.to_i64))

        Log.debug { "Process <#{process.address}> spawn_monitored <#{new_process.address}> (ref: #{ref.id})" }
        Value.new(new_process.address.to_i64)
      end

      # Check if a process is alive
      private def execute_is_alive(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "IS_ALIVE")

        pid_val = process.stack.pop
        unless pid_val.is_integer?
          raise TypeMismatchException.new("IS_ALIVE requires an Integer process address")
        end

        pid = pid_val.to_i64.to_u64
        target = @engine.processes.find { |p| p.address == pid }

        alive = target && target.state != Process::State::DEAD

        check_stack_capacity(process)
        process.stack.push(Value.new(alive))
        Value.new(alive)
      end

      # Get information about a process
      private def execute_process_info(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_INFO")

        pid_val = process.stack.pop
        unless pid_val.is_integer?
          raise TypeMismatchException.new("PROCESS_INFO requires an Integer process address")
        end

        pid = pid_val.to_i64.to_u64
        target = @engine.processes.find { |p| p.address == pid }

        if target
          info = Hash(String, Value).new
          info["address"] = Value.new(target.address.to_i64)
          info["state"] = Value.new(target.state.to_s)
          info["registered_name"] = target.registered_name ? Value.new(target.registered_name.not_nil!) : Value.new
          info["mailbox_size"] = Value.new(target.mailbox.size.to_i64)
          info["stack_size"] = Value.new(target.stack.size.to_i64)
          info["counter"] = Value.new(target.counter.to_i64)
          info["links"] = Value.new(@engine.process_links.get_links(pid).map { |l| Value.new(l.to_i64) })
          info["trap_exit"] = Value.new(@engine.process_links.traps_exit?(pid))

          check_stack_capacity(process)
          process.stack.push(Value.new(info))
          Value.new(info)
        else
          check_stack_capacity(process)
          process.stack.push(Value.new)
          Value.new
        end
      end

      # Begin a try-catch block
      private def execute_try_catch(process : Process, instruction : Instruction) : Value
        process.counter += 1

        unless instruction.value.is_integer?
          raise TypeMismatchException.new("TRY_CATCH requires an Integer catch offset")
        end

        catch_offset = instruction.value.to_i64
        catch_address = (process.counter.to_i64 + catch_offset).to_u64

        handler = ExceptionHandler.new(
          catch_address,
          process.stack.size,
          process.call_stack.size
        )

        process.exception_handlers.push(handler)

        Log.debug { "Process <#{process.address}> entered try block (catch at #{catch_address})" }
        Value.new
      end

      # End a try block without exception
      private def execute_end_try(process : Process) : Value
        process.counter += 1

        if process.exception_handlers.empty?
          raise EmulationException.new("END_TRY without matching TRY_CATCH")
        end

        process.exception_handlers.pop

        Log.debug { "Process <#{process.address}> exited try block normally" }
        Value.new
      end

      # Entry point for exception handler
      private def execute_catch(process : Process) : Value
        process.counter += 1
        # Exception value is already on the stack from handle_exception
        # Just continue execution
        Log.debug { "Process <#{process.address}> in catch block" }
        Value.new
      end

      # Rethrow current exception
      private def execute_rethrow(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "RETHROW")

        exception_val = process.stack.pop

        # Try to jump to next exception handler
        if handler = process.exception_handlers.pop?
          # Restore state and jump to handler
          while process.stack.size > handler.stack_size
            process.stack.pop
          end
          while process.call_stack.size > handler.call_stack_size
            process.call_stack.pop
          end

          process.stack.push(exception_val)
          process.counter = handler.catch_address

          Log.debug { "Process <#{process.address}> rethrew to catch at #{handler.catch_address}" }
        else
          # No handler - process dies
          raise EmulationException.new("Unhandled exception: #{exception_val.to_s}")
        end

        Value.new
      end

      # Set a process flag
      private def execute_set_flag(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 2, "SET_FLAG")

        value = process.stack.pop
        flag_name_val = process.stack.pop

        unless flag_name_val.is_string?
          raise TypeMismatchException.new("SET_FLAG requires a String flag name")
        end

        flag_name = flag_name_val.to_s
        old_value = process.flags[flag_name]?
        process.flags[flag_name] = value

        check_stack_capacity(process)
        process.stack.push(old_value || Value.new)

        Log.debug { "Process <#{process.address}> set flag '#{flag_name}'" }
        old_value || Value.new
      end

      # Get a process flag
      private def execute_get_flag(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "GET_FLAG")

        flag_name_val = process.stack.pop

        unless flag_name_val.is_string?
          raise TypeMismatchException.new("GET_FLAG requires a String flag name")
        end

        flag_name = flag_name_val.to_s
        value = process.flags[flag_name]? || Value.new

        check_stack_capacity(process)
        process.stack.push(value)

        value
      end

      # Handle an exception in the current process
      def handle_exception(process : Process, exception : Exception) : Bool
        if handler = process.exception_handlers.pop?
          # Restore state
          while process.stack.size > handler.stack_size
            process.stack.pop
          end
          while process.call_stack.size > handler.call_stack_size
            process.call_stack.pop
          end

          # Push exception info
          exception_val = Value.new({
            "type"    => Value.new("exception"),
            "message" => Value.new(exception.message || "unknown"),
          } of String => Value)

          process.stack.push(exception_val)
          process.counter = handler.catch_address
          process.state = Process::State::ALIVE

          Log.debug { "Process <#{process.address}> caught exception at #{handler.catch_address}" }
          true
        else
          false
        end
      end

      # Helper method to check stack size
      private def check_stack_size(process : Process, required : Int32, operation : String)
        raise EmulationException.new("Stack underflow for #{operation}") if process.stack.size < required
      end

      # Helper method to check stack capacity
      private def check_stack_capacity(process : Process)
        raise EmulationException.new("Stack overflow") if process.stack.size >= @engine.configuration.max_stack_size
      end
    end
  end
end
