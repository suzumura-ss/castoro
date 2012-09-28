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
require 'castoro-peer/pipeline'
require 'castoro-peer/log'

module Castoro
  module Peer

    class PreThreadedTcpServer

      class SocketDelegator
        attr_reader :ip, :port

        def initialize socket
          @socket = socket
        end

        def method_missing m, *args, &block
          @socket.__send__ m, *args, &block
        end

        def client_sockaddr= client_sockaddr
          @port, @ip = Socket.unpack_sockaddr_in client_sockaddr
        end
      end

      def initialize port, host, number_of_threads
        @number_of_threads = number_of_threads
        factor = 1
        backlog = number_of_threads * factor
        backlog = 5 if backlog < 5
        sockaddr = Socket.pack_sockaddr_in port, host
        @server_socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
        @server_socket.setsockopt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true
        @server_socket.setsockopt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
        @server_socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
        @server_socket.do_not_reverse_lookup = true
        @server_socket.bind sockaddr
        @server_socket.listen backlog
        @queue = SizedPipeline.new 1
        @thread_acceptor = nil
        @thread_workers = []
        @stop_requested = false
      end

      def start
        @thread_acceptor = Thread.new do
          #RubyTracer.enable
          acceptor
        end
        @number_of_threads.times do
          @thread_workers << Thread.new do
            #RubyTracer.enable
            worker
          end
        end
      end

      def acceptor
        loop do
          break if @stop_requested
          Thread.current.priority = 3
          begin
            client_socket, client_sockaddr = @server_socket.accept  # accept might be interrupted by Thread.kill
            s = SocketDelegator.new client_socket
            s.client_sockaddr = client_sockaddr
            @queue.enq s

          rescue IOError => e
            #p "@stop_requested = #{@stop_requested} in PreThreadedTcpServer"
            return if @stop_requested and e.message.match( /closed stream/ )
            Log.warning e
            sleep 1  # To avoid out of control

          rescue Errno::EBADF => e
            #p "@stop_requested = #{@stop_requested} in PreThreadedTcpServer"
            return if @stop_requested and e.message.match( /Bad file number/ )
            Log.warning e
            sleep 1

          rescue => e
            Log.warning e
            sleep 1

          end
        end

      ensure
        @server_socket.close unless @server_socket.closed?
      end

      def worker
        loop do
          Thread.current.priority = 3
          begin
            socket = @queue.deq
            return if socket.nil?
            serve socket
          rescue => e
            Log.warning e
          ensure
            # socket might be nil or not-yet-defined
            socket.close if socket and not socket.closed?
          end
        end
      end

      def serve socket
        # should be implemented in a subclass
      end

      # it would be better if this method is overridden in a subclass
      def stop_requested= f
        #p "def stop_requested= #{f} in PreThreadedTcpServer"
        @stop_requested = f
      end

      def stop
        #p "def stop in PreThreadedTcpServer"
        Thread.kill @thread_acceptor if @thread_acceptor.alive?
        @thread_workers.each { |t| Thread.kill t }
        sleep 0.1
      end

      def graceful_stop
        #p "def graceful_stop starts in PreThreadedTcpServer"
        self.stop_requested = true
        @server_socket.close unless @server_socket.closed?  # this lets accept abort
        @thread_acceptor.join
        #p "def stop acceptor joined in PreThreadedTcpServer"
        @thread_workers.each { |t| @queue.enq nil }
        # @thread_workers.each { |t| t.join }  some thread cannot stop by themselves due to being blocked in a system call
        #p "def stop workers joined in PreThreadedTcpServer"
        sleep 0.5
        stop
        #p "def graceful_stop ends in PreThreadedTcpServer"
      end
    end

  end
end
