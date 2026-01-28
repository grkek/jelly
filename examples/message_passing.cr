require "../src/abstract_machine"

Log.setup(:debug)

engine = AbstractMachine::Engine::Context.new

engine.register_built_in_function("IO", "printLine", 1) do |engine, process, arguments|
  puts arguments[0].to_s
  AbstractMachine::Value::Context.null
end

# Process 1: Receiver - waits for messages and prints them
receiver = engine.create_process(
  instructions: [
    # Register this process as "receiver"
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PROCESS_SELF),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PROCESS_REGISTER, AbstractMachine::Value::Context.new("receiver")),

    # Wait for and print first message
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::MESSAGE_RECEIVE),
    AbstractMachine::Instruction::Operation.new(
      AbstractMachine::Instruction::Code::CONTROL_CALL_BUILT_IN_FUNCTION,
      AbstractMachine::Value::Context.new(
        [
          AbstractMachine::Value::Context.new("IO"),
          AbstractMachine::Value::Context.new("printLine"),
          AbstractMachine::Value::Context.new(1_i64),
        ]
      )
    ),

    # Wait for and print second message
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::MESSAGE_RECEIVE),
    AbstractMachine::Instruction::Operation.new(
      AbstractMachine::Instruction::Code::CONTROL_CALL_BUILT_IN_FUNCTION,
      AbstractMachine::Value::Context.new(
        [
          AbstractMachine::Value::Context.new("IO"),
          AbstractMachine::Value::Context.new("printLine"),
          AbstractMachine::Value::Context.new(1_i64),
        ]
      )
    ),

    # Exit normally
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("normal")),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PROCESS_EXIT),
  ]
)

# Process 2: Sender - sends messages to the receiver
sender = engine.create_process(
  instructions: [
    # Yield to let receiver register first
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PROCESS_YIELD),

    # Send first message to "receiver"
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("receiver")),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_CUSTOM, AbstractMachine::Value::Context.new({"hello" => "world"})),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::MESSAGE_SEND),

    # Send second message
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("receiver")),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("Hello, World!")),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::MESSAGE_SEND),

    # Print confirmation
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("Sender: Messages sent!")),
    AbstractMachine::Instruction::Operation.new(
      AbstractMachine::Instruction::Code::CONTROL_CALL_BUILT_IN_FUNCTION,
      AbstractMachine::Value::Context.new(
        [
          AbstractMachine::Value::Context.new("IO"),
          AbstractMachine::Value::Context.new("printLine"),
          AbstractMachine::Value::Context.new(1_i64),
        ]
      )
    ),

    # Exit normally
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PUSH_STRING, AbstractMachine::Value::Context.new("normal")),
    AbstractMachine::Instruction::Operation.new(AbstractMachine::Instruction::Code::PROCESS_EXIT),
  ]
)

engine.processes.push(receiver)
engine.processes.push(sender)

engine.scheduler.enqueue(receiver)
engine.scheduler.enqueue(sender)

engine.run

sleep 1.seconds
