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
require 'etc'

require 'castoro-peer/configurations'
require 'castoro-peer/command_line_options'
require 'castoro-peer/log'
require 'castoro-peer/daemon'
require 'castoro-peer/signal_handlers'
require 'castoro-peer/custom_condition_variable'

module Castoro
  module Peer

    PROGRAM_VERSION = 'peer-0.2 - 2012-03-29'

    $RUN_AS_DAEMON = true

    # Todo: $FATAL_ERROR_OCCURRED could be reported through a method 
    $FATAL_ERROR_OCCURRED = false
    $VERBOSE = false

    class Main
      include Singleton
      
      attr_accessor :mutex, :cv, :shutdown_requested, :start_requested, :stop_requested, :reload_requested

      def initialize
        # super should be called in the beginning of subclass method

        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
        @shutdown_requested = false
        @start_requested    = false
        @stop_requested     = false
        @reload_requested   = false

        CommandLineOptions.new
        if $RUN_AS_DAEMON
          Log.output = nil
        end
        Configurations.instance

        if ( Process.euid == 0 )
          # Todo: notifies with an understandable error message if effective_user is not set
          pwnam = Etc.getpwnam( Configurations.instance.effective_user )
          Process.egid = pwnam.gid
          Process.euid = pwnam.uid
        end

        if $RUN_AS_DAEMON
          Daemon.daemonize
          Daemon.create_pid_file
        end
        SignalHandler.instance.main = self
      end

      def start
        # super should be called in the end of subclass method
        STDOUT.flush
        STDERR.flush

        if $RUN_AS_DAEMON
          Daemon.close_stdio
        end
        Log.notice( "Started." )

        # Activate set_trace_func() being traced with 
        # pid$target::call_trace_proc:entry of DTrace
        # set_trace_func proc {}

        # Inactivate it
        # set_trace_func nil
      end

      def stop
        # super should be called in the beggining of subclass method
        Log.notice( "Stopping..." )
      end

      def process_request
        if ( @shutdown_requested )
          @shutdown_requested = false
          stop
# Todo: XXX
#          thread_join_all
          Log.notice( "Shutdowned." )
          sleep 0.01
          exit 0
        end

        if ( @stop_requested )
          @stop_requested = false
          if ( @started )
            stop
            @started = false
          else
            Log.notice( "Already stopped." )
          end
        end

        if ( @start_requested )
          @start_requested = false
          if ( @started )
            Log.notice( "Already started." )
          else
            start
            @started = true
          end
        end

        if ( @reload_requested )
          @reload_requested = false
          Log.notice( "Reloading..." )
          if ( @started )
            stop
            sleep 0.1
            Configurations.instance.reload
            sleep 0.1
            start
          else
            Configurations.instance.reload
          end
        end
      end

      def main_loop
        start
        @started = true
        while ( true )
          @mutex.lock
          until ( @shutdown_requested || @start_requested || @stop_requested || @reload_requested ) do
            @cv.wait( @mutex )
            sleep 1
          end
          process_request
          @mutex.unlock
          # sleep 0.01
          sleep 3
        end
      end

      def thread_join_all
        begin
          main = Thread.main
          current = Thread.current
          STDOUT.flush
          sleep 0.01
          a = Thread.list.select { |t| t != main and t != current }
          a.each { |t|
            t.join
          }
          # sleep 0.01
          sleep 3
        end until a.size == 0
      end
    end

  end
end
