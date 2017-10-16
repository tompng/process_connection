require 'socket'
module ProcessConnection
  def self.start_master
    Master.start
  end

  def self.master_port
    Master.port
  end
end

class ProcessConnection::Master
  def initialize
    @server = ::TCPServer.new 0
  end

  def self.instance
    @instance ||= new
  end

  def self.start
    instance.run
  end

  def self.port
    @instance.port
  end

  def port
    @server.local_address.ip_port
  end

  def run
    workers_queue = Queue.new
    workers = {}
    Thread.new do
      loop do
        port, queue = workers_queue.deq
        if queue
          workers[port] = queue
        else
          workers.delete port
        end
        workers.each do |p, q|
          q << workers.keys - [p] rescue nil
        end
      end
    end
    Thread.new do
      Socket.accept_loop(@server) do |socket|
        Thread.new do
          port = socket.gets.to_i
          queue = Queue.new
          workers_queue << [port, queue]
          begin
            Thread.new do
              socket.gets
              queue.close
            end
            while (ports = queue.deq)
              socket.puts ports.join(',')
            end
          ensure
            workers_queue << [port, nil]
            socket.close
          end
        end
      end
    end
  end
end
