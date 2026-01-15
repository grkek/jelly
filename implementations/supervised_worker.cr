require "../src/jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Create supervisor with restart strategy
supervisor = engine.create_supervisor(
  strategy: VM::Supervisor::RestartStrategy::OneForOne,
  max_restarts: 5,
  restart_window: 10.seconds
)

# Worker that might fail
worker_instructions = [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Worker starting...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Worker stopping...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:normal)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

# Permanent - Always restart (even on normal exit) - use for long-running services
# Transient - Only restart on abnormal exit - use for task workers
# Temporary - Never restart - use for one-shot tasks

# Define child specification
worker_specification = VM::Supervisor::Child::Specification.new(
  id: "worker",
  instructions: worker_instructions,
  restart: VM::Supervisor::RestartType::Transient,  # Only restart on abnormal exit
  max_restarts: 3,
  restart_window: 5.seconds
)

# Add worker to supervisor and run
supervisor.add_child(worker_specification)
engine.run
