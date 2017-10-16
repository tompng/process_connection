require 'process_connection'

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

ProcessConnection.start_master

fork do
  ProcessConnection.start do |msg|
    ProcessConnection.broadcast 'pong', response: false if msg == 'ping'
    "A#{msg}"
  end.join
end

fork do
  ProcessConnection.start do |msg|
    ProcessConnection.broadcast 'pong', response: false if msg == 'ping'
    "B#{msg}"
  end.join
end

fork do
  ProcessConnection.start do |msg|
    puts 'pong' if msg == 'pong'
    "C#{msg}"
  end
  def test
    puts ProcessConnection.broadcast('a').sort.join
    puts ProcessConnection.broadcast('b', response: false)
    puts ProcessConnection.broadcast('c', include_self: false).sort.join
    puts ProcessConnection.broadcast('d', include_self: false, response: false)
    puts ProcessConnection.broadcast('e').sort.join
    ProcessConnection.broadcast('ping', response: false)
  end
  sleep 0.1
  test
  sleep 0.2
  test
  sleep 0.2
  test
  sleep 0.1
end

sleep 0.2

fork do
  Thread.new { sleep 0.2; exit }
  ProcessConnection.start do |msg|
    ProcessConnection.broadcast 'pong', response: false if msg == 'ping'
    "D#{msg}"
  end.join
end

sleep 0.4
