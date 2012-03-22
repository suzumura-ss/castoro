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

require "monitor"

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
        @locker           = Monitor.new
        @recv_locker      = Monitor.new

        @gup              = config["gateway_comm_udpport"].to_i
        @gmp              = config["gateway_learning_udpport_multicast"].to_i
        @gwp              = config["gateway_watchdog_udpport_multicast"].to_i
        @watchdog_logging = config["gateway_watchdog_logging"]
        config.is_island_when { @ibp = config["isladn_comm_udpport_broadcast"].to_i }

        ifs                 = Castoro::Utils.network_interfaces
        gateway_device_addr = (ifs[config["gateway_comm_device_multicast"]] || {})[:ip]
        island_device_addr  = (ifs[config["island_comm_device_multicast"]] || {})[:ip]

        @mreqs = []
        config.is_original_or_island_when {
          @mreqs << (IPAddr.new(config["gateway_comm_ipaddr_multicast"]).hton + IPAddr.new(gateway_device_addr).hton)
        }
        config.is_master_when {
          @mreqs << (IPAddr.new(config["master_comm_ipaddr_multicast"]).hton + IPAddr.new(island_device_addr).hton)
        }
        config.is_island_when {
          @mreqs << (IPAddr.new(config["island_comm_ipaddr_multicast"]).hton + IPAddr.new(island_device_addr).hton)
        }
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
          @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
          @watchdog = UDPSocket.new
          @watchdog.bind("0.0.0.0", @gwp)
          @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
          if @ibp
            @island = UDPSocket.new
            @island.bind("0.0.0.0", @ibp)
          end
          @mreqs.each { |mreq|
            @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)
            @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)
          }

          # Thre reception packet is output in the log at #recvfrom.
          audit_sockets = []
          audit_sockets << @unicast
          audit_sockets << @multicast
          audit_sockets << @watchdog if @watchdog_logging
          audit_sockets << @island if @island
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

          @mreqs.each { |mreq|
            @multicast.setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, mreq)
            @watchdog.setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, mreq)
          }
          @unicast.close
          @multicast.close
          @watchdog.close
          @island.close if @island
          @unicast = nil
          @multicast = nil
          @watchdog = nil
          @island = nil

          @logger.info { "stopped facade" }
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?
        @locker.synchronize {
          @unicast and !@unicast.closed? and
            @multicast and !@multicast.closed? and
            @watchdog and !@watchdog.closed?
        }
      end

      ##
      # Get packet from UDP socket(s).
      #
      # when expired, nil is returned.
      #
      def recv
        received = @recv_locker.synchronize {

          return nil unless alive?

          sockets = [@unicast, @multicast, @watchdog].tap { |s| s << @island if @island }
          ret = begin
                  IO.select(sockets, nil, nil, RECV_EXPIRE)
                rescue Errno::EBADF
                  raise if alive?
                  nil
                end

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

