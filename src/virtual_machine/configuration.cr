module Jelly
  module VirtualMachine
    class Configuration
      property max_processes : Int32 = 100
      property max_stack_size : Int32 = 1000
      property max_mailbox_size : Int32 = 100
      property max_instructions_per_cycle : Int32 = 10
      property execution_delay : Time::Span = 0.001.seconds
      property deadlock_detection : Bool = true
      property auto_reactivate_processes : Bool = true
      property iteration_limit : Int32 = 10000
      property default_message_ttl : Time::Span = 30.seconds
      property default_receive_timeout : Time::Span = 5.seconds
      property mailbox_full_behavior : Symbol = :block # :block, :drop, :fail
      property enable_message_acknowledgments : Bool = false
      property cleanup_expired_messages : Bool = true
      property message_cleanup_interval : Time::Span = 5.seconds
    end
  end
end
