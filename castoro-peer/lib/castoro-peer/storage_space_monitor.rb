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

require 'sync'

module Castoro #:nodoc:
  module Peer #:nodoc:

    ##
    # The free space computational method of storage is defined.
    #
    module StorageSpaceMeasurable

      private

      ##
      # free space is calculated.
      #
      # === Args
      #
      # +directory+::
      #   disk space base directory.
      #
      def measure_space_bytes directory
        df_ret = `#{measure_command} #{directory} 2>&1`
        if $? == 0
          df_ret = df_ret.split("\n").last
          return $3.to_i if df_ret =~ /^.+(\d+) +(\d+) +(\d+) +(\d+)% +.+$/
        end
        nil
      end

      ##
      # Free space display commandline is returned.
      #
      def measure_command
        @measure_command ||= if RUBY_PLATFORM.include?("solaris")
                               "DF_BLOCK_SIZE=1 /usr/gnu/bin/df"
                             else
                               "DF_BLOCK_SIZE=1 /bin/df"
                             end
      end

    end

    ##
    # StorageSpaceMonitor
    #
    # The capacity of the disk is regularly observed.
    #
    # === Example
    #
    #  # init.
    #  m = Castoro::Peer::StorageSpaceMonitor.new "/expdsk"
    #
    #  # start
    #  m.start
    #
    #  10.times {
    #    puts m.space_bytes # => The disk free space is displayed.
    #    sleep 3
    #  }
    #
    #  # stop
    #  m.stop 
    #
    class StorageSpaceMonitor
      include StorageSpaceMeasurable

      @@monitoring_interval = 60.0

      ##
      # initialize
      #
      # === Args
      #
      # +direcotry+::
      #   disk space base directory.
      #
      def initialize directory
        raise "directory not found - #{directory}" unless File.directory?(directory.to_s)

        @directory = directory.to_s
        @locker = Sync.new
      end

      ##
      # start
      #
      # start monitor service.
      #
      def start
        @locker.synchronize(:EX) {
          raise 'monitor already started.' if alive?

          # first measure.
          @space_bytes = measure_space_bytes(@directory)

          # fork
          @thread = Thread.fork { monitor_loop }
        }
      end

      ##
      # stop
      #
      # stop monitor service.
      #
      def stop
        @locker.synchronize(:EX) {
          raise 'monitor already stopped.' unless alive?
          
          @thread[:dying] = true
          @thread.wakeup rescue nil
          @thread.join
          @thread = nil         
        }
      end

      ##
      # space_bytes
      #
      # Accessor of storage space (bytes)
      #
      def space_bytes
        @locker.synchronize(:SH) {
          raise 'monitor does not started.' unless alive?
          @space_bytes
        }
      end

      ##
      # alive?
      #
      # Return the state of alive or not alive.
      #
      def alive?
        @locker.synchronize(:SH) { !! @thread }
      end

      private

      ##
      # monitor_loop
      #
      # It keeps executing the calculation of space
      # every @@monitoring_interval second.
      #
      def monitor_loop
        until Thread.current[:dying]
          space_bytes = (measure_space_bytes(@directory) || @space_bytes)
          @locker.synchronize(:EX) { @space_bytes = space_bytes }
          sleep @@monitoring_interval
        end
      end

    end
  end
end

