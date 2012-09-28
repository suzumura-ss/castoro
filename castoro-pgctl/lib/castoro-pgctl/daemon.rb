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

require 'timeout'
require 'castoro-pgctl/log'

module Castoro
  module Peer

    module Daemon
      WORKING_DIR = '/var/castoro'
      UMASK = 0022
      DURATION_IN_SECOND_KEEPING_EYE_ON_THE_CHILD = 2
      
      def self.daemonize
        Dir.chdir WORKING_DIR
        File.umask UMASK

        @program_name = $0.sub(/.*\//, '')
        print "Starting #{@program_name} ... "

        # Workaround for http://redmine.ruby-lang.org/issues/show/2371
        Log.stop

        pid = Kernel.fork
        if pid
          # Parent
          begin
            Timeout.timeout( DURATION_IN_SECOND_KEEPING_EYE_ON_THE_CHILD ) do
              x_pid, x_status = Process.waitpid2 pid
              status = x_status.exitstatus
              status = 1 if status == 0
              puts "\nStarting #{@program_name} ... FAILED"
              exit status  # The child process has unexpectedly finished
            end
          rescue Timeout::Error
            puts "\nStarting #{@program_name} ... OK"
            exit 0  # The child process has been working
          end
        end

        # Child
        Process.setsid()
        Log.start_again

        program_name = $0.sub( /.*\//, '' )
        file = "#{WORKING_DIR}/#{program_name}.pid"
        File.open( file, 'w' ) do |f|
          pid = Process.pid
          f.puts( pid )
        end

        at_exit do
          begin
            File.delete( file ) if File.exists? file
          rescue
          end
        end
      end

      def self.close_stdio
        STDOUT.flush
        STDERR.flush
        STDIN.reopen '/dev/null'
        STDOUT.reopen '/dev/null', 'w'
        STDERR.reopen STDOUT
      end
    end

  end
end
