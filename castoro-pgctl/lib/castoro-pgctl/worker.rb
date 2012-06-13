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
require 'castoro-pgctl/log'
require 'castoro-pgctl/custom_condition_variable'

module Castoro
  module Peer

    class Worker
      def initialize *argv
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
        @thread = nil
        @limitation_of_exception_count = 3
        @running = false
        @finished = false
        @terminated = false
        @stop_requested = false
      end

      def start *args
        raise StandardError 'This worker has already started. ' if @running
        @running = true
        @terminated = false
        @finished = false
        @thread = Thread.new do
          loop do
            Thread.current.exit if @finished
            Thread.current.priority = 3
            @exception_count = 0

            begin
              serve *args  # Do the actual tasks
            rescue => e
              @exception_count = @exception_count + 1
              Log.err e, "in #{self.class}; exception count: #{@exception_count}"

              #          if @limitation_of_@exception_count <= @exception_count
              #            Log.crit "Beyond the limitation count: #{@limitation_of_exception_count}"
              #            @terminated = true
              #            @cv.signal
              #            Thread.exit
              #          end

              sleep 1.5  # To avoid an out-of-control, infinite loop
            end

            if $DEBUG and Log.output
              STDERR.flush 
              STDOUT.flush
              Log.output.flush
            end

            @cv.signal
          end
        end
      rescue => e
        Log.err e
      end

      def serve *args
        # actual task should be implemented in a subclass
      end

      def stop
        raise StandardError 'This worker has already stopped. ' unless @running
        @stop_requested = true
        sleep 0.01
        if @thread and @thread.alive?

          @mutex.synchronize do
            until finished? do
              break if @terminated
              @cv.wait @mutex
              sleep 1  # cv.wait does not wait: Bug of Ruby: http://redmine.ruby-lang.org/issues/show/3212
            end
          end

          if @thread and @thread.alive?
            Thread::kill @thread
          end
          @thread.join
        end
        @running = false
      rescue => e
        Log.err e
      end

      def stop_requested?
        @stop_requested
      end

      def finished?
        # this method could be implemented in a subclass.
        # @cv.signal is needed to notify that the @finished alters.
        @finished
      end

      def finished
        Thread.new do
          @finished = true
          @cv.broadcast
        end
      end
    end


    class SingletonWorker < Worker
      include Singleton
    end

  end
end
