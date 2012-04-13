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
require 'castoro-groupctl/command_line_options'
require 'castoro-groupctl/daemon'
require 'castoro-groupctl/log'

module Castoro
  module Peer

    $RUN_AS_DAEMON = true
    $VERBOSE = false

    EFFECTIVE_USER = 'xxx'

    class Main
      include Singleton

      def initialize
        # super should be called in the beginning of subclass method

        CommandLineOptions.new
        Log.output = nil if $RUN_AS_DAEMON

        if Process.euid == 0
          pwnam = Etc.getpwnam EFFECTIVE_USER
          Process.egid = pwnam.gid
          Process.euid = pwnam.uid
        end

        Daemon.daemonize if $RUN_AS_DAEMON
      end

      def start
        # super should be called in the end of subclass method
        STDOUT.flush
        STDERR.flush
        Daemon.close_stdio if $RUN_AS_DAEMON
        Log.notice "Started."

        # Activate set_trace_func() being traced with 
        # pid$target::call_trace_proc:entry of DTrace
        # set_trace_func proc {}

        # Inactivate it
        # set_trace_func nil
      end

      def stop
        # super should be called in the beggining of subclass method
        Log.notice "Stopping..."
      end
    end

  end
end
