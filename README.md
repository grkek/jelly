# Jelly

An abstract virtual machine for building concurrent, fault-tolerant applications. Jelly combines a stack-based bytecode interpreter with Erlang-inspired actor-model concurrency and supervision trees.

## Features

- **Stack-based VM** - Simple, predictable execution model with a rich instruction set
- **Actor Model Concurrency** - Lightweight processes with message passing
- **Fault Tolerance** - Process linking, monitoring, and supervision trees
- **First-class Data Structures** - Maps, arrays, and strings with built-in operations
- **TCP Networking** - Socket operations for building networked applications
- **Exception Handling** - Try-catch blocks with rethrow support

## Quick Start

### Installation

Add Jelly to your `shard.yml`:

```yaml
dependencies:
  jelly:
    github: grkek/jelly
```

Then run:

```bash
shards install
```

### Hello World

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

instructions = [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Hello, Jelly!")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)
engine.run
```

## Core Concepts

### The Stack Machine

Jelly uses a stack-based architecture. Values are pushed onto a stack, and operations pop their arguments and push results back.

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Compute (10 + 5) * 3 = 45
instructions = [
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(10_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(5_i64)),
  VM::Instruction.new(VM::Code::ADD),                                    # Stack: [15]
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(3_i64)),
  VM::Instruction.new(VM::Code::MULTIPLY),                               # Stack: [45]
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)
engine.run
```

### Processes and Message Passing

Jelly processes are lightweight units of execution with their own stack, mailbox, and local variables. Processes communicate exclusively through asynchronous message passing.

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Create a worker that receives and processes messages
worker_instructions = [
  VM::Instruction.new(VM::Code::RECEIVE), # Wait for message
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Received: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::HALT),
]

worker = engine.process_manager.create_process(instructions: worker_instructions)
engine.processes.push(worker)

# Send a message to the worker
tuple = {worker.address, VM::Value.new("Hello from sender!")}
sender_instructions = [
  VM::Instruction.new(VM::Code::SEND, VM::Value.new(tuple)),
  VM::Instruction.new(VM::Code::HALT),
]

sender = engine.process_manager.create_process(instructions: sender_instructions)
engine.processes.push(sender)

engine.run
```

### Process Registry

Processes can register themselves with names for easier discovery:

```crystal
# Worker registers itself
VM::Instruction.new(VM::Code::REGISTER_PROCESS, VM::Value.new("my_worker"))

# Another process can look it up
VM::Instruction.new(VM::Code::WHEREIS_PROCESS, VM::Value.new("my_worker"))
# Stack now contains the worker's address
```

### Supervision Trees

Jelly supports Erlang-style supervision for building fault-tolerant applications. Supervisors monitor child processes and restart them according to configurable strategies.

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Create a supervisor
supervisor = engine.create_supervisor(
  strategy: VM::Supervisor::RestartStrategy::OneForOne, # Only restart failed child
  max_restarts: 3,
  restart_window: 5.seconds
)

# Define a child specification
child_specification = VM::Supervisor::Child::Specification.new(
  id: "worker",
  instructions: worker_instructions,
  restart: VM::Supervisor::RestartType::Transient, # Restart only on abnormal exit
  max_restarts: 3,
  restart_window: 5.seconds
)

supervisor.add_child(child_specification)

engine.run
```

**Restart Strategies:**
- `OneForOne` - Only restart the failed process
- `OneForAll` - Restart all children if one fails
- `RestForOne` - Restart the failed process and all processes started after it

**Restart Types:**
- `Permanent` - Always restart
- `Transient` - Restart only on abnormal exit
- `Temporary` - Never restart

### Process Linking and Monitoring

Processes can be linked (bidirectional) or monitored (unidirectional) to receive notifications when other processes exit.

```crystal
# Link two processes (if one dies, the other receives an exit signal)
VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(other_pid.to_i64)),
VM::Instruction.new(VM::Code::LINK),

# Monitor a process (receive DOWN message when it exits)
VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(other_pid.to_i64)),
VM::Instruction.new(VM::Code::MONITOR),

# Enable exit trapping to receive exit signals as messages instead of dying
VM::Instruction.new(VM::Code::PUSH_BOOLEAN, VM::Value.new(true)),
VM::Instruction.new(VM::Code::TRAP_EXIT)
```

## Instruction Reference

### Stack Manipulation

| Instruction | Description | Stack Effect |
|-------------|-------------|--------------|
| `PUSH_INTEGER` | Push integer onto stack | → value |
| `PUSH_FLOAT` | Push float onto stack | → value |
| `PUSH_STRING` | Push string onto stack | → value |
| `PUSH_BOOLEAN` | Push boolean onto stack | → value |
| `PUSH_NULL` | Push null onto stack | → null |
| `POP` | Remove top value | value → |
| `DUPLICATE` | Copy top value | a → a, a |
| `SWAP` | Swap top two values | a, b → b, a |
| `ROT` | Rotate top three | a, b, c → b, c, a |
| `OVER` | Copy second value to top | a, b → a, b, a |

### Arithmetic

| Instruction | Description | Stack Effect |
|-------------|-------------|--------------|
| `ADD` | Add two numbers | a, b → (a+b) |
| `SUBTRACT` | Subtract | a, b → (a-b) |
| `MULTIPLY` | Multiply | a, b → (a*b) |
| `DIVIDE` | Divide | a, b → (a/b) |
| `MODULO` | Modulo | a, b → (a%b) |
| `NEGATE` | Negate | a → (-a) |

### String Operations

| Instruction | Description | Stack Effect |
|-------------|-------------|--------------|
| `STRING_CONCATENATE` | Join strings | a, b → (a+b) |
| `STRING_LENGTH` | Get length | str → length |
| `STRING_SUBSTRING` | Extract substring | str, start, len → substr |
| `STRING_TRIM` | Remove whitespace | str → trimmed |
| `STRING_SPLIT` | Split by delimiter | str, delim → array |
| `STRING_UPPER` | Uppercase | str → upper |
| `STRING_LOWER` | Lowercase | str → lower |
| `STRING_REPLACE` | Replace substring | str, pat, rep → result |
| `STRING_INDEX` | Find substring index | haystack, needle → index |
| `STRING_STARTS_WITH` | Check prefix | str, prefix → bool |
| `STRING_ENDS_WITH` | Check suffix | str, suffix → bool |
| `STRING_CONTAINS` | Check contains | str, needle → bool |
| `CHAR_AT` | Get character at index | str, index → char |
| `CHAR_CODE` | Get char code | str → code |
| `CHAR_FROM_CODE` | Create char from code | code → char |

### Comparisons

| Instruction | Description | Stack Effect |
|-------------|-------------|--------------|
| `LESS_THAN` | Less than | a, b → (a<b) |
| `GREATER_THAN` | Greater than | a, b → (a>b) |
| `LESS_THAN_OR_EQUAL` | Less or equal | a, b → (a<=b) |
| `GREATER_THAN_OR_EQUAL` | Greater or equal | a, b → (a>=b) |
| `EQUAL` | Equal | a, b → (a==b) |
| `NOT_EQUAL` | Not equal | a, b → (a!=b) |

### Logical Operations

| Instruction | Description | Stack Effect |
|-------------|-------------|--------------|
| `AND` | Logical AND | a, b → (a && b) |
| `OR` | Logical OR | a, b → (a \|\| b) |
| `NOT` | Logical NOT | a → (!a) |

### Variables

| Instruction | Description |
|-------------|-------------|
| `LOAD_LOCAL` | Load local variable onto stack |
| `STORE_LOCAL` | Store top of stack to local variable |
| `LOAD_GLOBAL` | Load global variable onto stack |
| `STORE_GLOBAL` | Store top of stack to global variable |

### Flow Control

| Instruction | Description |
|-------------|-------------|
| `JUMP` | Unconditional jump by offset |
| `JUMP_IF` | Jump if top of stack is true |
| `JUMP_UNLESS` | Jump if top of stack is false |
| `CALL` | Call subroutine |
| `RETURN` | Return from subroutine |
| `HALT` | Stop process execution |

### Concurrency

| Instruction | Description |
|-------------|-------------|
| `SPAWN` | Create new process |
| `SPAWN_LINK` | Spawn and link atomically |
| `SPAWN_MONITOR` | Spawn and monitor atomically |
| `SELF` | Push own process address |
| `SEND` | Send message to process |
| `RECEIVE` | Receive any message (blocking) |
| `RECEIVE_SELECT` | Receive matching pattern |
| `RECEIVE_TIMEOUT` | Receive with timeout |
| `SEND_AFTER` | Schedule delayed message |
| `REGISTER_PROCESS` | Register name for process |
| `WHEREIS_PROCESS` | Look up process by name |
| `KILL` | Terminate another process |
| `SLEEP` | Pause execution |

### Fault Tolerance

| Instruction | Description |
|-------------|-------------|
| `LINK` | Link to another process |
| `UNLINK` | Remove link |
| `MONITOR` | Monitor another process |
| `DEMONITOR` | Stop monitoring |
| `TRAP_EXIT` | Enable/disable exit trapping |
| `EXIT` | Send exit signal to process |
| `EXIT_SELF` | Exit current process |
| `IS_ALIVE` | Check if process is alive |
| `PROCESS_INFO` | Get process information |

### Data Structures

**Maps:**
| Instruction | Description |
|-------------|-------------|
| `MAP_NEW` | Create empty map |
| `MAP_GET` | Get value by key |
| `MAP_SET` | Set key-value pair |
| `MAP_DELETE` | Delete key |
| `MAP_KEYS` | Get all keys |
| `MAP_SIZE` | Get number of entries |

**Arrays:**
| Instruction | Description |
|-------------|-------------|
| `ARRAY_NEW` | Create new array |
| `ARRAY_GET` | Get element by index |
| `ARRAY_SET` | Set element at index |
| `ARRAY_PUSH` | Add element to end |
| `ARRAY_POP` | Remove and return last element |
| `ARRAY_LENGTH` | Get array length |

### Exception Handling

| Instruction | Description |
|-------------|-------------|
| `TRY_CATCH` | Begin try block with catch offset |
| `END_TRY` | End try block (no exception) |
| `CATCH` | Exception handler entry point |
| `THROW` | Throw exception |
| `RETHROW` | Rethrow to outer handler |

### Networking

**TCP:**
| Instruction | Description |
|-------------|-------------|
| `TCP_CONNECT` | Connect to host:port |
| `TCP_SEND` | Send data |
| `TCP_RECEIVE` | Receive data |
| `TCP_CLOSE` | Close connection |
| `TCP_LISTEN` | Create server socket bound to host:port |
| `TCP_ACCEPT` | Accept incoming connection |

**UDP:**
| Instruction | Description |
|-------------|-------------|
| `UDP_BIND` | Create and bind UDP socket to host:port |
| `UDP_CONNECT` | Create UDP socket connected to remote host:port |
| `UDP_SEND` | Send data over connected UDP socket |
| `UDP_SEND_TO` | Send data to specific address |
| `UDP_RECEIVE` | Receive data (returns address info and data) |
| `UDP_CLOSE` | Close UDP socket |

**UNIX Sockets:**
| Instruction | Description |
|-------------|-------------|
| `UNIX_CONNECT` | Connect to UNIX domain socket path |
| `UNIX_SEND` | Send data over UNIX socket |
| `UNIX_RECEIVE` | Receive data from UNIX socket |
| `UNIX_CLOSE` | Close UNIX socket |
| `UNIX_LISTEN` | Create UNIX domain server socket |
| `UNIX_ACCEPT` | Accept connection on UNIX server |

**Generic Socket:**
| Instruction | Description |
|-------------|-------------|
| `SOCKET_INFO` | Get socket type and info |
| `SOCKET_CLOSE` | Close any socket type |

### I/O

| Instruction | Description |
|-------------|-------------|
| `PRINT_LINE` | Print value to stdout |
| `READ_LINE` | Read line from stdin |

## Examples

### Factorial Calculator

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Compute factorial of 5 using a loop
instructions = [
  # result = 1 (local 0)
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1_i64)),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),
  
  # n = 5 (local 1)
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(5_i64)),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),
  
  # Loop: while n > 0
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(0_i64)),
  VM::Instruction.new(VM::Code::GREATER_THAN),
  VM::Instruction.new(VM::Code::JUMP_UNLESS, VM::Value.new(9_i64)), # Exit loop
  
  # result = result * n
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::MULTIPLY),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)),
  
  # n = n - 1
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_u64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(1_i64)),
  VM::Instruction.new(VM::Code::SUBTRACT),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)),
  
  # Loop back
  VM::Instruction.new(VM::Code::JUMP, VM::Value.new(-13_i64)),
  
  # Print result
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)
engine.run
```

### HTTP Client (Get Your IP Address)

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

instructions = [
  # Connect to icanhazip.com:80
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("icanhazip.com")),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(80_i64)),
  VM::Instruction.new(VM::Code::TCP_CONNECT),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_i64)), # Store socket
  
  # Send HTTP request
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new(
    "GET / HTTP/1.1\r\nHost: icanhazip.com\r\nConnection: close\r\n\r\n"
  )),
  VM::Instruction.new(VM::Code::TCP_SEND),
  VM::Instruction.new(VM::Code::POP),
  
  # Receive response
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(2048_i64)),
  VM::Instruction.new(VM::Code::TCP_RECEIVE),
  VM::Instruction.new(VM::Code::BINARY_TO_STRING),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_i64)),
  
  # Parse body (skip HTTP headers)
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_i64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("\r\n\r\n")),
  VM::Instruction.new(VM::Code::STRING_INDEX),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(4_i64)),
  VM::Instruction.new(VM::Code::ADD),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(2_i64)),
  
  # Extract and print IP
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(1_i64)),
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(2_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(50_i64)),
  VM::Instruction.new(VM::Code::STRING_SUBSTRING),
  VM::Instruction.new(VM::Code::STRING_TRIM),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  
  # Cleanup
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_i64)),
  VM::Instruction.new(VM::Code::TCP_CLOSE),
  VM::Instruction.new(VM::Code::POP),
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes.push(process)
engine.run
```

### Ping-Pong Between Processes

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Create both processes first to get addresses
pong_process = engine.process_manager.create_process(instructions: [] of VM::Instruction)
engine.processes.push(pong_process)

ping_process = engine.process_manager.create_process(instructions: [] of VM::Instruction)
engine.processes.push(ping_process)

# Build the message to send - include ping's actual address
ping_message = VM::Value.new({
  "from" => VM::Value.new(ping_process.address.to_i64),
  "message"  => VM::Value.new("ping"),
})

# Pong process: receives "ping", sends back "pong"
pong_instructions = [
  # Receive message - will be a map {from: address, message: "ping"}
  VM::Instruction.new(VM::Code::RECEIVE),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(0_u64)), # Store full message

  # Get sender address from message
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("from")),
  VM::Instruction.new(VM::Code::MAP_GET),
  VM::Instruction.new(VM::Code::STORE_LOCAL, VM::Value.new(1_u64)), # Store sender address in local 1

  # Print received message
  VM::Instruction.new(VM::Code::LOAD_LOCAL, VM::Value.new(0_u64)),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("message")),
  VM::Instruction.new(VM::Code::MAP_GET),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Pong received: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send "pong" back to sender using their address
  VM::Instruction.new(VM::Code::SEND, VM::Value.new({ping_process.address, VM::Value.new("pong")})),

  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Pong done!")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:normal)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

# Ping process: sends "ping" to pong, waits for reply
ping_instructions = [
  # Print starting message
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Ping starting...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  # Send message to pong (SEND doesn't push to stack, no POP needed)
  VM::Instruction.new(VM::Code::SEND, VM::Value.new({pong_process.address, ping_message})),

  # Wait for reply
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Ping waiting for reply...")),
  VM::Instruction.new(VM::Code::PRINT_LINE),
  VM::Instruction.new(VM::Code::RECEIVE),
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Ping received: ")),
  VM::Instruction.new(VM::Code::SWAP),
  VM::Instruction.new(VM::Code::STRING_CONCATENATE),
  VM::Instruction.new(VM::Code::PRINT_LINE),

  VM::Instruction.new(VM::Code::PUSH_SYMBOL, VM::Value.new(:normal)),
  VM::Instruction.new(VM::Code::EXIT_SELF),
]

# Set the instructions on the processes
pong_process.instructions = pong_instructions
ping_process.instructions = ping_instructions

engine.run
```

### Supervised worker

```crystal
require "jelly"

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
```

## Configuration

The engine can be configured via the `Configuration` object:

```crystal
engine = VM::Engine.new

engine.configuration.max_stack_size = 1000        # Maximum stack depth
engine.configuration.max_mailbox_size = 10000     # Maximum mailbox messages
engine.configuration.iteration_limit = 1000000    # Max execution iterations
engine.configuration.execution_delay = 0.001      # Delay between iterations
engine.configuration.deadlock_detection = true    # Enable deadlock detection
engine.configuration.enable_message_acks = false  # Message acknowledgments
engine.configuration.auto_reactivate_processes = true
```

## Debugging

### Process Inspection

```crystal
# Get JSON representation of process state
json = engine.inspect_process(process.address)
puts json
# => {"address":1,"state":"ALIVE","counter":5,"stack":["42"],...}
```

### Debugger

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Attach debugger
debugger = engine.attach_debugger do |process, instruction|
  puts "Break: Process <#{process.address}> at #{process.counter}"
  puts "Stack: #{process.stack.map(&.to_s)}"

  print "debug (c/s/q)> "
  case gets.try(&.chomp)
  when "s" then VM::Engine::Debugger::Action::Step
  when "q" then VM::Engine::Debugger::Action::Abort
  else          VM::Engine::Debugger::Action::Continue
  end
end

# Break at instruction 0
debugger.add_breakpoint_at(0_u64)

# Simple program
instructions = [
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(10_i64)),
  VM::Instruction.new(VM::Code::PUSH_INTEGER, VM::Value.new(20_i64)),
  VM::Instruction.new(VM::Code::ADD),
  VM::Instruction.new(VM::Code::PRINT_LINE), # Breakpoint here
  VM::Instruction.new(VM::Code::HALT),
]

process = engine.process_manager.create_process(instructions: instructions)
engine.processes << process
engine.run
```

### Fault Tolerance Statistics

```crystal
stats = engine.fault_tolerance_statistics
puts stats
# => {links: 2, monitors: 1, trapping: 0, supervisors: 1, crash_dumps: 0}
```

## Advanced Topics

### Custom Instruction Handlers

Extend the VM with custom instructions:

```crystal
require "jelly"

alias VM = Jelly::VirtualMachine

engine = VM::Engine.new

# Add custom instruction handler with a block
engine.on_instruction(VM::Code::DUPLICATE) do |process, instruction|
  process.counter += 1
  process.stack.push(VM::Value.new("custom result"))

  VM::Value.new
end

process = engine.process_manager.create_process(instructions: [
  VM::Instruction.new(VM::Code::PUSH_STRING, VM::Value.new("Hello, World!")),
  VM::Instruction.new(VM::Code::DUPLICATE),
  VM::Instruction.new(VM::Code::PRINT_LINE)
])

engine.processes.push(process)

engine.run
```

### Pattern Matching in Receive

Use `RECEIVE_SELECT` to selectively receive messages matching a pattern:

```crystal
# Only receive messages with type: "request"
pattern = VM::Value.new({"type" => VM::Value.new("request")})
VM::Instruction.new(VM::Code::RECEIVE_SELECT, pattern)
```

### Delayed Messages

Schedule messages to be delivered in the future:

```crystal
# Send "timeout" to target process in 5 seconds
tuple = {target_address, VM::Value.new("timeout"), 5.0}
VM::Instruction.new(VM::Code::SEND_AFTER, VM::Value.new(tuple))
```

## Use Cases

- **Distributed Systems Simulation** - Model and test distributed algorithms
- **Educational Tool** - Learn about VMs, concurrency, and fault tolerance
- **Game Scripting** - Lightweight scripting engine with built-in concurrency
- **Protocol Prototyping** - Rapidly prototype network protocols
- **Agent-Based Modeling** - Simulate autonomous agents with message passing

## Contributing

1. Fork it (<https://github.com/grkek/jelly/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Giorgi Kavrelishvili](https://github.com/grkek) - creator and maintainer
