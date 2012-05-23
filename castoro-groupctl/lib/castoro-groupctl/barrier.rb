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
require 'castoro-groupctl/custom_condition_variable'

module Castoro
  module Peer

    class MasterSlaveBarrier
      def initialize
        @clients = 0  # the number of clients that have been registered
        @waiting = 0  # the number of clients that have been waiting
        @phase = 0  # 0: waiting for ready;  1: waiting for join
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
      end

      def clients= clients
        @mutex.synchronize do
          @clients = clients
        end
      end

      def timedwait timelimit
        _wait timelimit
      end

      def wait
        _wait nil
      end

      private

      def _wait timelimit
        @mutex.synchronize do
          @waiting = @waiting + 1
          # p [ :clients, @clients, :waiting, @waiting ]
          my_phase = @phase  # Fixnum
          if @clients <= @waiting
            @waiting = 0
            @phase = 1 - @phase  # alter its value between 0 and 1
            # p [ :broadcast ]
            @cv.broadcast
          end
          while ( @phase == my_phase ) do
            if timelimit.nil?
              @cv.wait @mutex
            else
              t = timelimit - Time.new  # how many seconds left
              if t <= 0  # already expired
                # p [ :already_expired ]
                return :etimedout
              end
              x = @cv.timedwait @mutex, t
              if x == :etimedout  # just expired
                # p [ :just_expired ]
                return :etimedout
              end
            end
            sleep 0.01  # To avoid an out-of-control infinite loop
          end
        end
        nil
      end
    end

  end
end
