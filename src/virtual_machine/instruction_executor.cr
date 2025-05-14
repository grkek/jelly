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
          when Code::PUSH_INTEGER     then execute_push_integer(process, instruction)
          when Code::PUSH_FLOAT       then execute_push_float(process, instruction)
          when Code::PUSH_STRING      then execute_push_string(process, instruction)
          when Code::PUSH_BOOLEAN     then execute_push_boolean(process, instruction)
          when Code::PUSH_NULL        then execute_push_null(process)
          when Code::POP              then execute_pop(process)
          when Code::DUPLICATE        then execute_duplicate(process)
          when Code::SWAP             then execute_swap(process)
          when Code::CONCATENATE      then execute_concatenate(process)
          when Code::ADD              then execute_add(process)
          when Code::LESS_THAN        then execute_less_than(process)
          when Code::EQUAL            then execute_equal(process)
          when Code::SUBTRACT         then execute_subtract(process)
          when Code::JUMP_IF          then execute_jump_if(process, instruction)
          when Code::JUMP             then execute_jump(process, instruction)
          when Code::PRINT            then execute_print(process)
          when Code::CALL             then execute_call(process, instruction)
          when Code::RETURN           then execute_return(process)
          when Code::SPAWN            then execute_spawn(process)
          when Code::SEND             then execute_send(process, instruction)
          when Code::RECEIVE          then execute_receive(process)
          when Code::RECEIVE_SELECT   then execute_receive_select(process, instruction)
          when Code::RECEIVE_TIMEOUT  then execute_receive_timeout(process, instruction)
          when Code::SEND_AFTER       then execute_send_after(process, instruction)
          when Code::REGISTER_PROCESS then execute_register_process(process, instruction)
          when Code::WHEREIS_PROCESS  then execute_whereis_process(process, instruction)
          when Code::PEEK_MAILBOX     then execute_peek_mailbox(process)
          else
            if handler = @engine.custom_handlers[instruction.code]?
              handler.call(process, instruction)
            else
              raise InvalidInstructionException.new("Unknown instruction: #{instruction.code}")
            end
          end
        rescue ex : VMException
          Log.error { "Process <#{process.address}>: #{ex.message}" }
          process.state = Process::State::DEAD
          Value.new(ex)
        rescue ex : Exception
          Log.error { "Process <#{process.address}>: Unhandled error: #{ex.message}" }
          process.state = Process::State::DEAD
          Value.new(ex)
        end
      end

      # Push an integer value onto the stack
      private def execute_push_integer(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("PUSH_INTEGER requires an Integer value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_i)
        process.stack.push(value)
        value
      end

      # Push a float value onto the stack
      private def execute_push_float(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_float?
          raise TypeMismatchException.new("PUSH_FLOAT requires a Float value")
        end
        check_stack_capacity(process)
        value = Value.new(instruction.value.to_f)
        process.stack.push(value)
        value
      end

      # Push a string value onto the stack
      private def execute_push_string(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("PUSH_STRING requires a String value")
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
          raise TypeMismatchException.new("PUSH_BOOLEAN requires a Boolean value")
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
          result = Value.new(a.to_f + b.to_f)
        else
          result = Value.new(a.to_i + b.to_i)
        end
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
        result = Value.new(a.to_f < b.to_f)
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
          result = Value.new(a.to_f - b.to_f)
        else
          result = Value.new(a.to_i - b.to_i)
        end
        process.stack.push(result)
        result
      end

      # Jump if the top stack value is true
      private def execute_jump_if(process : Process, instruction : Instruction) : Value
        process.counter += 1
        check_stack_size(process, 1, "JUMP_IF")
        condition = process.stack.pop
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("JUMP_IF requires an Integer offset")
        end
        offset = instruction.value.to_i
        if condition.to_b
          new_counter = process.counter + offset
          if new_counter < 0 || new_counter >= @engine.instructions.size
            raise VMException.new("JUMP_IF to invalid address: #{new_counter}")
          end
          process.counter = new_counter.to_u64
        end
        Value.new
      end

      # Unconditional jump to a specified address
      private def execute_jump(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_integer?
          raise TypeMismatchException.new("JUMP requires an Integer address")
        end
        address = instruction.value.to_i
        if address < 0 || address >= @engine.instructions.size
          raise VMException.new("JUMP to invalid address: #{address}")
        end
        process.counter = address.to_u64
        Value.new
      end

      # Print the top value on the stack
      private def execute_print(process : Process) : Value
        process.counter += 1
        check_stack_size(process, 1, "PRINT")
        value = process.stack.pop

        puts value.to_s

        Value.new(nil)
      end

      # Call a subroutine
      private def execute_call(process : Process, instruction : Instruction) : Value
        process.counter += 1
        unless instruction.value.is_string?
          raise TypeMismatchException.new("CALL requires a String subroutine name")
        end
        subroutine_name = instruction.value.to_s
        subroutine = @engine.subroutines[subroutine_name]?
        unless subroutine
          raise VMException.new("Subroutine not found: #{subroutine_name}")
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
                         process.stack.last
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

      # Spawn a new process
      private def execute_spawn(process : Process) : Value
        process.counter += 1
        new_process = @engine.process_manager.create_process
        check_stack_capacity(process)
        process.stack.push(Value.new(new_process.address.to_i))
        Value.new(new_process.address.to_i)
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
        needs_ack = @engine.config.enable_message_acks
        ttl = @engine.config.default_message_ttl
        message = Message.new(process.address, value, needs_ack, ttl)
        process.add_dependency(target.address)
        if target.mailbox.size >= @engine.config.max_mailbox_size
          case @engine.config.mailbox_full_behavior
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
             (target.state == Process::State::STALE && @engine.config.auto_reactivate_processes))
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
          if message.needs_ack && @engine.config.enable_message_acks
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
        unless instruction.value.is_null?
          pattern = instruction.value
        else
          check_stack_size(process, 1, "RECEIVE_SELECT")
          pattern = process.stack.pop
        end
        message = process.mailbox.select(pattern)
        if message
          check_stack_capacity(process)
          process.stack.push(message.value)
          if message.needs_ack && @engine.config.enable_message_acks
            ack = MessageAcknowledgment.new(message.id, process.address, :processed)
            target = @engine.processes.find { |p| p.address == message.sender }
            target.mailbox.add_ack(ack) if target
          end
          Log.debug { "Process <#{process.address}> received selected message: #{message.value.inspect}" }
          @engine.check_blocked_sends(process)
          message.value
        else
          process.state = Process::State::WAITING
          process.waiting_for = pattern
          process.waiting_since = Time.utc
          process.waiting_timeout = nil
          Log.debug { "Process <#{process.address}> waiting for message matching pattern" }
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
          if message.needs_ack && @engine.config.enable_message_acks
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
          process.stack.push(Value.new(address.to_i))
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

      # Helper method to check stack size
      private def check_stack_size(process : Process, required : Int32, operation : String)
        raise VMException.new("Stack underflow for #{operation}") if process.stack.size < required
      end

      # Helper method to check stack capacity
      private def check_stack_capacity(process : Process)
        raise VMException.new("Stack overflow") if process.stack.size >= @engine.config.max_stack_size
      end
    end
  end
end
