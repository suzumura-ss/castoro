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
require "timeout"

module Castoro
  module Sender
    class SenderError < CastoroError; end
    class SenderTimeoutError < SenderError; end

    class TCP
      def self.start logger, host, port, connect_timeout
        me = TCP.new logger, host, port
        me.start connect_timeout

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
      #
      def initialize logger, host, port
        @logger = logger || Logger.new(nil)
        @host   = host
        @port   = port
        @locker = Mutex.new
      end

      ##
      # Start sender service.
      #
      def start connect_timeout
        @locker.synchronize {
          raise SenderError, "sender already started." if alive?

          begin
            @socket = timeout(connect_timeout) { TCPSocket.open(@host, @port) }
          rescue TimeoutError
            raise SenderTimeoutError, "tcp connection timeout."
          end

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
        
        @logger.debug { "sent to #{@host}:#{@port}\r\n#{data}" }
        @socket.write data.to_s

        res =
          begin
            s = IO.select([@socket], nil, nil, expire)
            s ? (s[0][0]).recv(1024) : nil
          rescue TimeoutError
            nil
          end
        return nil unless res
        @logger.debug { "returned\r\n#{res}" }
        
        res = Protocol.parse(res)
        unless res.kind_of? Protocol::Response
          raise SenderError, "responsed data should be Castoro::Protocol::Response."
        end

        res
      end

    private

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

        @logger.debug { "sent to #{addr}:#{port}\r\n#{header}#{data}" }
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

      def self.start logger, port, multicast_addr, device_addr
        me = UDP.new logger, port, multicast_addr, device_addr
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
  end
end
