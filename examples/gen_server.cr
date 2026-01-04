require "../src/jelly"

# This is an implementation of an example displayed on the HexDocs web page: https://hexdocs.pm/elixir/genservers.html

# defmodule KV.Bucket do
#   use GenServer

#   @doc """
#   Starts a new bucket.
#   """
#   def start_link(opts) do
#     GenServer.start_link(__MODULE__, %{}, opts)
#   end

#   @doc """
#   Gets a value from the `bucket` by `key`.
#   """
#   def get(bucket, key) do
#     GenServer.call(bucket, {:get, key})
#   end

#   @doc """
#   Puts the `value` for the given `key` in the `bucket`.
#   """
#   def put(bucket, key, value) do
#     GenServer.call(bucket, {:put, key, value})
#   end

#   @doc """
#   Deletes `key` from `bucket`.

#   Returns the current value of `key`, if `key` exists.
#   """
#   def delete(bucket, key) do
#     GenServer.call(bucket, {:delete, key})
#   end

#   ### Callbacks

#   @impl true
#   def init(bucket) do
#     state = %{
#       bucket: bucket
#     }

#     {:ok, state}
#   end

#   @impl true
#   def handle_call({:get, key}, _from, state) do
#     value = get_in(state.bucket[key])
#     {:reply, value, state}
#   end

#   def handle_call({:put, key, value}, _from, state) do
#     state = put_in(state.bucket[key], value)
#     {:reply, :ok, state}
#   end

#   def handle_call({:delete, key}, _from, state) do
#     {value, state} = pop_in(state.bucket[key])
#     {:reply, value, state}
#   end
# end

# KV.Bucket GenServer
# State: local[0] = bucket (map)
#        local[1] = message
#        local[2] = action
#        local[3] = key
#        local[4] = value
#        local[5] = from (caller pid)
#        local[6] = ref
kv_bucket_instructions = [
  # 0: Initialize with empty map
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("KV.Bucket starting...")),
  # 1:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 2: bucket = {}
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_NEW),
  # 3:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)),

  # === MAIN LOOP at 4 ===
  # 4: RECEIVE
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::RECEIVE),
  # 5: Store message
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),

  # 6: Extract action
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),
  # 7:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("action")),
  # 8:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 9:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(2_u64)),

  # 10: Extract key
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),
  # 11:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("key")),
  # 12:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 13:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(3_u64)),

  # 14: Extract from (caller pid)
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),
  # 15:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("from")),
  # 16:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 17:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(5_u64)),

  # 18: Extract ref
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),
  # 19:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("ref")),
  # 20:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 21:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(6_u64)),

  # 22: Check action == "get"
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(2_u64)),
  # 23:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("get")),
  # 24:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::EQUAL),
  # 25: Jump to GET handler at 38. After JUMP_IF, counter=26, need +12 to reach 38
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP_IF, Jelly::VirtualMachine::Value.new(12_i64)),

  # 26: Check action == "put"
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(2_u64)),
  # 27:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("put")),
  # 28:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::EQUAL),
  # 29: Jump to PUT handler at 47. After JUMP_IF, counter=30, need +17 to reach 47
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP_IF, Jelly::VirtualMachine::Value.new(17_i64)),

  # 30: Check action == "delete"
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(2_u64)),
  # 31:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("delete")),
  # 32:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::EQUAL),
  # 33: Jump to DELETE handler at 62. After JUMP_IF, counter=34, need +28 to reach 62
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP_IF, Jelly::VirtualMachine::Value.new(28_i64)),

  # 34: Unknown action - just loop back
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("Unknown action")),
  # 35:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 36: Jump to loop at 4. After JUMP, counter=37, need -33 to reach 4
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP, Jelly::VirtualMachine::Value.new(-33_i64)),

  # Padding to align handlers
  # 37:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_NULL),

  # === GET handler at 38 ===
  # 38: Get value from bucket[key]
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)), # bucket
  # 39:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(3_u64)), # key
  # 40:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 41: Store value in local[4]
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)),
  # 42: Print result
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("GET => ")),
  # 43:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 44:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)),
  # 45:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 46: Jump to loop at 4. After JUMP, counter=47, need -43 to reach 4
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP, Jelly::VirtualMachine::Value.new(-43_i64)),

  # === PUT handler at 47 ===
  # 47: Extract value from message
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(1_u64)),
  # 48:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("value")),
  # 49:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 50:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)),
  # 51: bucket[key] = value → MAP_SET needs [map, key, value] on stack
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)), # bucket
  # 52:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(3_u64)), # key
  # 53:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)), # value
  # 54:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_SET),
  # 55: Store updated bucket
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)),
  # 56: Print confirmation
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("PUT => :ok")),
  # 57:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 58: Print the bucket contents
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)),
  # 59:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 60: Jump to loop at 4. After JUMP, counter=61, need -57 to reach 4
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP, Jelly::VirtualMachine::Value.new(-57_i64)),

  # Padding
  # 61:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_NULL),

  # === DELETE handler at 62 ===
  # 62: Get current value first (to return it)
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)), # bucket
  # 63:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(3_u64)), # key
  # 64:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_GET),
  # 65: Store old value
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)),
  # 66: Delete key from bucket
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)), # bucket
  # 67:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(3_u64)), # key
  # 68:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::MAP_DELETE),
  # 69: Store updated bucket
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::STORE_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)),
  # 70: Print deleted value
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PUSH_STRING, Jelly::VirtualMachine::Value.new("DELETE => ")),
  # 71:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 72:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(4_u64)),
  # 73:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 74: Print bucket state
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::LOAD_LOCAL, Jelly::VirtualMachine::Value.new(0_u64)),
  # 75:
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::PRINT_LINE),
  # 76: Jump to loop at 4. After JUMP, counter=77, need -73 to reach 4
  Jelly::VirtualMachine::Instruction.new(Jelly::VirtualMachine::Code::JUMP, Jelly::VirtualMachine::Value.new(-73_i64)),
]

Log.setup(:none)

engine = Jelly::VirtualMachine::Engine.new

bucket = engine.process_manager.create_process(instructions: kv_bucket_instructions)
engine.processes << bucket

# Helper to create call messages
def make_call(action : String, key : String, value : Jelly::VirtualMachine::Value? = nil, ref : Int64 = 0_i64)
  map = {
    "action" => Jelly::VirtualMachine::Value.new(action),
    "key"    => Jelly::VirtualMachine::Value.new(key),
    "from"   => Jelly::VirtualMachine::Value.new(0_i64),
    "ref"    => Jelly::VirtualMachine::Value.new(ref),
  } of String => Jelly::VirtualMachine::Value

  map["value"] = value if value

  Jelly::VirtualMachine::Message.new(0_u64, Jelly::VirtualMachine::Value.new(map))
end

spawn do
  bucket.mailbox.push(make_call("put", "milk", Jelly::VirtualMachine::Value.new(3_i64), 1_i64))
  bucket.mailbox.push(make_call("put", "eggs", Jelly::VirtualMachine::Value.new(12_i64), 2_i64))
  bucket.mailbox.push(make_call("get", "milk", nil, 3_i64))
  bucket.mailbox.push(make_call("get", "eggs", nil, 4_i64))
  bucket.mailbox.push(make_call("delete", "milk", nil, 5_i64))
  bucket.mailbox.push(make_call("get", "milk", nil, 6_i64))
  bucket.mailbox.push(make_call("get", "eggs", nil, 7_i64))
end

puts "Starting KV.Bucket GenServer (#{bucket.address})"
engine.run
