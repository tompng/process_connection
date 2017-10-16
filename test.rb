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
    "A#{msg}"
    puts msg
  end.join
end

fork do
  ProcessConnection.start do |msg|
    "B#{msg}"
  end.join
end

fork do
  ProcessConnection.start do |msg|
    "C#{msg}"
  end
  def test
    puts ProcessConnection.broadcast('a').sort.join
    puts ProcessConnection.broadcast('b', response: false)
    puts ProcessConnection.broadcast('c', include_self: false).sort.join
    puts ProcessConnection.broadcast('d', include_self: false, response: false)
    puts ProcessConnection.broadcast('e').sort
  end
  sleep 1
  test
  sleep 2
  test
  sleep 2
  test
end

sleep 2

fork do
  Thread.new { sleep 2; exit }
  ProcessConnection.start do |msg|
    "C #{msg}"
  end.join
end

sleep 4
