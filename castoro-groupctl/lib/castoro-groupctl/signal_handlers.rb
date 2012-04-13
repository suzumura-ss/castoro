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
require 'castoro-groupctl/log'

module Castoro
  module Peer

    class SignalHandler
      include Singleton

      attr_accessor :f_reload, :f_shutdown, :f_stop, :f_start

      def initialize
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new

        Signal.trap('HUP')  { r_reload   }   #  1: Hungup
        Signal.trap('INT')  { r_shutdown }   #  2: Interrupt, Ctrl-C
        Signal.trap('QUIT') { r_shutdown }   #  3: Quit, Ctrl-|
        Signal.trap('TERM') { r_shutdown }   # 15: Terminate, kill process_id
        Signal.trap('USR1') { r_stop     }   # 16: User Signal 1
        Signal.trap('USR2') { r_start    }   # 17: User Signal 2
      end
        
      def notify   # :yield:
        # If the interrupted thread is the one that has been waiting for 
        # the ConditionVariable, ConditionVariable.wait fails waking up.
        # So, we need an individual thread to handle that.
        Thread.new do
          @mutex.synchronize do
            yield
          end
          @cv.signal
          sleep 0.01
        end
      end

      def r_reload
        Log.notice "Reload requested."
        notify { @f_reload = true }
      end

      def r_shutdown
        Log.notice "Shutdown requested."
        notify { @f_shutdown = true }
      end

      def r_stop
        Log.notice "Stop requested."
        notify { @f_stop = true }
      end

      def r_start
        Log.notice "Start requested."
        notify { @f_start = true }
      end


      def run main
        @main = main
        @started = true
        loop do
          @mutex.synchronize do
            until ( @f_reload || @f_shutdown || @f_stop || @f_start ) do
              @cv.wait @mutex
              sleep 0.1
            end
            a_reload   if @f_reload
            a_shutdown if @f_shutdown
            a_stop     if @f_stop
            a_start    if @f_start
          end
          sleep 0.1
        end
      end

      def a_reload
        # not implemented
      end

      def a_shutdown
        @f_shutdown = false
        @main.stop
        # Todo: XXX
        #          thread_join_all
        Log.notice( "Shutdowned." )
        sleep 0.01
        exit 0
      end

      def a_stop
        @f_stop = false
        if ( @started )
          @main.stop
          @started = false
        else
          Log.notice( "Already stopped." )
        end
      end

      def a_start
        @start = false
        if ( @started )
          Log.notice( "Already started." )
        else
          @main.start
          @started = true
        end
      end
    end

  end
end
