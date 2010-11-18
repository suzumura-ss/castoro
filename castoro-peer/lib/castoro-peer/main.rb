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
require 'castoro-peer/signal_handler'
require 'castoro-peer/custom_condition_variable'

require 'castoro-peer/basket'
require 'castoro-peer/manipulator'

module Castoro
  module Peer

    class Main
      include Singleton
      include SignalHandler

      def initialize
        # super should be called in the beginning of subclass method

        @mutex              = Mutex.new
        @cv                 = CustomConditionVariable.new
        @shutdown_requested = false
        @start_requested    = false
        @stop_requested     = false

        @options            = CommandLineOptions.new

        Log.output = nil if @options.run_as_daemon?
        @config = Configurations.new(@options.config_file)

        # refactor renessary.
        Basket.class_variable_set :@@base_dir, @config[:basket_base_dir]
        Csm::Request.class_variable_set :@@configurations, @config

        if ( Process.euid == 0 )
          # Todo: notifies with an understandable error message if effective_user is not set
          pwnam = Etc.getpwnam @config[:effective_user]
          Process.egid = pwnam.gid
          Process.euid = pwnam.uid
        end

        if @options.run_as_daemon?
          Daemon.daemonize
          Daemon.create_pid_file
        end

        # regist signal handlers.
        regist_signal_handler
      end

      def start
        # super should be called in the end of subclass method
        STDOUT.flush
        STDERR.flush

        if @options.run_as_daemon?
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

      end

      def main_loop
        start
        @started = true
        while ( true )
          @mutex.synchronize {
            until ( @shutdown_requested || @start_requested || @stop_requested ) do
              @cv.wait( @mutex )
              sleep 1
            end
            process_request
          }
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

      ##
      # set flags for shutdown request.
      #
      def shutdown_request
        Log.notice "Shutdown requested."
        deal_with_request { @shutdown_requested = true }
      end

      ##
      # set flags for start request.
      #
      def start_request
        Log.notice "Start requested."
        deal_with_request { @start_requested = true }
      end

      ##
      # set flags for stop request.
      #
      def stop_request
        Log.notice "Stop requested."
        deal_with_request { @stop_requested = true }
      end

      private

      def deal_with_request
        # ConditionVariable.wait fails waking up if the current thread is the same as the one being waiting
        Thread.new {
          @mutex.synchronize { yield }
          @cv.signal
          sleep 0.01
        }
      end

    end
  end
end

