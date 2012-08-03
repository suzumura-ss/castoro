require 'socket'
require 'thread'

$DEBUG = true

now = Time.new
TARGET1 = now + 3  # in seconds
TARGET2 = now + 4
TARGET3 = now + 7
TARGET4 = now + 10

FREQUENCY = 0.4
SIZE = 1024 * 1024

# In Ruby 1.9.1, STDOUT.puts emits two individual write() system calls, 
# for the body of text and \n, if the text does not end with \n, which 
# might cause context switch between the calls and consequently the results 
# of outputs produced by several threads simultaneously would become mess. 
# To avoid that situation, ensure that the text ends with \n.

def sender name, indent, host, port
  socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
  socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
  sockaddr = Socket.sockaddr_in port, host
  socket.connect sockaddr
  File.open( "/dev/zero", "r" ) do |fd|
    begin
      loop do
        puts "#{" " * indent} #{name}: sending it...\n"
        # After the corresponding receiver thread is killed, write() system call 
        # in IO.copy_stream will continue sending data until the TCP window size 
        # is filled up and then will wait forever.
        IO.copy_stream fd, socket, SIZE
        puts "#{" " * indent} #{name}: sent it.\n"
        sleep FREQUENCY
      end
    rescue Errno::EINTR => e  # Interrupted by Ruby VM because of Process.exit
      puts "#{" " * indent} #{name}: sending a little more...\n"
      # IO.syswrite will be blocked forever at select() internally because the TCP 
      # connection is already filled up and there is no room to write data.
      socket.syswrite "I would like to tell you more.\n"
      puts "#{" " * indent} #{name}: sent the more.\n"
    end
  end
  socket.close
end

def receiver name, indent, host, port
  backlog = 5
  sockaddr = Socket.pack_sockaddr_in port, host
  socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
  socket.setsockopt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true
  socket.setsockopt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
  socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
  socket.do_not_reverse_lookup = true
  socket.bind sockaddr
  socket.listen backlog
  client_socket, client_sockaddr = socket.accept
  File.open( "/dev/null", "w" ) do |fd|
    loop do
      puts "#{" " * indent} #{name}: receiving it...\n"
      IO.copy_stream client_socket, fd, SIZE
      puts "#{" " * indent} #{name}: received it.\n"
      sleep FREQUENCY
    end
  end
  client_socket.close
  socket.close
end

def wait_until target
  loop do
    now = Time.new
    return if target < now
    remain = target - now
    sleep( (0.5 < remain) ? remain/2.0 : remain )
  end
end

def send_and_receive name, indent, myhost, myport, herhost, herport
  wait_until TARGET1
  puts "#{" " * indent} #{name}: Go!\n"

  r = Thread.new { receiver name, indent, myhost, myport }

  wait_until TARGET2
  s = Thread.new { sender name, indent, herhost, herport }

  wait_until TARGET3
  puts "#{" " * indent} #{name}: killing the receiver thread...\n"
  Thread.kill r

#  sleep 1
#  puts "#{" " * indent} #{name}: killing the sender thread...\n"
#  Thread.kill s

  wait_until TARGET4
  puts "#{" " * indent} #{name}: exiting...\n"
end

# NAME, INDENT, HOST, PORT
N1, I1, H1, P1 = 'A',  0, '127.0.0.1', 40000
N2, I2, H2, P2 = 'B', 20, '127.0.0.1', 40001
N3, I3, H3, P3 = 'C', 40, '127.0.0.1', 40002

def main
  # Signal.trap('INT')   { }  # Ctrl-C   - ignore it.
  # Signal.trap('TERM')  { }  # kill pid - ignore it.

  puts "Get ready...\n"
  Process.fork { send_and_receive N1, I1, H1, P1, H2, P2 ; Process.exit 0 }
  Process.fork { send_and_receive N2, I2, H2, P2, H3, P3 ; Process.exit 0 }
  send_and_receive N3, I3, H3, P3, H1, P1
end

main
Process.exit 0 
