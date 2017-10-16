class Thread
  def self.new &block
    Thread.start do
      begin
        block.call
      rescue => e
        p e
        p e.backtrace
      end
    end
  end
end

require_relative './master'
require_relative './worker'
port = ARGV[0].to_i
if port == 0
  Connections.prepare_master
  p Connections.master_port
  Connections.start_master
else
  Thread.new do
    Connections.start port do |x|
      p "RECV #{x}"
      "#{x} #{$$}"
    end
  end
  require 'pry'
  binding.pry
end
