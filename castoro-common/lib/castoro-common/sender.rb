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

require "castoro-common"

require "logger"
require "socket"
require "ipaddr"
require "thread"

module Castoro
  module Sender
    class SenderError < CastoroError; end
    class SenderTimeoutError < SenderError; end

    class Connectable

      attr_reader :target
      
      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #  the logger.
      #
      def initialize logger
        @logger = logger || Logger.new(nil)
        @locker = Mutex.new
      end

      ##
      # Start sender service.
      #
      def start connect_expire
        @locker.synchronize {
          raise SenderError, "sender already started." if alive?

          sock = create_socket
          connect sock, connect_expire
          @socket = sock
          set_sock_opt @socket
        }
      end

      ##
      # Stop sender service.
      #
      def stop
        @locker.synchronize {
          raise SenderError, "sender already stopped." unless alive?

          unset_sock_opt @socket
          @socket.close
          @socket = nil
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?; !!@socket; end

      ##
      # Send packet and get response.
      #
      # === Args
      #
      # +data+::
      #   (Castoro::Protocol::Command) transmitted packet data
      # +expire+::
      #   response timeout(sec).
      #
      def send data, expire
        raise SenderError, "data should be Castoro::Protocol::Command." unless data.kind_of? Protocol::Command
        raise SenderError, "sender service doesn't start." unless alive?
        
        @logger.debug { "sent to #{@target}\n#{data.to_s.chomp}" }
        @socket.write data.to_s

        res = IO.select([@socket], nil, nil, expire) ? @socket.recv(1024) : nil
        return nil unless res
        @logger.debug { "returned\n#{res.to_s.chomp}" }

        res = Protocol.parse(res)
        unless res.kind_of? Protocol::Response
          raise SenderError, "responsed data should be Castoro::Protocol::Response."
        end

        res
      end

      ##
      # Sender packet and get raw packet.
      #
      # === Args
      #
      # +data+::
      #   (Castoro::Protocol::Command) transmitted packet data
      # +expire+::
      #   response timeout(sec).
      #
      # === Example
      #
      #  Castoro::Sender::TCP.start(Logger.new(nil), "127.0.0.1", port, 3.0) { |s|
      #    s.send_and_recv_stream(Castoro::Protocol::Command::Dump.new, 3.0) { |received|
      #      STDOUT.print received
      #    }
      #  }
      #
      def send_and_recv_stream data, expire
        raise SenderError, "data should be Castoro::Protocol::Command." unless data.kind_of? Protocol::Command
        raise SenderError, "sender service doesn't start." unless alive?
        
        @logger.debug { "sent to #{@target}\n#{data.to_s.chomp}" }
        @socket.write data.to_s

        if IO.select([@socket], nil, nil, expire)
          unless (res = @socket.recv(1024)).to_s.length == 0
            yield res

            until (res = @socket.recv(1024)).to_s.length == 0
              yield res
            end
          end
        end

        nil
      end

      private

      ##
      # connect with timeout
      #
      # === Args
      #
      # +sock+::
      #   connectable (unix, tcp) socket instance.
      # +expire+::
      #   connect timeout(sec).
      #
      def connect sock, expire
        begin
          sock.connect_nonblock(@sock_addr)
        rescue Errno::EINPROGRESS
          res = IO.select(nil, [sock], nil, expire)
          raise SenderTimeoutError, "connection timeout." unless res
          begin
            sock.connect_nonblock(@sock_addr)
          rescue Errno::EISCONN # already connected.
          end
        end
      end

      ##
      # When the socket begins,
      # the option can be set by changing the definition of the method.
      #
      def set_sock_opt socket
        socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
      end

      ##
      # When the socket ends,
      # the option can be set by changing the definition of the method.
      #
      def unset_sock_opt socket; end

      ##
      # Create socket resource.
      #
      # The method of making the socket by 
      # changing the definition of the method can be set. 
      #
      def create_socket; nil; end

    end

    class UNIX < Connectable

      def self.start logger, sock_file, connect_expire
        me = TCP.new logger, sock_file
        me.start connect_expire

        if block_given?
          ret = nil
          begin
            ret = yield me
          ensure
            me.stop
          end
          ret
        else
          me
        end
      end

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #  the logger.
      # +sock_file+::
      #  fullpath of UNIX socket file.
      #
      def initialize logger, sock_file
        super logger
        @target = sock_file
        @sock_addr = Socket.pack_sockaddr_un(sock_file)
      end

      def create_socket
        Socket.new(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
      end

    end

    class TCP < Connectable

      def self.start logger, host, port, connect_expire
        me = TCP.new logger, host, port
        me.start connect_expire

        if block_given?
          ret = nil
          begin
            ret = yield me
          ensure
            me.stop
          end
          ret
        else
          me
        end
      end

      attr_reader :host, :port

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +host+::
      #   destination host address.
      # +port+::
      #   destination port number.
      #
      def initialize logger, host, port
        super logger
        @host, @port = host, port
        @target = "#{@host}:#{@port}"
        @sock_addr = Socket.pack_sockaddr_in(port, host)
      end

      def create_socket
        Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      end

    end

    class UDP

      def self.start logger
        me = UDP.new logger
        me.start
        if block_given?
          begin
            yield me
          ensure
            me.stop
          end
        end
      end

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #  the logger.
      #
      def initialize logger
        @logger = logger || Logger.new(nil)
        @locker = Mutex.new
        if block_given?
          start
          begin
            yield self
          ensure
            stop
          end
        end
      end

      ##
      # Start sender service.
      #
      def start
        @locker.synchronize {
          raise SenderError, "sender already started." if alive?
          
          @socket = UDPSocket.new
          set_sock_opt @socket
        }
      end

      ##
      # Stop sender service.
      #
      def stop
        @locker.synchronize {
          raise SenderError, "sender already stopped." unless alive?

          unset_sock_opt @socket
          @socket.close
          @socket = nil
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?; !!@socket; end

      ##
      # Send packet.
      #
      # The transmission packet is pushed to the queue.
      #
      # === Args
      #
      # +header+::
      #   (Castoro::Protocol::Header) udp header data.
      # +data+::
      #   (Castoro::Protocol) transmitted packet data
      # +addr+::
      #   destination address.
      # +port+::
      #   destination port.
      #
      def send header, data, addr, port
        raise SenderError, "header should be Castoro::Protocol::UDPHeader." unless header.kind_of? Protocol::UDPHeader
        raise SenderError, "data should be Castoro::Protocol." unless data.kind_of? Protocol
        raise SenderError, "nil cannot be set to addr." if addr.nil?
        raise SenderError, "nil cannot be set to port." if port.nil?
        raise SenderError, "sender service doesn't start." unless alive?

        @logger.debug { "sent to #{addr}:#{port}\n#{header}#{data}" }
        @socket.send "#{header}#{data}", 0, addr, port
        nil
      end

      private

      ##
      # When the socket begins,
      # the option can be set by changing the definition of the method.
      #
      def set_sock_opt socket; end

      ##
      # When the socket ends,
      # the option can be set by changing the definition of the method.
      #
      def unset_sock_opt socket; end
    end

    ##
    # Class of multicast setting to Castoro::Sender::UDP
    #
    class UDP::Multicast < UDP

      class << self
        alias :start :new
      end

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #  the logger.
      # +port+::
      #  number of destination port.
      # +multicast_addr+::
      #   multicast destination address.
      # +device_addr+::
      #   multicast destination network interface device address.
      #
      def initialize logger, port, multicast_addr, device_addr
        @logger = logger || Logger.new(nil)
        @locker = Mutex.new
        @port = port
        @multicast_addr = multicast_addr
        @device_addr = device_addr
        
        if block_given?
          start
          begin
            yield self
          ensure
            stop
          end
        end
      end

      ##
      # sent multicast packet.
      #
      # === Args
      #
      # +header+::
      #   (Castoro::Protocol::Header) udp header data.
      # +data+::
      #   (Castoro::Protocol) transmitted packet data
      #
      def multicast header, data
        send header, data, @multicast_addr, @port
      end

      private

      def set_sock_opt socket
        socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, IPAddr.new(@device_addr).hton)
      end

      def unset_sock_opt socket; end
    end

    class UDP::Broadcast < UDP

      class << self
        alias :start :new
      end

      def initialize logger, port, broadcast_addr
        @logger = logger || Logger.new(nil)
        @sockaddr = Socket.pack_sockaddr_in(port, broadcast_addr)

        if block_given?
          start
          begin
            yield self
          ensure
            stop
          end
        end
      end

      def broadcast header, data
        send header, data, @sockaddr
      end

      private

      def set_sock_opt socket
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, 1)
      end

      def unset_sock_opt socket; end
    end
  end
end

