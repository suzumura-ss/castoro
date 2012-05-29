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

require 'castoro-groupctl/server_status'
require 'castoro-groupctl/stub'

module Castoro
  module Peer

    module Command
      class Base
        attr_accessor :exception, :error

        def initialize hostname, target
          @hostname, @target = hostname, target
        end

        def call command, args = {}
          @exception, @error = nil, nil
          a = { :target => @target }.merge args
          r = @stub.call command, a
          r.nil? and raise XXX
          if r.has_key? 'error'
            e = r[ 'error' ]
            @error  = "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            raise XXX
          end
          r

          # "Unknown error: #{r.inspect}"
        end
      end

      class Cstartd < Base
        attr_reader :stdout, :stderr

        def initialize hostname, target
          super
          @stub = Stub::Cstartd.new hostname
        end

        def call command, args = {}
          @stdout = nil
          @stderr = nil
          r = super
          @stdout = r[ 'stdout' ] or raise XXX
          @stderr = r[ 'stderr' ] or raise XXX
          r
        end
      end

      class Ps < Cstartd
        attr_reader :header, :alive, :status

        def execute
          @alive = nil
          r = call :PS
          @header = r[ 'header' ] or raise XXX
          @alive = case @stdout.size
                   when 0 ; false
                   when 1 ; true
                   else   ; nil  # more than one process are running
                   end
          @status = case @stdout.size
                    when 0 ; 'stopped'
                    when 1 ; 'running'
                    when nil ;  'unknown'
                    else   ;  'more than 1 daemon processes are running'
                    end
        end
      end

      class StartAndStop < Cstartd
        attr_reader :status, :message

        def execute command
          @status = nil
          @message = nil
          r = call command
          @status = r[ 'status' ] or raise XXX, r.inspect
          "status=#{@status} #{@stdout.join(' ')} #{@stderr.join(' ')}"
        end
      end

      class Start < StartAndStop
        def execute
          m = super :START
          if @status == 0
            if @stdout.find { |x| x.match( /Starting.*NG/ ) } and @stderr.find { |x| x.match( /Errno::EADDRINUSE/ ) }
              @message = "Already started"
            else
              @message = m
            end
          else
            @error = m
          end
        end
      end

      class Stop < StartAndStop
        def execute
          m = super :STOP
          if @status == 0
            if @stdout.find { |x| x.match( /Errno::ECONNREFUSED/ ) }
              @message = "Already stopped"
            else
              @message = m
            end
          else
            if @target == :manipulatord and @status == 1 and @stderr.find { |x| x.match( /PID file not found/ ) }
              @message = "Already stopped"
            else
              @error = m
            end
          end
        end
      end

#      def shutdown
#        issue_command( :cstartd, 'SHUTDOWN', nil )
#      end

      class Cagentd < Base
        def initialize hostname, target
          super
          @stub = Stub::Cagentd.new hostname
        end
      end

      class Status < Cagentd
        attr_reader :mode, :auto, :debug

        def execute
          @mode, @auto, @debug = nil, nil, nil
          return if @target == :manipulatord  # manipulatord does not currently support a STATUS command
          r = call :STATUS
          @mode = r[ 'mode' ]
          @auto = r[ 'auto' ]
          @debug = r[ 'debug' ]
        end
      end

      class Mode < Cagentd
        attr_reader :mode, :message

        def execute mode
          @mode, @message = nil, nil
          return if @target == :manipulatord  # manipulatord does not currently support a MODE command
          r = call( :MODE, { :mode => mode } )
          @mode = r[ 'mode' ]
          f = r[ 'mode_previous' ]  # from
          t = r[ 'mode' ]           # to
          from = f.nil? ? 'unknown' : ServerStatus.status_code_to_s( f )
          to   = t.nil? ? 'unknown' : ServerStatus.status_code_to_s( t )
          if @mode == mode and not ( f.nil? or t.nil? )
            if f == t
              @message = "Mode is already #{to}"
            else
              @message = "Mode has changed from #{from} to #{to}"
            end
          else
            @error = "#{@error} An attempt of changing the mode to #{mode} failed. The current mode is #{to}"
          end
        end

        def ascend_or_descend_mode current_mode, new_mode, &block
          if yield current_mode, new_mode
            execute new_mode
          else
            @mode = current_mode
            @message = "Do nothing since the mode is already #{ServerStatus.status_code_to_s( current_mode )}"
          end
        end

        def ascend_mode current_mode, new_mode
          ascend_or_descend_mode( current_mode, new_mode ) { |c, n| c.nil? || c < n }
        end

        def descend_mode current_mode, new_mode
          ascend_or_descend_mode( current_mode, new_mode ) { |c, n| c.nil? || c > n }
        end
      end

      class Auto < Cagentd
        attr_reader :auto, :message

        def execute auto
          @auto, @message = nil, nil
          return if @target == :manipulatord  # manipulatord does not currently support a AUTO command
          r = call( :AUTO, { :auto => auto } )
          @auto = r[ 'auto' ]
          f = r[ 'auto_previous' ]  # from
          t = r[ 'auto' ]           # to
          from = f.nil? ? 'unknown' : ( f ? 'auto' : 'off' )
          to   = t.nil? ? 'unknown' : ( t ? 'auto' : 'off' )
          if @auto == auto and not ( f.nil? or t.nil? )
            if f == t
              @message = "Autopilot is already #{to}"
            else
              @message = "Autopilot has changed from #{from} to #{to}"
            end
          else
            @error = "#{@error} An attempt of changing the autopilot to #{auto} failed. The current autopilot is #{to}"
          end
        end
      end
    end

  end
end
