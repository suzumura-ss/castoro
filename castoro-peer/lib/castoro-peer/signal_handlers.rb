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

require 'singleton'
require 'castoro-peer/log'

module Castoro
  module Peer

    class SignalHandler
      include Singleton
      
      def initialize
        Signal.trap('HUP')  { signal_handler_HUP  }
        Signal.trap('INT')  { signal_handler_INT  }
        Signal.trap('QUIT') { signal_handler_QUIT }
        Signal.trap('TERM') { signal_handler_TERM }
        Signal.trap('USR1') { signal_handler_USR1 }
        Signal.trap('USR2') { signal_handler_USR2 }
      end

      def main=( m )
        @m = m
      end

      def deal_with_request  # yield
        Thread.new {  # ConditionVariable.wait fails waking up if the current thread is the same as the one being waiting
          @m.mutex.lock
          yield
          @m.mutex.unlock
          @m.cv.signal
          sleep 0.01
        }
      end

      def shutdown_request
        Log.notice( "Shutdown requested." )
        deal_with_request { @m.shutdown_requested = true }
      end

      def start_request
        Log.notice( "Start requested." )
        deal_with_request { @m.start_requested = true }
      end

      def stop_request
        Log.notice( "Stop requested." )
        deal_with_request { @m.stop_requested = true }
      end

      def reload_request
        Log.notice( "Reload requested." )
        deal_with_request { @m.reload_requested = true }
      end

      def signal_handler_HUP  #  1: Hungup
        reload_request
      end

      def signal_handler_INT  #  2: Interrupt, Ctrl-C
        shutdown_request
      end

      def signal_handler_QUIT  #  3: Quit, Ctrl-|
        shutdown_request
      end

      def signal_handler_TERM  # 15: Terminate, kill process_id
        shutdown_request
      end

      def signal_handler_USR1  # 16: User Signal 1
        stop_request
      end

      def signal_handler_USR2  # 17: User Signal 2
        start_request
      end
    end

  end
end
