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
require 'castoro-peer/log'

module Castoro
  module Peer

    class PreThreadedTcpServer
      def initialize( port, host, number_of_threads, priority = 0 )
        @number_of_threads = number_of_threads
        @priority = priority
        backlog = (5 <= number_of_threads) ? number_of_threads : 5
        factor = 1
        max_length_of_the_queue = backlog * factor
        sockaddr = Socket.pack_sockaddr_in( port, host )
        @server_socket = Socket.new( Socket::AF_INET, Socket::SOCK_STREAM, 0 )
        @server_socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true )
        @server_socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true )
        @server_socket.setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
        @server_socket.do_not_reverse_lookup = true
        @server_socket.bind( sockaddr )
        @server_socket.listen( backlog )
        @queue = SizedQueue.new( max_length_of_the_queue )
      end

      def start
        t = Thread.new { acceptor }
        # Todo: should revise this line
        t.priority = 3  # RUBY_THREAD_PRIORITY_MAX and _MIN are defined in ruby-1.9.1-p378/thread.c
        @threads = []
        @number_of_threads.times {
          w = Thread.new { worker }
          w.priority = @priority
          @threads << w
        }
      end

      def acceptor
        loop do
          begin
            client_socket, client_sockaddr = @server_socket.accept
            @queue.enq client_socket
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
          begin
            socket = @queue.deq
            return if socket.nil?
            serve(socket)
            socket.close unless socket.closed?
          rescue => e
            Log.warning e
          end
        end
      end

      def stop
        @server_socket.close
        @threads.each { |t| Thread.kill t }
      end

      def graceful_stop
        @server_socket.close
        @threads.each { @queue.enq nil }
        sleep 0.5
        stop
      end

      def serve(socket)
        #  should be implemented in a derived class
      end
    end

  end
end
