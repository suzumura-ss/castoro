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

require 'time'
require 'singleton'

module Castoro
  module Peer

########################################################################
# Ticket
########################################################################

    class Ticket
      def fullname; '' ; end
      def nickname; '' ; end

      def initialize( object = nil )
        # Both @creation_time and @creation_time_usec are needed 
        # and they will be referred upon 'peerctl cpeerd dump'
        @creation_time = Time.new
        @creation_time_usec = @creation_time.usec
        @start_time = nil
        @finish_time = nil
        @elapse_times = []
        @stack = []
        @mutex = Mutex.new
        self.push( object ) if object
      end

      def active?
        ! @start_time.nil?
      end

      def mark
        @mutex.synchronize {
          if ( @start_time )
            @elapse_times.push Time.new
          else
            @start_time = Time.new
          end
        }
      end

      def finish
        @mutex.synchronize {
          @finish_time.nil? or raise InternalServerError, "Ticket#finish is called twice: #{self.inspect}"
          t = Time.new
          @elapse_times.push t
          @finish_time = t
        }  
      end

      def duration
        @mutex.synchronize {
          @finish_time - @start_time
        }
      end

      def durations
        @mutex.synchronize {
          last_time = @start_time
          @elapse_times.map { |t|
            x = last_time
            last_time = t
            t - x
          }
        }
      end

      def push( *args )
        @mutex.synchronize { @stack.push( *args ) }
      end

      def pop
        @mutex.synchronize { @stack.pop }
      end

      def pop2
        @mutex.synchronize { @stack.slice!( -2, 2 ) }
      end

      def dump( name = nil )
        if ( name.nil? or name == nickname or name == fullname )
          @mutex.synchronize { self.inspect }
        end
      end
    end

########################################################################
# TicketPool
########################################################################

    class TicketPool
      def fullname; '' ; end
      def nickname; '' ; end

      def initialize
        @tickets = []
        @mutex = Mutex.new
      end

      def create_ticket( ticket_class )
        Thread.current.priority = 3
        ticket = ticket_class.new
        @mutex.synchronize { @tickets << ticket }
        ticket
      end

      def delete( ticket )
        # Todo: calculate the statistics
        Thread.current.priority = 3
        @mutex.synchronize { @tickets.delete ticket }
      end

      def real_size
        Thread.current.priority = 3
        @mutex.synchronize { @tickets.size }
      end

      def size  # size of the active tickets
        Thread.current.priority = 3
        @mutex.synchronize {
          count = 0
          @tickets.each { |t| count = count + 1 if t.active? }
          count
        }
      end

      def dump( name = nil )
        Thread.current.priority = 3
        if ( name.nil? or name == nickname or name == fullname )
          @mutex.synchronize {
            ( @tickets.select { |t| t.active? } ).map { |t| t.dump }
          }
        end
      end
    end


    class SingletonTicketPool < TicketPool
      include Singleton
    end

########################################################################
# End
########################################################################

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      pool = TicketPool.new
      a = pool.create_ticket( Ticket )
      b = pool.create_ticket( Ticket )
      #p pool.delete( a )

      print pool.dump.join("\n") + "\n"
    end
  end
end

