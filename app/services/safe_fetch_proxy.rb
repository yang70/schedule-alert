require "socket"
require "timeout"

# Chrome routes all HTTP(S) traffic through this proxy, including redirects and
# subresources. Resolve, reject private addresses, then connect to the checked IP
# directly so a second DNS lookup cannot rebind the destination.
class SafeFetchProxy
  MAX_CONNECTIONS = 24
  MAX_BYTES = 20.megabytes

  def initialize
    @mutex = Mutex.new
    @connections = {}
    @bytes = 0
  end

  def start
    @server = TCPServer.new("127.0.0.1", 0)
    @acceptor = Thread.new do
      loop do
        client = @server.accept
        @mutex.synchronize do
          if @connections.size >= MAX_CONNECTIONS
            client.close
          else
            @connections[client] = Thread.new(client) { |socket| handle(socket) }
          end
        end
      end
    rescue IOError, Errno::EBADF
      nil
    end
    self
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def stop
    @server&.close
    @acceptor&.join(1)
    connections = @mutex.synchronize { @connections.to_a }
    connections.each { |socket, _thread| socket.close rescue nil }
    connections.each do |_socket, thread|
      thread.join(1)
      thread.kill if thread.alive?
    end
  end

  private

  def handle(client)
    upstream = nil
    Timeout.timeout(60) do
      line = client.gets("\r\n", 8192)
      return unless line
      method, target, protocol = line.strip.split(" ", 3)
      raise PublicUrl::UnsafeUrl, "Invalid proxy request" unless protocol == "HTTP/1.1" || protocol == "HTTP/1.0"
      headers = []
      size = line.bytesize
      loop do
        header = client.gets("\r\n", 8192)
        raise PublicUrl::UnsafeUrl, "Incomplete proxy request" unless header
        size += header.bytesize
        raise PublicUrl::UnsafeUrl, "Oversized proxy request" if size > 32.kilobytes
        break if header == "\r\n"
        headers << header
      end
      destination = method == "CONNECT" ? "https://#{target}" : target
      uri, address = PublicUrl.resolve!(destination)
      upstream = Socket.tcp(address, uri.port, connect_timeout: 5)
      if method == "CONNECT"
        client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
      else
        raise PublicUrl::UnsafeUrl, "Unsupported proxy method" unless %w[GET HEAD POST OPTIONS].include?(method)
        filtered = headers.reject { |header| header.match?(/\A(?:Host|Connection|Proxy-Connection|Proxy-Authorization):/i) }
        upstream.write("#{method} #{uri.request_uri} HTTP/1.1\r\nHost: #{uri.host}:#{uri.port}\r\nConnection: close\r\n#{filtered.join}\r\n")
      end
      relay(client, upstream)
    end
  rescue PublicUrl::UnsafeUrl, Timeout::Error, SystemCallError, IOError, SocketError
    client.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") rescue nil
  ensure
    upstream&.close rescue nil
    client.close rescue nil
    @mutex.synchronize { @connections.delete(client) }
  end

  def relay(client, upstream)
    loop do
      readable = IO.select([ client, upstream ], nil, nil, 15)&.first
      break unless readable
      readable.each do |source|
        data = source.read_nonblock(16.kilobytes, exception: false)
        return if data.nil?
        next if data == :wait_readable
        within_limit = @mutex.synchronize do
          @bytes += data.bytesize
          @bytes <= MAX_BYTES
        end
        raise IOError, "Page transfer limit reached" unless within_limit
        (source == client ? upstream : client).write(data)
      end
    end
  end
end
