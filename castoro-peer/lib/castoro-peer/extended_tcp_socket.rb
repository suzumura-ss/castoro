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
require 'castoro-peer/log'

module Castoro
  module Peer

    class ExtendedTCPSocket < Socket
      MAX_LINE_LENGTH = 4096
      BUFSIZE = 4096

      attr_reader :port, :ip

      def initialize
        super(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        @buffer = nil  # the buffer
        @pos = 0       # current position
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
          # confirm if the connection is established and find its port and ip address
          @port, @addr = Socket.unpack_sockaddr_in( getpeername )
        rescue Errno::ENOTCONN => e
          raise StandardError, "Connection timed out #{timedout}s: #{host}:#{port}"
        end

        set_blocking
        setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
      end

      def accept
        super
        @port, @ip = Socket.unpack_sockaddr_in( getpeername )
      end

      def set_blocking
        flags = fcntl(Fcntl::F_GETFL, 0)
        flags = flags & ( ~ Fcntl::O_NONBLOCK )
        fcntl(Fcntl::F_SETFL, flags)
      end

      def fill_buffer timedout
        if closed?
          Log.debug "TCP Closed : #{@addr}:#{@port}" if $DEBUG
          return false
        end

        # If the only single Ruby thread is running and Socket::SO_RCVTIMEO 
        # is activated, socket.sysread() works expectedly.
        # sysread(), however, does not expectedly work and it blocks forever
        # if two or more Ruby threads are running under Ruby 1.9.1.
        # Thus, select() must be used here, instead of sysread().
        if timedout
          unless IO.select( [self], nil, nil, timedout )
            # timed out
            raise Errno::EAGAIN, "gets timed out: #{timedout}s"
          end
        end

        # sysread() might raise:
        #  Errno::EAGAIN: Resource temporarily unavailable ; meanings timed out
        #  EOFError "end of file reached"
        #  IOError: closed stream
        @buffer = sysread( BUFSIZE )  # sysread might be interrupted by Thread.kill
        Log.debug "TCP I : #{@addr}:#{@port} #{@buffer}" if $DEBUG

        return (@buffer and 0 < @buffer.length)
      end

      def gets_with_timed_out timedout
        data = nil

        loop do
          unless @buffer
            fill_buffer( timedout ) or return data
            @pos = 0
          end

          n = @buffer.index( "\n", @pos )
          if n
            data = data ? (data + @buffer.slice( @pos..n )) : @buffer.slice( @pos..n )
            MAX_LINE_LENGTH < data.length and raise IOError, "Too long line has been received: #{@addr}:#{@port} #{data}"
            @pos = n + 1
            @buffer = nil if @buffer.length <= @pos
            return data
          else
            data = data ? (data + @buffer) : @buffer
            MAX_LINE_LENGTH < data.length and raise IOError, "Too long line has been received: #{@addr}:#{@port} #{data}"
            @buffer = nil
          end
        end
      end
    end
  end
end

if $0 == __FILE__
  module Castoro
    module Peer

      # ruby -d -I.. extended_tcp_socket.rb 

      HOST = 'google.com'
      PORT = 80

      # socat tcp-listen:8888,fork - &
      #HOST = 'localhost'
      #PORT = 8888

      begin
        socket = ExtendedTCPSocket.new
        # socket.connect_nonblock( "127.0.0.1", 22222, 3 )
        # socket.connect( "127.0.0.1", 22, 3 )
        # socket.connect( '192.168.254.254', 22,3 )
        socket.connect( HOST, PORT, 3 )
        socket.syswrite("GET / HTTP/1.0\r\n")
        socket.syswrite("\r\n")
        i = 0
        loop do
          x = socket.gets_with_timed_out( 2 )
          if x
            p [i, x]
            i = i + 1
          else
            break
          end
        end
        #p socket.sysread( 100 )
      rescue => e
        p [e, e.message, e.backtrace]
      end
      sleep 3
    end
  end
end

__END__

