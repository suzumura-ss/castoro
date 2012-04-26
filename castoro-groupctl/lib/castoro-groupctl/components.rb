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

      def do_ps options
        @ps_stdout = nil
        @ps_running = nil
        issue_command_to_cstartd( 'PS', { :target => @target, :options => options } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            @ps_error  = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'stdout'
            @ps_stdout = r[ 'stdout' ]
            @ps_header = r[ 'header' ]
            @ps_running = ( @ps_stdout.size == 1 )
            Success.new h, t, r[ 'stdout' ]
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
          end
        end
      end

      attr_reader :status_error, :status_mode, :status_auto, :status_debug

      def do_status options
        @status_mode = nil
        @status_auto = nil
        @status_debug = nil
        issue_command_to_cagentd( 'STATUS', { :target => @target, :options => options } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            @status_error  = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'mode'
            @status_mode = r[ 'mode' ]
            @status_auto = r[ 'auto' ]
            @status_debug = r[ 'debug' ]
            Success.new h, t, r[ 'mode' ]  # Todo: maybe, Success and Failure are not needed any longer
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
          end
        end
      end

      attr_reader :start_error, :start_stdout, :start_message

      def do_start
        @start_error = nil
        @start_message = nil
        issue_command_to_cstartd( 'START', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
            @start_error = "nil"
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']} #{e['message']} #{e['backtrace'].join(' ')}"
            @start_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] != 0
            Failure.new h, t, "status=#{r['status']} #{r['message']}"
            @start_error = "status=#{r['status']} #{r['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] == 0
            if r[ 'stdout' ].find { |x| x.match( /Starting.*NG/ ) } and r[ 'stderr' ].find { |x| x.match( /Errno::EADDRINUSE/ ) }
              Success.new h, t, "Already started"
              @start_message = "Already started"
            else
              Success.new h, t, "status=#{r['status']} #{r['message']}"
              @start_message = "status=#{r['status']} #{r['message']}"
            end
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
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
            Failure.new h, t, nil
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']} #{e['message']} #{e['backtrace'].join(' ')}"
            @stop_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'status' and r[ 'status' ] != 0
            if t == :manipulatord and r[ 'status' ] == 1 and r[ 'stderr' ].find { |x| x.match( /PID file not found/ ) }
              Success.new h, t, "Already stopped"
              @stop_message = "Already stopped"
            else
              Failure.new h, t, "status=#{r['status']} #{r['message']}"
              @stop_error = "status=#{r['status']} #{r['message']}"
            end
          elsif r.has_key? 'stdout' and r[ 'stdout' ].find { |x| x.match( /Errno::ECONNREFUSED/ ) }
            Success.new h, t, "Already stopped"
            @stop_message = "Already stopped"
          elsif r.has_key? 'status' and r[ 'status' ] == 0
            Success.new h, t, "status=#{r['status']} #{r['message']}"
            @stop_message = "status=#{r['status']} #{r['message']}"
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
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
            Failure.new h, t, nil
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            @mode_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'mode'
            @status_mode = r[ 'mode' ]
            f = r[ 'mode_previous' ] ? ServerStatus.status_code_to_s( r[ 'mode_previous' ] ) : 'unknown'
            t = r[ 'mode' ] ? ServerStatus.status_code_to_s( r[ 'mode' ] ) : 'unknown'
            @mode_message = "Mode has changed from #{f} to #{t}"
            Success.new h, t, r[ 'mode' ]  # Todo: maybe, Success and Failure are not needed any longer
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
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
              XBarrier.instance.wait( :result => nil )
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
              XBarrier.instance.wait( :result => nil )
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
            Failure.new h, t, nil
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            @auto_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'auto'
            @status_auto = r[ 'auto' ]
            f = r[ 'auto_previous' ].nil? ? 'unknown' : ( r[ 'auto_previous' ] ? 'auto' : 'off' )
            t = r[ 'auto' ].nil? ? 'unknown' : ( r[ 'auto' ] ? 'auto' : 'off' )
            @auto_message = "Autopilot has changed from #{f} to #{t}"
            Success.new h, t, r[ 'auto' ]  # Todo: maybe, Success and Failure are not needed any longer
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
            @auto_error = "Unknown error: #{r.inspect}"
          end
        end
      end

    end

    class ResultStatus
      attr_reader :hostname, :target, :message

      def initialize hostname, target, message
        @hostname, @target, @message = hostname, target, message
      end
    end

    class Success < ResultStatus
    end

    class Failure < ResultStatus
      attr_reader :backtrace

      def initialize hostname, target, message, backtrace = nil
        super hostname, target, message
        @backtrace = backtrace
      end
    end

    class ManipulatordProxy < Proxy
      def initialize hostname
        super hostname, :manipulatord
      end

      def do_status options
        # ManipulatordProxy does not currently support a STATUS command
        Thread.new do
          begin
            XBarrier.instance.wait
            @status_mode = nil
            @status_auto = nil
            @status_debug = nil
            XBarrier.instance.wait( :result => nil )
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
            XBarrier.instance.wait( :result => nil )
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
            XBarrier.instance.wait( :result => nil )
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


    class ProxyPool
      include Singleton

      attr_reader :entries

      def initialize
        @entries = {}
      end

      def add_peer hostname
        @entries[ hostname ] = {
          :cmond        => CmondProxy.new( hostname ),
          :cpeerd       => CpeerdProxy.new( hostname ),
          :crepd        => CrepdProxy.new( hostname ),
          :manipulatord => ManipulatordProxy.new( hostname ),
        }
      end

      def get_peer hostname
        PeerComponent.new hostname
      end

      def get_the_first_peer
        get_peer @entries.keys[0]
      end

      def get_the_rest_of_peers
        h = @entries.keys  # hostnames
        h.shift
        PeerGroupComponent.new h
      end

      def get_peer_group
        PeerGroupComponent.new @entries.keys
      end
    end


    class PeerComponent
      def initialize hostname
        @hostname = hostname
        @targets = ProxyPool.instance.entries[ hostname ]
      end

      def number_of_targets
        @targets.size
      end

      def do_ps options
        @targets.each do |t, x|  # target type, proxy object
          x.do_ps options
        end
      end

      def print_ps
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', @targets.values[0].ps_header
        @targets.map do |t, x|
          if x.ps_error
            printf f, h, t, x.ps_error
          else
            if x.ps_stdout
              if 0 < x.ps_stdout.size
                x.ps_stdout.each do |y|
                  printf f, h, t, y
                end
              else
                printf f, h, t, ''  # grep pattern did not match
              end
            else
              printf f, h, t, '(error occured)'
            end
          end
        end
        puts ''
      end

      def ps_running?
        @targets.each do |t, x|  # target type, proxy object
          r = x.ps_running
          r.nil? and return nil
          r or return false
        end
        true
      end

      def print_ps_printf hostname, type, message
        h = hostname || 'HOSTNAME'
        t = type || 'DAEMON'
        printf "%-14s%-14s%s\n", h, t, message
      end

      def do_status options
        @targets.each do |t, x|  # target type, proxy object
          x.do_status options
        end
      end

      def print_status
        f = "%-14s%-14s%-14s%-14s%-14s%-14s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'ACTIVITY', 'MODE', 'AUTOPILOT', 'DEBUG'
        @targets.map do |t, x|
          r = x.ps_error ? "(#{x.ps_error})" : (x.ps_running.nil? ? 'unknown' : (x.ps_running ? 'running' : 'stopped'))
          if x.status_error
            if x.status_error.match( /Connection refused/ )
              printf f, h, t, r, nil, nil, nil
            else
              printf f, h, t, r, x.status_error, nil, nil
            end
          else
            m = x.status_mode ? ServerStatus.status_code_to_s( x.status_mode ) : ''
            a = x.status_auto.nil? ? '' : ( x.status_auto ? 'auto' : 'off' )
            d = x.status_debug.nil? ? '' : ( x.status_debug ? 'on' : 'off' )
            printf f, h, t, r, m, a, d
          end
        end
        puts ''
      end

      def do_start
        @targets.each do |t, x|
          x.do_start
        end
      end

      def print_start
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.start_error
            printf f, h, t, x.start_error
          else
            printf f, h, t, x.start_message
          end
        end
        puts ''
      end

      def do_stop
        @targets.each do |t, x|
          x.do_stop
        end
      end

      def print_stop
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.stop_error
            printf f, h, t, x.stop_error
          else
            printf f, h, t, x.stop_message
          end
        end
        puts ''
      end

      def do_mode mode
        @targets.each do |t, x|
          x.do_mode mode
        end
      end

      def print_mode
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.mode_error
            printf f, h, t, x.mode_error
          else
            printf f, h, t, x.mode_message
          end
        end
        puts ''
      end

      def ascend_mode mode
        @targets.each do |t, x|
          x.ascend_mode mode
        end
      end

      def descend_mode mode
        @targets.each do |t, x|
          x.descend_mode mode
        end
      end

      def mode
        r = nil
        @targets.each do |t, x|
          if x.is_a? CxxxdProxy
            m = x.status_mode
            m.nil? and return nil
            if r.nil?
              r = m
            else
              r == m or return nil
            end
          end
        end
        r
      end

      def do_auto auto
        @targets.each do |t, x|
          x.do_auto auto
        end
      end

      def print_auto
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.auto_error
            printf f, h, t, x.auto_error
          else
            printf f, h, t, x.auto_message
          end
        end
        puts ''
      end
    end


    class PeerGroupComponent
      def initialize hostnames
        @peers = hostnames.map do |h|  # hostname
          PeerComponent.new h
        end
      end

      def number_of_targets
        c = 0  # count
        @peers.each do |x|
          c = c + x.number_of_targets
        end
        c
      end

      def do_ps options
        @peers.each do |x|
          x.do_ps options
        end
      end

      def print_ps
        @peers.each do |x|
          x.print_ps
        end
      end

      def ps_running?
        @peers.each do |x|
          r = x.ps_running?
          r.nil? and return nil
          r or return false
        end
        true
      end

      def do_status options
        @peers.each do |x|
          x.do_status options
        end
      end

      def print_status
        @peers.each do |x|
          x.print_status
        end
      end

      def do_start
        @peers.each do |x|
          x.do_start
        end
      end

      def print_start
        @peers.each do |x|
          x.print_start
        end
      end

      def do_stop
        @peers.each do |x|
          x.do_stop
        end
      end

      def print_stop
        @peers.each do |x|
          x.print_stop
        end
      end

      def do_mode mode
        @peers.each do |x|
          x.do_mode mode
        end
      end

      def print_mode
        @peers.each do |x|
          x.print_mode
        end
      end

      def ascend_mode mode
        @peers.each do |x|
          x.ascend_mode mode
        end
      end

      def descend_mode mode
        @peers.each do |x|
          x.descend_mode mode
        end
      end

      def mode
        r = nil
        @peers.each do |x|
          m = x.mode
          m.nil? and return nil
          if r.nil?
            r = m
          else
            r == m or return nil
          end
        end
        r
      end

      def do_auto auto
        @peers.each do |x|
          x.do_auto auto
        end
      end

      def print_auto
        @peers.each do |x|
          x.print_auto
        end
      end
    end

  end
end
