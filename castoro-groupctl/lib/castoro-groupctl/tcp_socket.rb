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
require 'castoro-groupctl/log'

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


    class TcpSocketDelegator
      attr_reader :addr, :port

      def initialize socket
        @socket = socket
        @buffer = []
      end

      def method_missing m, *args, &block
        @socket.__send__ m, *args, &block
      end

      def peername= sockaddr
        @port, @addr = Socket.unpack_sockaddr_in sockaddr
      end

      def timed_gets timedout
        unless 2 <= @buffer.size and @buffer[1] == "\n"
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

          x = sysread 4096
          # sysread() might raise:
          #  Errno::EAGAIN: Resource temporarily unavailable ; meanings timed out
          #  EOFError "end of file reached"
          #  IOError: closed stream
          Log.debug "TCP I : #{@addr}:#{@port} #{x}" if $DEBUG

          a = x.split /\r?(\n)/
          if 0 < @buffer.size and @buffer[-1] != "\n" and not a[0].nil?
            @buffer[-1] = "#{@buffer[-1]}#{a.shift}"
          end
          @buffer.concat a
        end

        if ( 2 <= @buffer.size and @buffer[1] == "\n" )
          data, linefeed = @buffer.slice!( 0, 2 )
          return data
        end

        # Todo: there might be no "\n" at the end of file.
        Log.debug "TCP Closed : #{@addr}:#{@port}" if $DEBUG
        return nil
      end

      def gets
        timed_gets nil
      end

      def syswrite data
        Log.debug "TCP O : #{@addr}:#{@port} #{data}" if $DEBUG
        @socket.syswrite data
      end

      def tcp?
        true
      end
    end

  end
end
