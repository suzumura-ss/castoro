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

module Castoro
  module Peer

    # This Pipeline is a working alternative to Queue in require 'thread'.
    # Unfortunately, Queue in Ruby 1.9.1 does not work efficiently.

    # Note that this code is tuned for ruby-1.9.1-p378/thread.c and 
    # this might not efficiently work with other than Ruby 1.9.1

    # The code Thread.current.priority = 3 prevents a critical region 
    # from being preempted by the Ruby 1.9.1's tick timer of 10ms.
    # See 
    #  th->slice in rb_thread_priority_set() of thread.c
    #  th->slice in rb_thread_execute_interrupts_rec() of thread.c
    #  RUBY_VM_SET_TIMER_INTERRUPT() in timer_thread_function() of thread.c
    #  timer_thread_function() in thread_timer() of thread_pthread.c
    #  RUBY_VM_CHECK_INTS() in vm_core.h and files that uses the macro

    class Pipeline
      RUBY_THREAD_PRIORITY_MAX = 3  # Defined in thread.c

      def initialize
        @mutex = Mutex.new
        @array = []
        @sleepers = []
      end

      def enq( object )
        previous_priority = Thread.current.priority
        Thread.current.priority = RUBY_THREAD_PRIORITY_MAX
        @mutex.lock
        @array.push( object )
        begin
          t = @sleepers.shift
          t.wakeup if t
        rescue ThreadError
          retry
        end
      ensure
        @mutex.unlock
        Thread.current.priority = previous_priority
      end

      def deq
        previous_priority = Thread.current.priority
        Thread.current.priority = RUBY_THREAD_PRIORITY_MAX
        @mutex.lock
        while ( @array.empty? )
          @sleepers.unshift( Thread.current )
          @mutex.sleep
        end
        return @array.shift
      ensure
        @mutex.unlock
        Thread.current.priority = previous_priority
      end

      def empty?
        previous_priority = Thread.current.priority
        Thread.current.priority = RUBY_THREAD_PRIORITY_MAX
        @mutex.lock
        return @array.empty?
      ensure
        @mutex.unlock
        Thread.current.priority = previous_priority
      end

      def size
        previous_priority = Thread.current.priority
        Thread.current.priority = RUBY_THREAD_PRIORITY_MAX
        @mutex.lock
        return @array.size
      ensure
        @mutex.unlock
        Thread.current.priority = previous_priority
      end

      def dump
        @mutex.synchronize {
          @array.map { |x| x.inspect }
        }
      end
    end


    class SingletonPipeline < Pipeline
      include Singleton
    end

  end
end

