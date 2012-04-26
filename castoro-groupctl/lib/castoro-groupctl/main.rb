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
require 'castoro-groupctl/custom_condition_variable'
require 'castoro-groupctl/daemon'
require 'castoro-groupctl/log'

module Castoro
  module Peer

    $RUN_AS_DAEMON = true
    $VERBOSE = false

    class Main
      include Singleton

      def initialize
        # super should be called in the beginning of subclass method
      end

      def setup args  # :effective_user
        # super should be called in the beginning of subclass method

        Log.output = nil if $RUN_AS_DAEMON

        effective_user = args[ :effective_user ]
        if effective_user
          pwnam = Etc.getpwnam effective_user
          case Process.euid
          when 0
            Process.egid = pwnam.gid
            Process.euid = pwnam.uid
          when pwnam.uid
            # OK.
          else
            raise StandardError, "You are not the same user as #{effective_user}"
          end
        end

        Daemon.daemonize if $RUN_AS_DAEMON

        @mutex = Mutex.new
        @cv = CustomConditionVariable.new

        Signal.trap('INT')  { shutdown_requested }   #  2: Interrupt, Ctrl-C
        Signal.trap('QUIT') { shutdown_requested }   #  3: Quit, Ctrl-|
        Signal.trap('TERM') { shutdown_requested }   # 15: Terminate, kill process_id
      end

      def start
        # super should be called in the end of subclass method
        STDOUT.flush
        STDERR.flush
        Daemon.close_stdio if $RUN_AS_DAEMON
        Log.notice "Started."
      end

      def stop
        # super should be called in the beggining of subclass method
        Log.notice "Stopping..."
      end

      def shutdown
        stop
        sleep 0.5
        Process.exit 0
      end

      def notify   # :yield:
        # If the interrupted thread is the one that has been waiting for 
        # the ConditionVariable, ConditionVariable.wait fail to wake up.
        # So, we need an individual thread to handle that.
        Thread.new do
          @mutex.synchronize do
            yield
          end
          @cv.signal
        end
      end

      def shutdown_requested
        Log.notice "Shutdown requested."
        notify { @f_shutdown = true }
      end

      def do_shutdown
        Log.notice( "Shutdowned." )
        sleep 0.01
        Process.exit 0
      end

      def main_loop
        loop do
          @mutex.synchronize do
            until( @f_shutdown ) do
              @cv.wait @mutex
              sleep 0.1
            end

            if @f_shutdown
              @f_shutdown = false
              do_shutdown
            end
          end
          sleep 0.1
        end
      end

      def run
        setup
        start
        main_loop
      end
    end

  end
end

__END__

Tracing scripts with Tracer

  require 'tracer'
  Tracer.on
  Tracer.off


Tracing scripts with Dtrace

  Kernel.set_trace_func proc { |eventname, filename, line, id, binding, classname| }
  Kernel.set_trace_func nil

  pid$target::rb_proc_call_with_block:entry
  {
     /* see proc.c */
  }

  pid$target::call_trace_proc:entry
  {
     /* see thread.c */
  }
