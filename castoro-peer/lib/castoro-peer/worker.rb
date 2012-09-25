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

require 'castoro-peer/log'
require 'castoro-peer/custom_condition_variable'

module Castoro
  module Peer

    class Worker
      def initialize *argv
        # Please, please do not put any unrelated class in this file 
        # such as @config = Configurations.instance
        # This class is a general class for not only Castoro but also 
        # other application software
        @mutex = Mutex.new
        @cv = CustomConditionVariable.new
        @thread = nil
        @limitation_of_exception_count = 3
        @finished = false
        @stop_requested = false
      end

      def start *args
        exception_count = 0
        @terminated = false
        @finished = false
        @thread = Thread.new do
          loop do
            Thread.current.priority = 3
            calmness = false
#            @mutex.synchronize { @finished = false }
            begin
              self.serve *args
              if $DEBUG and Log.output
                STDERR.flush 
                STDOUT.flush
                Log.output.flush
              end
            rescue => e
              exception_count = exception_count + 1
              s = "in #{self.class}; count: #{exception_count}"
              #              if @limitation_of_exception_count <= exception_count
              #                Log.crit "#{s}: reaching the limitation: #{@limitation_of_exception_count}"
              #                # Todo: this situation should be reported to the manager
              #                @terminated = true
              #                @cv.signal
              #                Thread.exit
              #              else
              Log.err e, s
              #              end
              # calmness = true if exception_count % 10 == 0
              calmness = true
            end
#            @mutex.synchronize { @finished = true }
            @cv.signal
            # Thread.pass
            if calmness
              sleep 1.5  # To avoid an out-of-control infinite loop
              calmness = false
            end
            if @finished
              Thread.current.exit
            end
          end
        end
      end

      def serve *args
        # actual task should be implemented in a subclass
      end

      def restart
        self.graceful_stop
        sleep 0.01
        self.start
      end

      def refresh
      end

      def graceful_stop
        @stop_requested = true
        sleep 0.01
        if @thread and @thread.alive?
          # p [ @thread, @thread.alive? ]
          self.wait_until_finish
          if @thread and @thread.alive?
            Thread::kill @thread
          end
          @thread.join
        end
      end

      def stop_requested?
        @stop_requested
      end

      protected

      def wait_until_finish
        begin
          @mutex.lock
          until self.finish? do
            break if @terminated
            @cv.wait @mutex
            sleep 1  # cv.wait does not wait: Bug of Ruby: http://redmine.ruby-lang.org/issues/show/3212
          end
        ensure
          @mutex.unlock
        end
      end

      def finish?
        # this could be implemented in a subclass
        # or use @finished to indicate the stauts
        # @cv.signal in needed to notice change of condition
        @finished
      end

      def finished
        Thread.new {
          @finished = true
          @cv.broadcast
        }
      end
    end

    class SingletonWorker < Worker
      include Singleton
    end

  end
end


if $0 == __FILE__
  module Castoro
    module Peer

      class SampleSingletonWorker < SingletonWorker
        def initialize
          super
          @count = 0
        end

        def serve
          @count = @count + 1
          # a = 0; b = 1 / a
          sleep 0.7
        end

        def finish?
          5 <= @count
        end

        def restart
          @count = 0
          super
        end
      end

      x = SampleSingletonWorker.instance
      x.start
      x.graceful_stop
      sleep 1
      x.restart
      x.graceful_stop
      
    end
  end
end

__END__

$ ruby -e 'b=Time.new; sleep 0.00001; e=Time.new; p [ (e-b) * 1000 ]'
[10.077387]

$ time ruby -e '100.times { sleep 0.00001 }'
real	0m1.182s
user	0m0.014s
sys	0m0.017s

$ time ruby -e '100.times { sleep 0.0001 }'
real	0m1.184s
user	0m0.016s
sys	0m0.026s

$ time ruby -e '100.times { sleep 0.001 }'
real	0m1.149s
user	0m0.015s
sys	0m0.023s

$ time ruby -e '100.times { sleep 0.01 }'
real	0m1.177s
user	0m0.014s
sys	0m0.051s

$ time ruby -e '100.times { sleep 0.02 }'
real	0m2.172s
user	0m0.016s
sys	0m0.023s
