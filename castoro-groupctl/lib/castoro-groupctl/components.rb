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

      attr_reader :ps_stdout, :ps_header, :ps_error

      def do_ps options
        @ps_stdout = nil
        issue_command_to_cstartd( 'PS', { :target => @target, :options => options } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r[ 'error' ]
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']}: #{e['message']} #{e['backtrace'].join(' ')}"
            @ps_error  = "#{e['code']}: #{e['message']}"
          elsif r[ 'stdout' ]
            @ps_stdout = r[ 'stdout' ]
            @ps_header = r[ 'header' ]
            Success.new h, t, r[ 'stdout' ]
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
          end
        end
      end

      def start
        xxx( 'START', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r[ 'error' ]
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']} #{e['message']} #{e['backtrace'].join(' ')}"
          elsif r[ 'status' ] and r[ 'status' ] != 0
            Failure.new h, t, "status=#{r['status']} #{r['message']}"
          elsif r[ 'status' ] == 0
            if r[ 'stdout' ].find { |x| x.match( /Starting.*NG/ ) } and r[ 'stderr' ].find { |x| x.match( /Errno::EADDRINUSE/ ) }
              Success.new h, t, "Already started"
            else
              Success.new h, t, "status=#{r['status']} #{r['message']}"
            end
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
          end
        end
      end

      def stop
        port = Configurations.instance.cstartd_comm_tcpport
        xxx( port, 'STOP', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r[ 'error' ]
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']} #{e['message']} #{e['backtrace'].join(' ')}"
          elsif r[ 'status' ] and r[ 'status' ] != 0
            if t == :manipulatord and r[ 'status' ] == 1 and r[ 'stderr' ].find { |x| x.match( /PID file not found/ ) }
              Success.new h, t, "Already stopped"
            else
              Failure.new h, t, "status=#{r['status']} #{r['message']}"
            end
          elsif r[ 'stdout' ] and r[ 'stdout' ].find { |x| x.match( /Errno::ECONNREFUSED/ ) }
            Success.new h, t, "Already stopped"
          elsif r[ 'status' ] == 0
            Success.new h, t, "status=#{r['status']} #{r['message']}"
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
          end
        end
      end

      def shutdown
        port = Configurations.instance.cstartd_comm_tcpport
        xxx( port, 'SHUTDOWN', nil )
      end

      def status
        port = Configurations.instance.cagentd_comm_tcpport
        xxx( port, 'STATUS', { :target => @target } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            Failure.new h, t, nil
          elsif r[ 'error' ]
            e = r[ 'error' ]
            Failure.new h, t, "#{e['code']} #{e['message']} #{e['backtrace'].join(' ')}"
          elsif r[ 'mode' ]
            Success.new h, t, r
          else
            Failure.new h, t, "Unknown error: #{r.inspect}"
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

      def get_peer_group
        PeerGroupComponent.new
      end

      def cxxxd
      end

      def peer
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
        f = "%-12s%-14s%s\n"  # format
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
                printf f, h, t, '(grep pattern did not match)'
              end
            else
              printf f, h, t, '(error occured)'
            end
          end
        end
        puts ''
      end

      def print_ps_printf hostname, type, message
        h = hostname || 'HOSTNAME'
        t = type || 'DAEMON'
        printf "%-12s%-14s%s\n", h, t, message
      end

      def start
        @leaves.each do |leaf|
          leaf.start
        end
      end

      def stop
        @leaves.each do |leaf|
          leaf.stop
        end
      end
    end


    class PeerGroupComponent
      def initialize
        @peers = ProxyPool.instance.entries.keys.map do |h|  # hostname
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

      def start
        @peers.each do |peer|
          peer.start
        end
      end

      def stop
        @peers.each do |peer|
          peer.stop
        end
      end
    end


    class CxxxdGroupComponent
      def initialize hostnames
        @peers = hostnames.map do |hostname|
          CxxxdComponent.new hostname
        end
      end

      def size
        @peers.size
      end

      def total
        count = 0
        @peers.each do |peer|
          count = count + peer.size
        end
        count
      end

      def status
        @peers.each do |peer|
          peer.status
        end
      end
    end

  end
end
