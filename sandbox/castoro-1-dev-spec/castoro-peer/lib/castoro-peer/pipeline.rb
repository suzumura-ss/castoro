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
    # this might not efficiently work with rather than Ruby 1.9.1

    class Pipeline
      def initialize
        @mutex = Mutex.new
        @array = []
        @consumers = []
      end

      def enq( object )
        Thread.current.priority = 3
        @mutex.synchronize {
          @array.push( object )
          begin
            t = @consumers.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
        }
      end

      def deq
        Thread.current.priority = 3
        @mutex.synchronize {
          while ( @array.empty? )
            @consumers.unshift( Thread.current )
            @mutex.sleep
          end
          @array.shift
        }
      end

      def empty?
        Thread.current.priority = 3
        @mutex.synchronize {
          @array.empty?
        }
      end

      def size
        Thread.current.priority = 3
        @mutex.synchronize {
          @array.size
        }
      end

      def dump
        Thread.current.priority = 3
        @mutex.synchronize {
          @array.map { |x| x.inspect }
        }
      end
    end


    class SizedPipeline < Pipeline
      def initialize( max_length )
        super()
        @max_length = max_length
        @producers = []
      end

      def enq( object )
        Thread.current.priority = 3
        @mutex.synchronize {
          while ( @max_length <= @array.size )
            @producers.unshift( Thread.current )
            @mutex.sleep
          end
          @array.push( object )
          begin
            t = @consumers.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
        }
      end

      def deq
        Thread.current.priority = 3
        @mutex.synchronize {
          while ( @array.empty? )
            @consumers.unshift( Thread.current )
            @mutex.sleep
          end
          begin
            t = @producers.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
          @array.shift
        }
      end
    end


    class SingletonPipeline < Pipeline
      include Singleton
    end

  end
end
