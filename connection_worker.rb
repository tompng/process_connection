require 'socket'

module Connections
  def self.start(master_port = Connections.master_port, &block)
    Worker.start master_port, &block
  end

  def self.broadcast *args
    Worker.instance.broadcast *args
  end
end

class Connections::SiblingList
  def initialize(master_port, worker_port, &block)
    @block = block
    Thread.new { run master_port, worker_port }
  end

  def run(master_port, worker_port)
    socket = TCPSocket.new('localhost', master_port)
    socket.puts worker_port
    loop do
      ports = socket.gets.scan(/\d+/).map(&:to_i)
      @block.call ports
    end
  ensure
    exit
  end
end


class Connections::Worker
  def self.start(master_port, &block)
    @worker = new
    Connections::SiblingList.new master_port, @worker.port do |ports|
      @worker.update_siblings ports
    end
    @worker.run_recv_loop(&block)
  end

  def initialize
    @server = TCPServer.new 0
    @mutex = Mutex.new
    @connections = {}
    @recv_queue = Queue.new
    Thread.new { run }
  end

  def port
    @server.local_address.ip_port
  end

  def update_siblings ports
    @mutex.synchronize do
      (ports - @connections.keys).each { |port| add_connection port }
      (@connections.keys - ports).each { |port| remove_connection port }
    end
  end

  def inject_data_from_self(data, response: true)
    if response
      queue = Queue.new
      @recv_queue << [data, '_', queue]
      queue.deq.last
    else
      @recv_queue << data
    end
  end

  def run_recv_loop
    loop do
      message, key, response_queue = @recv_queue.deq
      if key.empty?
        block.call(message)
      else
        response = yield message
        response_queue << [key, response] rescue nil
      end
    end
  end

  def add_connection port
    return if @connections[port]
    send_queue = Queue.new
    @connections[port] = send_queue
    Thread.new do
      socket = TCPSocket.new 'localhost', port
      response_waitings = {}
      waiting_mutex = Mutex.new
      Thread.new do
        while (data = send_queue.deq)
          message, res_queue = data
          if res_queue
            key = rand.to_s
            waiting_mutex.synchronize do
              response_waitings[key] = res_queue
            end
            socket.puts key + '/' + message
          else
            socket.puts '/' + message
          end
        end
      end
      Thread.new do
        begin
          while (data = socket.gets)
            key, message = data.chomp.split '/', 2
            response_queue = waiting_mutex.synchronize do
              response_waitings.delete(key)
            end
            next unless response_queue
            response_queue << message rescue nil
            response_queue.close
          end
        ensure
          send_queue.close
          socket.close
          waiting_mutex.synchronize do
            response_waitings.each_value do |rq|
              rq << nil rescue nil
              rq.close
            end
          end
          @mutex.synchronize { remove_connection port }
        end
      end
    end
  end

  def remove_connection(port)
    return unless @connections[port]
    queue = @connections.delete port
    queue.close
  end

  def self.instance
    @worker
  end

  def broadcast(data, response: true, include_self: true)
    if response
      queues = @mutex.synchronize do
        @connections.values.map do |send_queue|
          response_queue = Queue.new
          send_queue << [data, response_queue]
          response_queue
        end
      end
      response = inject_data_from_self data if include_self
      responses = queues.map(&:deq).compact
      responses.unshift response if include_self
      responses
    else
      size = @mutex.synchronize do
        @connections.each_value do |send_queue|
          send_queue << data rescue nil
        end
        @connections.size
      end
      return size unless include_self
      inject_data_from_self data, response: false
      size + 1
    end
  end

  def run
    Socket.accept_loop(@server) do |socket|
      queue = Queue.new
      Thread.new do
        begin
          while (data = socket.gets)
            key, message = data.chomp.split('/', 2)
            @recv_queue << [message, key, queue]
          end
        ensure
          queue.close
          socket.close
        end
      end
      Thread.new do
        while (data = queue.deq)
          socket.puts data.join('/')
        end
      end
    end
  end

  def update_connections(ports)
    @mutex.synchronize do
      ports.each do |port|
        add_connection port
      end
      (@connections.keys - ports).each do |port|
        remove_connection port
      end
    end
  end
end
