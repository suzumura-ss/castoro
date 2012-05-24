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
#        attr_accessor :exception
        attr_accessor :error
#        attr_reader 

        def initialize hostname, target
          @hostname, @target = hostname, target
        end

        def call command, args = {}
          @error = nil
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

      class Cagentd < Base
        def initialize hostname, target
          super
          @stub = Stub::Cagentd.new hostname
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

      class Ps < Cstartd
        attr_reader :header, :alive

        def execute
          @alive = nil
          r = call :PS
          @header = r[ 'header' ] or raise XXX
          @alive = case @stdout.size
                   when 0 ; false
                   when 1 ; true
                   else   ; nil  # more than one process are running
                   end
        end
      end

#      def shutdown
#        issue_command( :cstartd, 'SHUTDOWN', nil )
#      end

      class Status < Cagentd
        attr_reader :mode, :auto, :debug

        def execute
          @mode, @auto, @debug = nil, nil, nil
          r = call :STATUS
          @mode = r[ 'mode' ]
          @auto = r[ 'auto' ]
          @debug = r[ 'debug' ]
        end
      end

      attr_reader :mode_error, :mode_message

      def do_mode mode
        @mode_error = nil
        @mode_message = nil
        issue_command( :cagentd, 'MODE', { :target => @target, :mode => mode } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @mode_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'mode'
            @status_mode = r[ 'mode' ]
            f = r[ 'mode_previous' ] ? ServerStatus.status_code_to_s( r[ 'mode_previous' ] ) : 'unknown'
            t = r[ 'mode' ] ? ServerStatus.status_code_to_s( r[ 'mode' ] ) : 'unknown'
            @mode_message = "Mode has changed from #{f} to #{t}"
          else
            @mode_error = "Unknown error: #{r.inspect}"
          end
        end
      end

      def ascend_mode mode
        if @status_mode.nil? or @status_mode < mode
          do_mode mode
        else
          Thread.new do
            begin
              XBarrier.instance.wait
              @mode_error = nil
              @mode_message = "Do nothing since the mode is already #{ServerStatus.status_code_to_s( @status_mode )}"
              XBarrier.instance.wait
            end
          end
        end
      end

      def descend_mode mode
        if @status_mode.nil? or mode < @status_mode
          do_mode mode
        else
          Thread.new do
            begin
              XBarrier.instance.wait
              @mode_error = nil
              @mode_message = "Do nothing since the mode is already #{ServerStatus.status_code_to_s( @status_mode )}"
              XBarrier.instance.wait
            end
          end
        end
      end

      attr_reader :auto_error, :auto_message

      def do_auto auto
        @auto_error = nil
        @auto_message = nil
        issue_command( :cagentd, 'AUTO', { :target => @target, :auto => auto } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @auto_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'auto'
            @status_auto = r[ 'auto' ]
            f = r[ 'auto_previous' ].nil? ? 'unknown' : ( r[ 'auto_previous' ] ? 'auto' : 'off' )
            t = r[ 'auto' ].nil? ? 'unknown' : ( r[ 'auto' ] ? 'auto' : 'off' )
            @auto_message = "Autopilot has changed from #{f} to #{t}"
          else
            @auto_error = "Unknown error: #{r.inspect}"
          end
        end
      end
    end

  end
end
