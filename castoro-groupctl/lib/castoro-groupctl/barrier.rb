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
require 'singleton'
require 'castoro-groupctl/custom_condition_variable'

module Castoro
  module Peer

    class MasterSlaveBarrier
      def initialize
        @clients = 0  # number of all clients
        @waiting = 0  # number of clients being waiting
        @results = []
        @phase = 0  # 0: waiting for ready;  1: waiting for join
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
      end

      def clients= clients
        @mutex.synchronize do
          @clients = clients
        end
      end

      def wait result
        _wait result, 0
      end

      def timedwait result, duration
        _wait result, duration
      end

      def results
        @mutex.synchronize do
          @results.dup
        end
      end

      def flush
        @mutex.synchronize do
          @results.clear
        end
      end

      private

      def _wait result, duration
        @mutex.synchronize do
          @waiting = @waiting + 1
          @results.push( result ) if @phase == 1
          my_phase = @phase  # Fixnum
          if @clients <= @waiting
            @waiting = 0
            @phase = 1 - @phase  # alter its value between 0 and 1
            @cv.broadcast
          end
          while ( @phase == my_phase ) do
            if 0 == duration
              @cv.wait @mutex
            else
              x = @cv.timedwait @mutex, duration
              return :etimedout if x == :etimedout
            end
            sleep 0.01  # To avoid an out-of-control infinite loop
          end
        end
        nil
      end
    end


    class MasterSlaveBarrierSingleton < MasterSlaveBarrier
      include Singleton
    end

  end
end
