#
#   Copyright 2010 Ricoh Company, Ltd.
#
#   This file is part of Castoro.
#
#   Castoro is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Lesser General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Castoro is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public License
#   along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
#

require 'socket'
require 'fcntl'
require 'castoro-peer/errors'

module Castoro
  module Peer

    class ExtendedTCPSocket < Socket
      def initialize
        super(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        @buffer = []
      end
        
      def connect( host, port, timedout )
        sockaddr = Socket.sockaddr_in(port, host)
        begin
          connect_nonblock(sockaddr)
        rescue Errno::EINPROGRESS
          # intended and ignored
        # Other potential exceptions:
        #  Errno::ECONNREFUSED
        #  SocketError
        end

        IO.select(nil, [self], nil, timedout)
        errno = getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR).unpack('i')[0]
        unless (errno == 0)
          # See /usr/include/sys/errno.h
          raise StandardError, "Connection refused or something else: errno=#{errno} #{host}:#{port}"
        end

        begin
          # p Socket.unpack_sockaddr_in( socket.getpeername )
          # => port, host
          getpeername  # to confirm if the connection is established
        rescue Errno::ENOTCONN => e
          raise StandardError, "Connection timed out #{timedout}s: #{host}:#{port}"
        end

        set_blocking
        setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
      end

      def set_blocking
        flags = fcntl(Fcntl::F_GETFL, 0)
        flags = flags & ( ~ Fcntl::O_NONBLOCK )
        fcntl(Fcntl::F_SETFL, flags)
      end

      def set_receive_timed_out( timedout )
        t = Time.at( timedout )
        optval = [t.tv_sec, t.tv_usec].pack('ll')
        setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval)
      end

      def reset_receive_timed_out
        set_receive_timed_out( 0 )
      end

      def gets_with_timed_out( timedout )
#        t = Time.new
#        p [ Thread.current, "A", "#{"%.3fs" % (Time.new - t)}", @buffer ]

        if ( 2 <= @buffer.size and @buffer[1] == "\n" )
          line, lf = @buffer.slice!( 0, 2 )
          return "#{line}#{lf}"
        end

        # sysread() with Socket::SO_RCVTIMEO work when a single Ruby thread runs.
        # It, however, does not work when two or more Ruby threads run.
        # Thus, select() is used here, instead.
        unless ( IO.select([self], nil, nil, timedout) )
          raise Errno::EAGAIN
        end

        x = sysread( 1024 )
        # getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR).unpack('i')[0]

        # x = sysread( 1024 )
        # might raise
        #  Errno::EAGAIN: Resource temporarily unavailable ; meanings timed out
        #  EOFError "end of file reached"
        #  IOError: closed stream

#        p [ Thread.current, "B", "#{"%.3fs" % (Time.new - t)}", x ]

        a = x.split(/\r?(\n)/)

        if ( 0 < @buffer.size and @buffer[-1] != "\n" and not a[0].nil? )
          @buffer[-1] = "#{@buffer[-1]}#{a.shift}"
        end
        @buffer.concat( a )

#        p [ Thread.current, "C", "#{"%.3fs" % (Time.new - t)}", @buffer ]

        if ( 2 <= @buffer.size and @buffer[1] == "\n" )
          line, lf = @buffer.slice!( 0, 2 )
          return "#{line}#{lf}"
        end
        return nil
      end
    end
  end
end

if $0 == __FILE__
  module Castoro
    module Peer

      Thread.new {
        begin
          socket2 = ExtendedTCPSocket.new
          socket2.connect( 'google.com', 80, 3 )
          socket2.set_receive_timed_out( 2 )
          p socket2.gets_with_timed_out( 1 )
          p socket2.gets_with_timed_out( 1 )
        rescue => e
          p e
        end
      }

      socket = ExtendedTCPSocket.new
      # socket.connect_nonblock( "127.0.0.1", 22222, 3 )
      # socket.connect( "127.0.0.1", 22, 3 )
      # socket.connect( '192.168.254.254', 22,3 )
       socket.connect( 'google.com', 80, 3 )
#      socket.set_receive_timed_out( 2 )
      socket.puts("GET / HTTP/1.0")
      socket.puts("")

      p socket.gets_with_timed_out( 2 )
      p socket.gets_with_timed_out( 2 )
#      p socket.sysread( 100 )
#      p socket.sysread( 100 )

      sleep 3
    end
  end
end

__END__

