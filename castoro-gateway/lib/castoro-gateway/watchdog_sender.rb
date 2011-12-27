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

      def initialize logger, options = {}
        @logger = logger
        @locker = Monitor.new
        @thread = nil
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
        until Thread.current[:dying]
          # sender loop...
          sleep calculate_interval
        end
      end

      def calculate_interval
        rand(5 * 60)
      end
    end

  end
end

