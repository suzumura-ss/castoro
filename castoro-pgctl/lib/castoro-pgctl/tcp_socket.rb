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
require 'castoro-pgctl/log'

module Castoro
  module Peer

    class TcpServer
      def initialize addr, port, backlog
        s = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
        s.setsockopt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true
        s.setsockopt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
        s.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
        s.do_not_reverse_lookup = true
        sockaddr = Socket.pack_sockaddr_in port, addr
        s.bind sockaddr
        s.listen backlog
        Log.debug "Listen: #{addr}:#{port}" if $DEBUG
        @listening_socket = s
      end

      def accept
        connected_socket, client_addr = @listening_socket.accept
        # SO_KEEPALIVE is inherited from @listening_socket
        # TCP_NODELAY  is inherited from @listening_socket
        connected_socket.do_not_reverse_lookup = true
        s = TcpSocketDelegator.new connected_socket
        s.peername = client_addr
        Log.debug "Connected from: #{s.addr}:#{s.port}" if $DEBUG
        @connected_socket = s
      end

      def close
        @listening_socket.close
      end
    end


    class TcpClient
      def timed_connect addr, port, timedout
        socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
        socket.setsockopt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
        socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
        socket.do_not_reverse_lookup = true
        sockaddr = Socket.sockaddr_in port, addr

        begin
          socket.connect_nonblock sockaddr
        rescue Errno::EINPROGRESS
          # EINPROGRESS is intentionally ignored.
          # The connection cannot be completed immediately.
          # You can use select(3C) to complete the connection
          # by selecting the socket for writing.
        end

        IO.select nil, [socket], nil, timedout
        errno = socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR).unpack('i')[0]
        unless errno == 0
          # See /usr/include/sys/errno.h
          raise ConnectionRefusedError, "Connection refused or else: errno=#{errno} hostname=#{addr} port=#{port}"
        end

        s = TcpSocketDelegator.new socket

        begin
          # confirm if the connection is established by calling getpeername
          # and find its counter side of port and ip address.
          s.peername = socket.getpeername
        rescue Errno::ENOTCONN => e
          # The socket is not connected.
          raise ConnectionTimedoutError, "Connection timed out: timelimit=#{timedout}s hostname=#{addr} port=#{port}"
        end

        Log.debug "Connected to: #{s.addr}:#{s.port}" if $DEBUG

        # make the socket blocking
        flags = s.fcntl Fcntl::F_GETFL, 0
        flags = flags & ( ~ Fcntl::O_NONBLOCK )  # reset O_NONBLOCK
        s.fcntl Fcntl::F_SETFL, flags

        s.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
        @socket = s
      end
    end


    class TcpSocketDelegator
      MAX_LINE_LENGTH = 4096
      BUFSIZE = 4096

      attr_reader :addr, :port

      def initialize socket
        @socket = socket
        @buffer = nil  # the buffer
        @pos = 0       # current position
      end

      def method_missing m, *args, &block
        @socket.__send__ m, *args, &block
      end

      def peername= sockaddr
        @port, @addr = Socket.unpack_sockaddr_in sockaddr
      end

      def fill_buffer timedout
        if @socket.closed?
          Log.debug "TCP Closed : #{@addr}:#{@port}" if $DEBUG
          return false
        end

        # If the only single Ruby thread is running and Socket::SO_RCVTIMEO 
        # is activated, socket.sysread() works expectedly.
        # sysread(), however, does not expectedly work and it blocks forever
        # if two or more Ruby threads are running under Ruby 1.9.1.
        # Thus, select() must be used here, instead of sysread().
        if timedout
          unless IO.select( [@socket], nil, nil, timedout )
            # timed out
            raise Errno::EAGAIN, "gets timed out: #{timedout}s"
          end
        end

        # sysread() might raise:
        #  Errno::EAGAIN: Resource temporarily unavailable ; meanings timed out
        #  EOFError "end of file reached"
        #  IOError: closed stream
        @buffer = @socket.sysread( BUFSIZE )
        Log.debug "TCP I : #{@addr}:#{@port} #{@buffer}" if $DEBUG

        return (@buffer and 0 < @buffer.length)
      end

      def timed_gets timedout
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

      def gets
        timed_gets nil
      end

      def syswrite data
        Log.debug "TCP O : #{@addr}:#{@port} #{data}" if $DEBUG
        @socket.syswrite data
      end

      def puts data
        @socket.syswrite "#{data}\n"
      end

      def tcp?
        true
      end
    end

  end
end
