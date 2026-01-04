require "log"
require "json"
require "./virtual_machine/**"

module Jelly
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
