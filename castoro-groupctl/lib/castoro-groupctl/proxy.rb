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
require 'socket'
require 'singleton'
require 'castoro-groupctl/channel'
require 'castoro-groupctl/barrier'
require 'castoro-groupctl/tcp_socket'
require 'castoro-groupctl/configurations'
require 'castoro-groupctl/server_status'

module Castoro
  module Peer

    class XBarrier < MasterSlaveBarrier
      include Singleton
    end

    class Proxy
      def initialize hostname, target
        @hostname, @target  = hostname, target
        @response = nil
      end

      def issue_command_to_cstartd command, args, &block
        port = Configurations.instance.cstartd_comm_tcpport
        issue_command port, command, args, &block
      end

      def issue_command_to_cagentd command, args, &block
        port = Configurations.instance.cagentd_comm_tcpport
        issue_command port, command, args, &block
      end

      def issue_command port, command, args, &block
        Thread.new do
          begin
            # port is a Fixnum. thus, there is no need to duplicate it.
            c = command.dup 
            a = args.dup
            @response = nil

            XBarrier.instance.wait

            timelimit = 5
            client = TcpClient.new
            socket = client.timed_connect @hostname, port, timelimit
            channel = TcpClientChannel.new socket
            channel.send_command command, args
            x_command, @response = channel.receive_response
            socket.close

            if block_given?
              result = yield @hostname, @target, @response
            else
              result = [ @hostname, @target, @response ]
            end

            XBarrier.instance.wait( :result => result )
          rescue => e
            XBarrier.instance.wait( :result => e )
          end
        end
      end

      attr_reader :ps_error, :ps_stdout, :ps_header, :ps_running

      def do_ps
        @ps_stdout = nil
        @ps_running = nil
        issue_command_to_cstartd( 'PS', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @ps_error  = "#{e['code']}: #{e['message']}"  # e['backtrace'].join(' ')
          elsif r.has_key? 'stdout'
            @ps_stdout = r[ 'stdout' ]
            @ps_header = r[ 'header' ]
            @ps_running = ( @ps_stdout.size == 1 )
          else
            # "Unknown error: #{r.inspect}"
          end
        end
      end

      attr_reader :status_error, :status_mode, :status_auto, :status_debug

      def do_status
        @status_mode = nil
        @status_auto = nil
        @status_debug = nil
        issue_command_to_cagentd( 'STATUS', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @status_error  = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'mode'
            @status_mode = r[ 'mode' ]
            @status_auto = r[ 'auto' ]
            @status_debug = r[ 'debug' ]
          else
            # 
          end
        end
      end

      attr_reader :start_error, :start_stdout, :start_message

      def do_start
        @start_error = nil
        @start_message = nil
        issue_command_to_cstartd( 'START', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            @start_error = "nil"
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @start_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] != 0
            @start_error = "status=#{r['status']} #{r['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] == 0
            if r[ 'stdout' ].find { |x| x.match( /Starting.*NG/ ) } and r[ 'stderr' ].find { |x| x.match( /Errno::EADDRINUSE/ ) }
              @start_message = "Already started"
            else
              @start_message = "status=#{r['status']} #{r['message']}"
            end
          else
            @start_error = "Unknown error: #{r.inspect}"
          end
        end
      end

      attr_reader :stop_error, :stop_message

      def do_stop
        @stop_error = nil
        @stop_message = nil
        issue_command_to_cstartd( 'STOP', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @stop_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] != 0
            if t == :manipulatord and r[ 'status' ] == 1 and r[ 'stderr' ].find { |x| x.match( /PID file not found/ ) }
              @stop_message = "Already stopped"
            else
              @stop_error = "status=#{r['status']} #{r['message']}"
            end
          elsif r.has_key? 'stdout' and r[ 'stdout' ].find { |x| x.match( /Errno::ECONNREFUSED/ ) }
            @stop_message = "Already stopped"
          elsif r.has_key? 'status' and r[ 'status' ] == 0
            @stop_message = "status=#{r['status']} #{r['message']}"
          else
            @stop_error = "Unknown error: #{r.inspect}"
          end
        end
      end

      def shutdown
        issue_command_to_cstartd( 'SHUTDOWN', nil )
      end

      attr_reader :mode_error, :mode_message

      def do_mode mode
        @mode_error = nil
        @mode_message = nil
        issue_command_to_cagentd( 'MODE', { :target => @target, :mode => mode } ) do |h, t, r|  # hostname, target, response
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
        issue_command_to_cagentd( 'AUTO', { :target => @target, :auto => auto } ) do |h, t, r|  # hostname, target, response
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


    class ManipulatordProxy < Proxy
      def initialize hostname
        super hostname, :manipulatord
      end

      def do_status
        # ManipulatordProxy does not currently support a STATUS command
        Thread.new do
          begin
            XBarrier.instance.wait
            @status_mode = nil
            @status_auto = nil
            @status_debug = nil
            XBarrier.instance.wait
          end
        end
      end

      def dummy_mode mode
        # ManipulatordProxy does not currently support a MODE command
        Thread.new do
          begin
            XBarrier.instance.wait
            @mode_error = nil
            @mode_message = nil
            XBarrier.instance.wait
          end
        end
      end

      def do_mode mode
        dummy_mode mode
      end

      def ascend_mode mode
        dummy_mode mode
      end

      def descend_mode mode
        dummy_mode mode
      end

      def do_auto auto
        # ManipulatordProxy does not currently support a AUTO command
        Thread.new do
          begin
            XBarrier.instance.wait
            @auto_error = nil
            @auto_message = nil
            XBarrier.instance.wait
          end
        end
      end
    end


    class CxxxdProxy < Proxy
    end


    class CmondProxy < CxxxdProxy
      def initialize hostname
        super hostname, :cmond
      end
    end


    class CpeerdProxy < CxxxdProxy
      def initialize hostname
        super hostname, :cpeerd
      end
    end


    class CrepdProxy < CxxxdProxy
      def initialize hostname
        super hostname, :crepd
      end
    end

  end
end