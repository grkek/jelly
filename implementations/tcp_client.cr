require "../src/jelly"

alias VirtualMachine = Jelly::VirtualMachine

engine = VirtualMachine::Engine.new

worker_instructions = [
  # Connect to icanhazip.com
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("icanhazip.com")), # 0
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(80_i64)),         # 1
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_CONNECT),                                             # 2
  VirtualMachine::Instruction.new(VirtualMachine::Code::DUPLICATE),                                               # 3
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_NULL),                                               # 4
  VirtualMachine::Instruction.new(VirtualMachine::Code::EQUAL),                                                   # 5
  VirtualMachine::Instruction.new(VirtualMachine::Code::JUMP_IF, VirtualMachine::Value.new(30_i64)),              # 6 -> jump to failure path

  # Success path - store socket in local 0
  VirtualMachine::Instruction.new(VirtualMachine::Code::STORE_LOCAL, VirtualMachine::Value.new(0_i64)), # 7

  # Send HTTP request
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),                                                                 # 8
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("GET / HTTP/1.1\r\nHost: icanhazip.com\r\nConnection: close\r\n\r\n")), # 9
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_SEND),                                                                                                     # 10
  VirtualMachine::Instruction.new(VirtualMachine::Code::POP),                                                                                                          # 11

  # Receive response and convert to string
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),      # 12
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(2048_i64)), # 13
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_RECEIVE),                                       # 14
  VirtualMachine::Instruction.new(VirtualMachine::Code::BINARY_TO_STRING),                                  # 15
  VirtualMachine::Instruction.new(VirtualMachine::Code::STORE_LOCAL, VirtualMachine::Value.new(1_i64)),     # 16 - store response in local 1

  # Find "\r\n\r\n" (end of headers)
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(1_i64)),       # 17
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("\r\n\r\n")), # 18
  VirtualMachine::Instruction.new(VirtualMachine::Code::STRING_INDEX),                                       # 19 - find index of blank line
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(4_i64)),     # 20 - add 4 to skip past \r\n\r\n
  VirtualMachine::Instruction.new(VirtualMachine::Code::ADD),                                                # 21
  VirtualMachine::Instruction.new(VirtualMachine::Code::STORE_LOCAL, VirtualMachine::Value.new(2_i64)),      # 22 - store body start index

  # Extract body (from body_start to end)
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(1_i64)),    # 23 - load response
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(2_i64)),    # 24 - load body start index
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_INTEGER, VirtualMachine::Value.new(50_i64)), # 25 - length (50 chars is plenty for an IP)
  VirtualMachine::Instruction.new(VirtualMachine::Code::STRING_SUBSTRING),                                # 26
  VirtualMachine::Instruction.new(VirtualMachine::Code::STRING_TRIM),                                     # 27 - trim whitespace

  # Print the IP
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("Your IP: ")), # 28
  VirtualMachine::Instruction.new(VirtualMachine::Code::SWAP),                                                # 29
  VirtualMachine::Instruction.new(VirtualMachine::Code::STRING_CONCATENATE),                                  # 30
  VirtualMachine::Instruction.new(VirtualMachine::Code::PRINT_LINE),                                          # 31

  # Close socket
  VirtualMachine::Instruction.new(VirtualMachine::Code::LOAD_LOCAL, VirtualMachine::Value.new(0_i64)),     # 32
  VirtualMachine::Instruction.new(VirtualMachine::Code::TCP_CLOSE),                                        # 33
  VirtualMachine::Instruction.new(VirtualMachine::Code::POP),                                              # 34
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("normal")), # 35
  VirtualMachine::Instruction.new(VirtualMachine::Code::EXIT_SELF),                                        # 36

  # Failure path (index 37)
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("Connection failed")),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PRINT_LINE),
  VirtualMachine::Instruction.new(VirtualMachine::Code::PUSH_STRING, VirtualMachine::Value.new("connect_failed")), # Non-normal exit
  VirtualMachine::Instruction.new(VirtualMachine::Code::EXIT_SELF),
]

# Create supervisor
supervisor = engine.create_supervisor(
  strategy: VirtualMachine::RestartStrategy::OneForOne,
  max_restarts: 3,
  restart_window: 5.seconds
)

Log.info { "Supervisor created with address <#{supervisor.address}>" }

worker = VirtualMachine::Specification.new(
  id: "worker",
  instructions: worker_instructions,
  restart: VirtualMachine::RestartType::Transient,
  max_restarts: 3,
  restart_window: 5.seconds
)

supervisor.add_child(worker)

Log.info { "Starting VM with properly supervised worker..." }

Log.setup(:debug)

engine.run

sleep 5.seconds

Log.info { "Final fault tolerance stats: #{engine.fault_tolerance_stats}" }
Log.info { "Supervisor child status: #{supervisor.child_status}" }
