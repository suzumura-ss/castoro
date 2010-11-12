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
require 'castoro-peer/pipeline'

module Castoro
  module Peer

    class Scheduler
      def initialize( duration, margin )
        @duration, @margin = duration, margin
        @mutex = Mutex.new
        @sleepers1 = []
        @sleepers2 = []
        @target = Time.new + @duration
        @expired = false
      end

      def check_point
        current = Thread.current
        current.priority = 3
        @mutex.lock
        unless ( @expired )
          rest = @target - Time.new
          if ( rest < 0 )
            @expired = true
          elsif ( @margin <= rest )
            return
          end
        end

        loop do
          t = @sleepers2.shift or break
          begin
            t.wakeup
          rescue ThreadError
          end
        end

        while ( @expired )
          @sleepers1.push( current )
          @mutex.sleep
        end
      ensure
        @mutex.unlock
      end

      def wait
        current = Thread.current
        current.priority = 3
        @mutex.lock
        # Log.notice "#{@sleepers2.size} #{@target} - #{Time.new} = #{"%f" % (@target - Time.new)}"
        if ( 0 < @sleepers2.size )
          @sleepers2.push( current )
          @mutex.sleep
          @sleepers2.delete( current )
        else
          rest = @target - Time.new
          if ( rest < 0 )
            @target = @target + @duration * ( 1 + ( ( 0 - rest ) / @duration ).to_i )
          elsif ( rest < @margin )
            @target = @target + @duration
          else
            @sleepers2.push( current )
            @mutex.sleep( rest )
            @sleepers2.delete( current )
            loop do
              t = @sleepers2.shift or break
              begin
                t.wakeup
              rescue ThreadError
              end
            end
            @target = @target + @duration
          end
          @expired = false

          loop do
            t = @sleepers1.shift or break
            begin
              t.wakeup
            rescue ThreadError
            end
          end
        end
      ensure
        @mutex.unlock
      end
    end

    class MaintenaceServerScheduler < Scheduler
      DURATION = 1
      MARGIN = 0.200

      def initialize
        super( DURATION, MARGIN )
      end
    end

    class MaintenaceServerSingletonScheduler < MaintenaceServerScheduler
      include Singleton
    end
  end
end

################################################################################
__END__


module Castoro
  module Peer

    class Scheduler
      def initialize( duration, margin )
        @duration, @margin = duration, margin
        @mutex = Mutex.new
        @sleepers1 = []
        @sleepers2 = []
        @target = Time.new + @duration
        @expired = false
        p ["@mutex", @mutex]
        p ["@sleepers1", "%08x" % @sleepers1.object_id]
        p ["@sleepers2", "%08x" % @sleepers2.object_id]
      end
    end

    class DebugMessageSingletonPipeline < SingletonPipeline
    end

    class SchedulerForDebugging < Scheduler
      @@START = Time.new

      def check_point
        debug "A enter #{@mutex.locked?}"
        previous_priority = Thread.current.priority
        Thread.current.priority = 3
        @mutex.lock
        debug " B with lock"
        unless ( @expired )
          rest = @target - Time.new
          if ( rest < 0 )
            debug "  C expired #{"%.3f" % (rest)}"
            @expired = true
          elsif ( @margin <= rest )
            debug "   D unlock and return without wait #{"%.3f" % (rest)}"
            return
          end
        end

        debug "    E broadcast"
        loop do
          t = @sleepers2.shift or break
          begin
            debug "     F wakeup #{t}"
            t.wakeup
          rescue ThreadError
          end
        end

        debug "      G loop"
        while ( @expired )
          @sleepers1.push( Thread.current )
          debug "       H sleeping"
          @mutex.sleep
          debug "        I wake up"
        end
        debug "         J unlock"
      ensure
        @mutex.unlock
        Thread.current.priority = previous_priority
        debug "          K return"
      end

      def wait
        debug "               P enter #{@mutex.locked?}"
        previous_priority = Thread.current.priority
        Thread.current.priority = 3
        @mutex.lock
        rest = @target - Time.new
        if ( rest < 0 )
          debug "                Q missed #{rest}"
          @target = @target + @duration * ( 1 + ( ( 0 - rest ) / @duration ).to_i )
        elsif ( rest < @margin )
          debug "                 R within margin #{rest}"
          @target = @target + @duration
        else
          @sleepers2.push( Thread.current )
          debug "                  S sleeping for #{rest}"
          @mutex.sleep( rest )
          debug "                   T wake up #{"%.3f" % (@target - Time.new)}"
          @sleepers2.delete( Thread.current )
          @target = @target + @duration
        end
        @expired = false

        debug "                    U broadcast"
        loop do
          t = @sleepers1.shift or break
          begin
            debug "                     V wakeup #{t}"
            t.wakeup
          rescue ThreadError
          end
        end
        debug "                      W unlock"
      ensure
        @mutex.unlock
        debug "                       X return #{"%.3f" % (@target - @duration - Time.new)}"
        Thread.current.priority = previous_priority
      end

      def debug( message )
        n = Thread.current[:thread_number]
        s = "#{" " * n}#{n}"
        m = "#{"%.3f" % (Time.new - @@START)} #{"%-32s" % s} #{Thread.current} #{message}\n"
        # Don't use puts, print, like that, which causes switching a thread upon 
        # flushing an internal buffer every 8192 bytes.
        # The action of flush involves write() system call in a blocking region and
        # consequently, a current thread would surrender without leasing a lock
        # Use pipe of queue, instead.
        DebugMessageSingletonPipeline.instance.enq m
      end
    end

    #class MaintenaceServerSingletonScheduler < Scheduler
    class MaintenaceServerSingletonScheduler < SchedulerForDebugging
      include Singleton

      DURATION = 1
      MARGIN = 0.200

      def initialize
        super( DURATION, MARGIN )
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      m = MaintenaceServerSingletonScheduler.instance
      30.times { |i|
        Thread.new {
          n = i + 1
          Thread.current[:thread_number] = n
          begin
            loop do
              m.debug "#{" " * n}=> #{n}"
                    m.check_point
              # Thread.current.priority = 0
              t = Time.new
              m.debug "#{" " * n}== #{n}"
              #(1000000 * rand).to_i.times { x = 1 }
              #(500000 * rand).to_i.times { x = 1 }
              (100000 * rand).to_i.times { x = 1 }
              (100000 * rand).to_i.times { x = 1 }
              (100000 * rand).to_i.times { x = 1 }
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              #(100000 * rand).to_i.times { x = 1 } ; Thread.pass
              m.debug "#{" " * n}<= #{n}  #{"%0.3f" % (Time.new - t)}"
              Thread.pass
            end
          rescue => e
            p e
          end
        }
      }

      Thread.new {
        loop do
          message = DebugMessageSingletonPipeline.instance.deq
          print message
        end
      }

      Thread.current[:thread_number] = 0
      loop do
        t = Time.new
        m.wait
        m.debug " ===========================> work starts"
        (10000 * rand).to_i.times { x = 1 }
        m.debug " <=========================== work finishes"
      end
    end
  end
end

__END__

ruby -I ../.. scheduler.rb > z74
grep "work starts" z74 | awk '{print $1 - n, $0; n = $1}' | sort -n | tail
grep "X return" z73 | awk '{print $NF, $0}' | sort -n | head
grep "X return" z73 | awk '{print $NF, $0}' | sort -n | tail


