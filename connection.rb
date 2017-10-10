class ServerConnections
  class << self
    attr_accessor :instance
  end
  def self.initialize_master
    @instance = ServerConnections.new
    Thread.new { instance.master_run }
  end

  def self.initialize_worker
    instance.initialize_worker
  end

  def self.start(&block)
    instance.start(&block)
  end

  def self.broadcast(data)
    instance.broadcast data
  end

  def initialize
    @master_server ||= TCPServer.new 0
    @master_port ||= @master_server.local_address.ip_port
  end

  def master_run
    workers_queue = Queue.new
    workers = {}
    Thread.new do
      begin
      loop do
        port, queue = workers_queue.deq
        if queue
          workers[port] = queue
        else
          workers.delete port
        end
        workers.each do |p, q|
          q << workers.keys - [p]
        end
      end
      rescue=>e;p e;end
    end
    Socket.accept_loop(@master_server) do |socket|
      Thread.new do
        begin
        port = socket.gets.to_i
        queue = Queue.new
        workers_queue << [port, queue]
        begin
          Thread.new do
            data = socket.gets
            queue.close
          end
          while (ports = queue.deq)
            socket.puts ports.join(',')
          end
          socket.close
        rescue => e
          p e
        ensure
          workers_queue << [port, nil]
        end
        rescue=>e;p e;end
      end
    end
  rescue => e
    p e
  end

  def initialize_worker
    @mutex = Mutex.new
    @connections = {}
    @read_queue = Queue.new
    Thread.new { worker_run }
  end

  def worker_run
    server = TCPServer.new(0)
    p @master_port
    ports_socket = TCPSocket.new('localhost', @master_port)
    ports_socket.puts server.local_address.ip_port
    Thread.new do
      Socket.accept_loop(server) do |socket|
        Thread.new do
          while (data = socket.gets)
            @read_queue << data
          end
          socket.close
        end
      end
    end
    Thread.new do
      begin
        loop do
          ports = ports_socket.gets.scan(/\d+/).map(&:to_i)
          update_connections ports
        end
      rescue => e
        p e
        p e.backtrace
      ensure
        exit
      end
    end
  end

  def add_connection(port)
    return if @connections[port]
    queue = Queue.new
    p [:ADD, port]
    @connections[port] = queue
    Thread.new do
      socket = TCPSocket.new 'localhost', port
      Thread.new do
        begin
          while (data = queue.deq)
            socket.puts data.to_str
          end
        rescue => e
          p e
        ensure
          @mutex.synchronize { remove_connection port }
          socket.close
        end
      end
    end
  end

  def remove_connection(port)
    return unless @connections[port]
    p [:REMOVE, port]
    queue = @connections.delete port
    queue.close
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

  def broadcast(data)
    @mutex.synchronize do
      @connections.each_value do |queue|
        queue << data
      end
    end
  rescue => e
    p e
    p e.backtrace
  end

  def start
    loop do
      yield @read_queue.deq
    end
  end
end
