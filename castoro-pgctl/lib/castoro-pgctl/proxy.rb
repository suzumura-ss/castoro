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
require 'castoro-pgctl/barrier'
require 'castoro-pgctl/command'
require 'castoro-pgctl/exceptions'

module Castoro
  module Peer

    module Proxy
      class Base
        attr_accessor :flag
        attr_reader :date, :ps, :start, :stop, :status, :mode, :auto, :remains

        def target
          # should be implemented in a subclass
        end

        def initialize hostname
          @hostname = hostname
        end

        def execute command, &block
          Thread.new do
            begin
              Barrier.instance.wait
              yield command
            rescue => e
              command.exception = e
              Exceptions.instance.push e
            ensure
              Barrier.instance.wait
            end
          end
        end

        def do_dummy
          execute( nil ) { |c| }  # do nothing
        end

        def do_date
          @date = Command::GetDate.new @hostname, target
          execute( @date ) { |c| c.execute }
        end

        def do_ps
          @ps = Command::Ps.new @hostname, target
          execute( @ps ) { |c| c.execute }
        end

        def do_start
          @start = Command::Start.new @hostname, target
          execute( @start ) { |c| c.execute }
        end

        def do_stop
          @stop = Command::Stop.new @hostname, target
          execute( @stop ) { |c| c.execute }
        end

        #      def shutdown
        #        @shutdown = Command::Stop.new @hostname, target
        #        execute( @shutdown ) { |c| c.execute }
        #      end

        def do_status
          @status = Command::Status.new @hostname, target
          execute( @status ) { |c| c.execute }
        end

        def do_mode mode
          @mode = Command::Mode.new @hostname, target
          execute( @mode ) { |c| c.execute mode }
        end

        def ascend_mode mode
          @mode = Command::Mode.new @hostname, target
          execute( @mode ) { |c| c.ascend_mode @status.mode, mode }
        end

        def descend_mode mode
          @mode = Command::Mode.new @hostname, target
          execute( @mode ) { |c| c.descend_mode @status.mode, mode }
        end

        def do_auto auto
          @auto = Command::Auto.new @hostname, target
          execute( @auto ) { |c| c.execute auto }
        end

        def do_remains type, threshold
          @remains = {} unless @remains
          @remains[ type ] = Command::Remains.new @hostname, target
          execute( @remains[ type ] ) { |c| c.execute type, threshold }
        end
      end


      class Cxxxd < Base
        def has_mode? ; true ; end
        def has_auto? ; true ; end
      end

      class Cmond < Cxxxd
        def target ; :cmond ; end
      end

      class Cpeerd < Cxxxd
        def target ; :cpeerd ; end
      end

      class Crepd < Cxxxd
        def target ; :crepd ; end
      end

      class Manipulatord < Base
        def has_mode? ; false ; end
        def has_auto? ; false ; end
        def target ; :manipulatord ; end
      end
    end

  end
end
