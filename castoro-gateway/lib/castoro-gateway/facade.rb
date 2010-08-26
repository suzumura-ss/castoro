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

require "castoro-gateway"

require "thread"

module Castoro
  class Gateway
    ##
    # Facade for Client --> Gateway <-- Peer.
    #
    class Facade

      RECV_EXPIRE = 0.5

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +config+::
      #   the Hash of configuration.
      #
      def initialize logger, config
        
        @logger           = logger
        @locker           = Mutex.new
        @recv_locker      = Mutex.new

        @addr             = config["multicast_addr"].to_s
        @device           = config["multicast_device_addr"].to_s
        @mreq             = IPAddr.new(@addr).hton + IPAddr.new(@device).hton
        @gup              = config["gateway"]["unicast_port"].to_i
        @gmp              = config["gateway"]["multicast_port"].to_i
        @gwp              = config["gateway"]["watchdog_port"].to_i
        @watchdog_logging = config["gateway"]["watchdog_logging"]
      end

      ##
      # Start facade service.
      #
      def start
        @locker.synchronize {
          raise "facade already started." if alive?

          @logger.info { "starting facade" }

          @unicast = UDPSocket.new
          @unicast.bind("0.0.0.0", @gup)
          @multicast = UDPSocket.new
          @multicast.bind("0.0.0.0", @gmp)
          @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @mreq)
          @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
          @watchdog = UDPSocket.new
          @watchdog.bind("0.0.0.0", @gwp)
          @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @mreq)
          @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)

          # Thre reception packet is output in the log at #recvfrom.
          audit_sockets = []
          audit_sockets << @unicast
          audit_sockets << @multicast
          audit_sockets << @watchdog if @watchdog_logging
          audit_sockets.each { |s|
            s.instance_variable_set :@logger, @logger
            class << s
              alias :recvfrom_original :recvfrom
              def recvfrom maxlen
                data, sockaddr = recvfrom_original maxlen
                port, ip = sockaddr[1].to_i, sockaddr[3].to_s
                @logger.debug { "#{self.addr[1]} / received data from #{ip}:#{port}\r\n#{data}" }
                [data, sockaddr]
              end
            end
          }
        }
      end

      ##
      # Stop facade service.
      #
      def stop
        @locker.synchronize {
          raise "facade already stopped." unless alive?

          @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @mreq)
          @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @mreq)
          @unicast.close
          @multicast.close
          @watchdog.close
          @unicast = nil
          @multicast = nil
          @watchdog = nil

          @logger.info { "stopped facade" }
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?
        @unicast and !@unicast.closed? and
          @multicast and !@multicast.closed? and
          @watchdog and !@watchdog.closed?
      end

      ##
      # Get packet from UDP socket(s).
      #
      # when expired, nil is returned.
      #
      def recv
        received = @recv_locker.synchronize {
          return nil unless alive?

          sockets = [@unicast, @multicast, @watchdog]
          ret = IO.select(sockets, nil, nil, RECV_EXPIRE)
          return nil unless ret

          readable = ret[0]
          sock = readable[0]
          data, = sock.recvfrom(1024)
          data
        }

        # parse header and data.
        lines = received.split("\r\n")
        h = Protocol::UDPHeader.parse(lines[0])
        d = Protocol.parse(lines[1])

        [h, d]
      end
    end
  end
end
