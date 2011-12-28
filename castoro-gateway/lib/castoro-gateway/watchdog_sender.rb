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

require 'monitor'
require 'socket'

module Castoro
  class Gateway

    class WatchdogSender

      DEFAULT_OPTIONS = {
        :dest_port => 30109,
        :dest_host => '239.192.254.254',
        :if_addr => IPSocket::getaddress(Socket::gethostname),
      }.freeze

      def initialize logger, repository, island, options = {}
        @logger = logger
        @repository = repository
        @island = island.to_island
        options = options.select { |k,v| DEFAULT_OPTIONS.include?(k) }
        DEFAULT_OPTIONS.merge(options).each { |k,v|
          instance_variable_set "@#{k}", v
        }

        @locker = Monitor.new
        @thread = nil
        @header = Protocol::UDPHeader.new @if_addr, 0
      end

      ##
      # Start watchdog service.
      #
      def start
        @locker.synchronize {
          raise CastoroError, 'watchdog sender already started' if alive?
          @thread = Thread.fork { sender_loop }
        }
      end

      ##
      # Stop watchdog service.
      #
      def stop
        @locker.synchronize {
          raise CastoroError, 'watchdog sender already stopped' unless alive?
          @thread[:dying] = true
          @thread.wakeup rescue nil
          @thread.join
          @thread = nil
        }
      end

      def alive?
        @locker.synchronize { !! @thread }
      end

      private

      def sender_loop
        Sender::UDP::Multicast.new(@logger, @dest_port, @dest_host, @if_addr) { |s|
          until Thread.current[:dying]
            s.multicast @header, island_command
            sleep calculate_interval
          end
        }
      end

      def island_command
        Protocol::Command::Island.new @island, @repository.storables, @repository.capacity
      end

      def calculate_interval
        Random.new.rand(60..300)
      end
    end

  end
end

