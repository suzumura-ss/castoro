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

module Castoro
  module Peer
    ##
    # StorageSpaceMonitor
    #
    # The capacity of the disk is regularly observed.
    #
    # === Example
    #
    # <pre>
    # # init.
    # m = Castoro::Peer::StorageSpaceMonitor.new "/expdsk"
    #
    # # start
    # m.start
    #
    # 10.times {
    #   puts m.space_bytes # => The disk free space is displayed.
    #   sleep 3
    # }
    #
    # # stop
    # m.stop 
    # </pre>
    #
    class StorageSpaceMonitor

      # TODO: refactor necessary.
      @@df = RUBY_PLATFORM.include?("solaris") ? "/usr/gnu/bin/df" : "/bin/df"
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
        @locker = Mutex.new
      end

      ##
      # start
      #
      # start monitor service.
      #
      def start
        @locker.synchronize {
          raise 'monitor already started.' if alive?

          # first calculate.
          @space_bytes = calculate_space_bytes

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
        @locker.synchronize {
          raise 'monitor already started.' unless alive?
          
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
        raise 'monitor does not started.' unless alive?

        @space_bytes
      end

      ##
      # alive?
      #
      # Return the state of alive or not alive.
      #
      def alive?; !! @thread; end

      private

      ##
      # monitor_loop
      #
      # It keeps executing the calculation of space
      # every @@monitoring_interval second.
      #
      def monitor_loop
        until Thread.current[:dying]
          @space_bytes = calculate_space_bytes
          sleep @@monitoring_interval
        end
      end

      ##
      # calculate_space_bytes
      #
      # The storage space is calculated.
      # When failing in the calculation, original value is returned.
      #
      def calculate_space_bytes
        orig_space_bytes = @space_bytes
        ret = nil

        # TODO: refactor necessary.
        df_ret = `#{@@df} #{@directory} 2>&1`
        if $? == 0
          df_ret = df_ret.split("\n").last
          if df_ret =~ /^.+(\d+) +(\d+) +(\d+) +(\d+)% +.+$/
            ret = $3.to_i
          end
        end

        ret || orig_space_bytes     
      end
    end
  end
end

