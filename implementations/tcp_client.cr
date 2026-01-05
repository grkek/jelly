require "../src/jelly"

Log.setup(:debug)

alias VirtualMachine = Jelly::VirtualMachine

engine = VirtualMachine::Engine.new

# Worker instructions — unchanged
worker_instructions = [
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("icanhazip.com")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(80_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_CONNECT),
  VirtualMachine::Instruction.new(VirtualMachine::Code::DUPLICATE),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_NULL),
  VirtualMachine::Instruction.new(VirtualMachine::Code::EQUAL),
  VirtualMachine::Instruction.new(VirtualMachine::Code::JUMP_IF, VirtualMachine::Value.new(18_i64)),

  # Success path
  VirtualMachine::Instruction.new(VirtualMachine::Code::STORE_LOCAL, VirtualMachine::Value.new(0_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("GET / HTTP/1.0\r\nHost: icanhazip.com\r\nConnection: close\r\n\r\n")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_SEND),
  VirtualMachine::Instruction.new(VirtualMachine::Code::POP),

  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(1024_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_RECEIVE),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PRINT_LINE),

  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_CLOSE),
  VirtualMachine::Instruction.new(VirtualMachine::Code::POP),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("normal")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::EXIT_SELF),

  # Failure path
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("Failed to connect – will be restarted by supervisor")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PRINT_LINE),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("connect_failed")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::EXIT_SELF),
]

# Create supervisor — this automatically registers it
supervisor = engine.create_supervisor(
  strategy: VirtualMachine::RestartStrategy::OneForOne,
  max_restarts: 3,
  restart_window: 5.seconds
)

Log.info { "Supervisor created with address <#{supervisor.address}>" }

# Create a proper child specification
ip_fetcher_spec = VirtualMachine::Specification.new(
  id: "ip_fetcher",
  instructions: worker_instructions,
  restart: VirtualMachine::RestartType::Transient,  # Restart only on abnormal exit
  max_restarts: 3,
  restart_window: 5.seconds
)

# Add the child — this starts it immediately
supervisor.add_child(ip_fetcher_spec)

Log.info { "Starting VM with properly supervised worker..." }

# Run the VM
engine.run

# Keep main thread alive to observe behavior
sleep 5.seconds

Log.info { "Final fault tolerance stats: #{engine.fault_tolerance_stats}" }
Log.info { "Supervisor child status: #{supervisor.child_status}" }
