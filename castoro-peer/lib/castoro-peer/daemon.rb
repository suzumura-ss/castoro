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

require 'thread'
require 'timeout'
require 'castoro-peer/log'

module Castoro
  module Peer

    module Daemon
      UMASK = 0022
      WORKING_DIR = '/var/castoro'
      DURATION_IN_SECOND_KEEPING_EYE_ON_THE_CHILD = 1.5
      
      def self.daemonize(dir = WORKING_DIR)
        Dir.chdir(dir)
        File.umask(UMASK)

        @program_name = $0.sub(/.*\//, '')
        print "Starting #{@program_name} ... "

        pid = fork()
        if ( pid )  # parent
          begin
            Timeout.timeout( DURATION_IN_SECOND_KEEPING_EYE_ON_THE_CHILD ) do
              pid, status = Process.waitpid2( pid )
              status = status.exitstatus
              status = 1 if status == 0
              puts "\nStarting #{@program_name} ... NG"
              exit status
            end
          rescue Timeout::Error
            puts "OK"
            exit 0  # The child seems to be working properly
          end
        else  # child
          Process.setsid()
          # this child process continues to work

          # Todo: ...
          Log.start_again
        end
      end

      def self.create_pid_file( pid_file = nil )
        pid = Process.pid()
        program_name = $0.sub(/.*\//, '')
        file = pid_file || "#{WORKING_DIR}/#{program_name}.pid"
        File.open( file, 'w' ) do |f|
          f.puts( pid )
        end
        at_exit {
          begin
            File.delete( file ) if File.exists?( file )
          rescue
          end
        }
      end

      def self.close_stdio
        STDOUT.flush
        STDERR.flush
        STDIN.reopen('/dev/null')
        STDOUT.reopen('/dev/null', 'w')
        STDERR.reopen(STDOUT)
      end
    end

  end
end
