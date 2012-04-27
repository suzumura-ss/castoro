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
        @clients = 0  # number of all clients
        @waiting = 0  # number of clients being waiting
        @phase = 0  # 0: waiting for ready;  1: waiting for join
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
      end

      def clients= clients
        @mutex.synchronize do
          @clients = clients
        end
      end

      def wait args = nil  # :timelimit
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
            if args and args.has_key? :timelimit
              t = :timelimit - Time.new
              if 0 < t
                x = @cv.timedwait @mutex, t
                return :etimedout if x == :etimedout
              else
                return :etimedout
              end
            else
              @cv.wait @mutex
            end
            sleep 0.01  # To avoid an out-of-control infinite loop
          end
        end
        nil
      end
    end

  end
end
