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
      def initialize port, addr, backlog
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
      end

      def method_missing m, *args, &block
        @socket.__send__ m, *args, &block
      end

      def peername= sockaddr
        @port, @addr = Socket.unpack_sockaddr_in sockaddr
      end

      def gets
        data = @socket.gets
        if $DEBUG
          if data.nil? or data == '' or @socket.closed?
            Log.debug "TCP Closed : #{@addr}:#{@port}"
          else
            Log.debug "TCP I : #{@addr}:#{@port} #{data}"
          end
        end
        data
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
