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
require 'thread'
require 'castoro-groupctl/pipeline'
require 'castoro-groupctl/log'

module Castoro
  module Peer

    class PreThreadedTcpServer

      class SocketDelegator
        attr_reader :ip, :port

        def initialize socket
          @socket = socket
        end

        def method_missing(m, *args, &block)
          @socket.__send__(m, *args, &block)
        end

        def client_sockaddr= client_sockaddr
          @port, @ip = Socket.unpack_sockaddr_in( client_sockaddr )
        end
      end

      def initialize( port, host, number_of_threads )
        @number_of_threads = number_of_threads
        factor = 1
        backlog = number_of_threads * factor
        backlog = 5 if backlog < 5
        sockaddr = Socket.pack_sockaddr_in( port, host )
        @server_socket = Socket.new( Socket::AF_INET, Socket::SOCK_STREAM, 0 )
        @server_socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true )
        @server_socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true )
        @server_socket.setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
        @server_socket.do_not_reverse_lookup = true
        @server_socket.bind( sockaddr )
        @server_socket.listen( backlog )
        @queue = SizedPipeline.new( 1 )
        @thread_acceptor = nil
        @thread_workers = []
      end

      def start
        @thread_acceptor = Thread.new {
          acceptor()
        }
        @number_of_threads.times {
          @thread_workers << Thread.new {
            worker()
          }
        }
      end

      def acceptor
        loop do
          Thread.current.priority = 3
          begin
            client_socket, client_sockaddr = @server_socket.accept
            s = SocketDelegator.new client_socket
            s.client_sockaddr = client_sockaddr
            @queue.enq s
          rescue IOError => e
            return if e.message.match( /closed stream/ )
            Log.warning e
          rescue Errno::EBADF => e
            return if e.message.match( /Bad file number/ )
            Log.warning e
          rescue => e
            Log.warning e
          end
        end
      end

      def worker
        loop do
          Thread.current.priority = 3
          begin
            socket = @queue.deq
            return if socket.nil?
            serve( socket )
            socket.close unless socket.closed?
          rescue => e
            Log.warning e
          end
        end
      end

      def serve( socket )
        # should be implemented in a subclass
      end

      def stop
        @server_socket.close unless @server_socket.closed?
        sleep 0.1
        Thread.kill @thread_acceptor if @thread_acceptor.alive?
        @number_of_threads.times { @queue.enq nil }
        # sleep 0.1
        # @thread_workers.each { |t| Thread.kill t if t.alive? }
      end

      def graceful_stop
        Thread.kill @thread_acceptor
        @server_socket.close unless @server_socket.closed?
        @thread_workers.each { @queue.enq nil }
        sleep 0.5
        stop
      end
    end

  end
end
