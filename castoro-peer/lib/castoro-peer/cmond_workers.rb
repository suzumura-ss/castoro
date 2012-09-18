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

require 'castoro-peer/pre_threaded_tcp_server'
require 'castoro-peer/worker'
require 'castoro-peer/log'
require 'castoro-peer/storage_servers'
require 'castoro-peer/server_status'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/extended_tcp_socket'
require 'castoro-peer/channel'
require 'castoro-peer/maintenace_server'
require 'castoro-peer/storage_space_monitor'

module Castoro
  module Peer

    $AUTO_PILOT = true

    class RemoteControl
      TIMED_OUT_DURATION = 600

      def self.set_mode( host, port )
        Thread.current.priority = 3
        socket = nil
        begin
          socket = ExtendedTCPSocket.new
          socket.connect( host, port, TIMED_OUT_DURATION )
        rescue => e
          Log.warning e, "Remote control: attempt of connecting to #{host}:#{port}"
          error = e.message
          socket.close if socket and ! socket.closed?
          socket = nil
        end
        if ( socket )
          socket.setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
          socket.syswrite( "_mode #{ServerStatus.instance.status_name}\n" )
          begin
            socket.gets_with_timed_out( TIMED_OUT_DURATION )
          rescue Errno::EAGAIN  # "Resource temporarily unavailable"
            Log.warning "Remote control: response timed out #{TIMED_OUT_DURATION}s: #{host}:#{port} #{ServerStatus.instance.status_name}"
          rescue => e
            Log.warning e, "Remote control: #{host}:#{port} #{ServerStatus.instance.status_name}"
          ensure
            socket.close if socket and ! socket.closed?
          end
        end
      end

      def self.set_mode_of_every_local_target
        c = Configurations.instance
        Thread.new {
          self.set_mode( '127.0.0.1', c.cpeerd_maintenance_tcpport )
        }
        Thread.new {
          self.set_mode( '127.0.0.1', c.crepd_maintenance_tcpport )
        }
      end
    end

    class CmondWorkers
      include Singleton

      def initialize
        c = Configurations.instance
        @w = []
        @s = StorageSpaceMonitor.new( c.basket_basedir )
        @a = AlivePacketSender.new( c.gateway_comm_ipaddr_multicast, c.gateway_watchdog_udpport_multicast, @s )
        @p = CxxxdCommnicationWorker.new( '127.0.0.1', c.cpeerd_healthcheck_tcpport )
        @r = CxxxdCommnicationWorker.new( '127.0.0.1', c.crepd_healthcheck_tcpport )
        @colleague_hosts = StorageServers.instance.colleague_hosts
        @colleague_hosts.each { |h| @w << CxxxdCommnicationWorker.new( h, c.cmond_healthcheck_tcpport ) }
        @d = nil
        @z = SupervisorWorker.new( @p, @r, @d, @w, @a )
        @m = CmondTcpMaintenaceServer.new( c.cmond_maintenance_tcpport, @p, @r, @d, @w, @a )
        @h = TCPHealthCheckPatientServer.new( c.cmond_healthcheck_tcpport )
      end

      def start_workers
        @s.start
        @w.reverse_each { |w| w.start }
        @r.start
        @p.start
        @a.start
        sleep 1
        @z.start
      end

      def stop_workers
        @z.graceful_stop
        @w.each { |w| w.graceful_stop }
        @p.graceful_stop
        @r.graceful_stop
        @a.graceful_stop
        @s.stop
      end

      def start_maintenance_server
        @m.start
        @h.start
      end

      def stop_maintenance_server
        @m.graceful_stop
        @h.graceful_stop
      end

   #####################################################################


   ########################################################################
   # CxxxdCommnicationWorker
   ########################################################################

      class CxxxdCommnicationWorker < Worker
        attr_accessor :mode, :auto, :error, :host, :port

        TIMED_OUT_DURATION = 600
        INTERVAL = 3
        THRESHOLD = 2

        def initialize( host, port )
          @host, @port = host, port
          super
          @socket = nil
          @interval = INTERVAL
          @target = Time.new + @interval
          @last_error = nil
        end

        def serve
          Thread.current.priority = 3
          mode, auto, error = nil, nil, nil
          begin
            if ( @socket.nil? or @socket.closed? )
              start_time = Time.new
              begin
                @socket = ExtendedTCPSocket.new
                @socket.connect( @host, @port, TIMED_OUT_DURATION )
                Log.notice "Health check: connection established to #{@host}:#{@port}"
              rescue => e
                unless ( @last_error == e.message )
                  Log.warning e, "Health check: attempt of connecting to #{@host}:#{@port}"
                end
                error = e.message
                @socket.close if @socket and ! @socket.closed?
                @socket = nil
              end
              elapsed = Time.new - start_time
              Log.notice "Health check: connection establishment to #{@host}:#{@port} took #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
            end

            if ( @socket )
              start_time = Time.new
              # Use syswrite() here and don't use write() or puts().
              # write() in Ruby 1.9.1 does a lot of things causing waste of time, 
              # especially releasing the global_vm_lock and obtaining it
              # puts() in Ruby 1.9.1 emits a write() system call twice.
              # The one is for the message and the other is for "\n"
              @socket.syswrite( "\n" )
              elapsed = Time.new - start_time
              Log.notice "Health check: command syswrite() to #{@host}:#{@port} took #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
              x = nil
              begin
                x = @socket.gets_with_timed_out( TIMED_OUT_DURATION )
                elapsed = Time.new - start_time
                Log.notice "Health check: command response from #{@host}:#{@port} took #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
                mode, mode2, auto, debug = x.split(' ')
                # p [ mode, mode2, auto, debug ]
                error = nil
              rescue Errno::EAGAIN  # "Resource temporarily unavailable"
                elapsed = Time.new - start_time
                Log.notice "Health check: command response did not come from #{@host}:#{@port} in #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
                error = "Timed out #{TIMED_OUT_DURATION}s"
                Log.warning "#{error} #{@host}:#{@port}"
                @socket.close if @socket and ! @socket.closed?
                @socket = nil
              rescue => e
                Log.warning e, "#{@host}:#{@port}"
                error = e.message
                @socket.close if @socket and ! @socket.closed?
                @socket = nil
              end
            end
          rescue => e
            Log.warning e, "#{@host}:#{@port}"
            error = e.message
            @socket.close if @socket and ! @socket.closed?
            @socket = nil
          end

          # Todo: has to be guarded with a Mutex
          @mode, @auto, @error = mode, auto, error
#          p [ @host, @port, @mode, @auto, @error ]

        rescue => e
          Log.err e, "#{@host}:#{@port}"
          error = e.message

        ensure
          rest = @target - Time.new
          x_now = Time.new
          x_rest = rest
          x_target = @target
          if ( rest < 0 )
            @target = @target + @interval * ( 1 + ( ( 0 - rest ) / @interval ).to_i )
            rest = @target - Time.new
            rest = @interval if rest <= 0 or @interval < rest
          else
            @target = @target + @interval
          end
          # Log.notice "rest:#{x_rest} = @target:#{x_target} - Time.new:#{x_now} ==> rest:#{rest} @target:#{@target}"
          sleep rest
          @last_error = error
        end

        def graceful_stop
          finished
          super
        end
      end


   ########################################################################
   # xxx
   ########################################################################

      class SupervisorWorker < Worker
        def initialize( p, r, d, w, alive_packet_sender )
          @p, @r, @d, @w, @alive_packet_sender = p, r, d, w, alive_packet_sender
          super
          @error = false
          # @lsat_min = ServerStatus::ONLINE
        end

        def serve
          begin
            error = false
            error = true if @p.error or @r.error
            @w.each { |x| error = true if x.error }
#            p [ @error, error, @error != error ]

            min = error ? ServerStatus::REP : ServerStatus::ONLINE
            if ( @p.mode and @p.mode != '' )
              p_mode = ServerStatus.status_name_to_i @p.mode
              if ( ServerStatus::REP <= p_mode )
                min = p_mode if p_mode < min
              end
            end
            if ( @r.mode and @r.mode != '' )
              r_mode = ServerStatus.status_name_to_i @r.mode
              if ( ServerStatus::REP <= r_mode )
                min = r_mode if r_mode < min
              end
            end
            @w.map { |x| 
              if ( x.mode and x.mode != '' )
                y = ServerStatus.status_name_to_i x.mode
#p [x, y]
                if ( ServerStatus::REP <= y )
                  min = y if y < min
                end
              end
            }
            min = ServerStatus::REP if min < ServerStatus::REP

            if ( @error != error )
              @error = error
              if ( error )
                Log.err( "#{@p.host}:#{@p.port} cpeerd error: #{@p.error}" ) if @p.error
                Log.err( "#{@r.host}:#{@r.port} crepd error: #{@r.error}" ) if @r.error
                # Log.warning( "#{@d.host}:#{@d.port} MySQL error: #{@d.error}" ) if @d.error
                @w.each { |x| 
                  Log.err( "#{x.host}:#{x.port} cmond error: #{x.error}" ) if x.error
                }
              else
                Log.notice( "Health check: error recovered" )
              end
            end

            # if ( min != @lsat_min and min < @lsat_min and min < ServerStatus.instance.status )  # Todo: falling down and rising up? ...
            if ( min < ServerStatus.instance.status )  # Todo: falling down and rising up? ...
              if ( $AUTO_PILOT )
                ServerStatus.instance.status = min
                sleep 0.01
                RemoteControl.set_mode_of_every_local_target
                @alive_packet_sender.send_alive_packet
              else
                Log.notice( "STATUS change (from #{ServerStatus.instance.status_name} to #{min}) is requested, but auto is disabled" )
              end
            end
            # @lsat_min = min
                
          rescue => e
            Log.err e
          ensure
            sleep 3
          end
        end

        def graceful_stop
          finished
          super
        end
      end

   ########################################################################
   # AlivePacketSender
   ########################################################################

      class AlivePacketSender < Worker
        def initialize( ip, port, space_monitor )
          @ip, @port, @space_monitor = ip, port, space_monitor
          super
          socket = ExtendedUDPSocket.new
          socket.set_multicast_if Configurations.instance.gateway_comm_ipaddr_nic
          @channel   = UdpClientChannel.new socket
          @host      = Configurations.instance.peer_hostname
          @period    = Configurations.instance.cmond_period_of_watchdog_sender
          @mutex     = Mutex.new
        end

        def serve
          send_alive_packet
          sleep @period
        end

        def send_alive_packet
          @mutex.synchronize {
            status = ServerStatus.instance.status
            unless ( status == ServerStatus::UNKNOWN )
              args = Hash[ 'host', @host, 'status', status, 'available', @space_monitor.space_bytes ]
              @channel.send 'ALIVE', args, @ip, @port
            end
          }
        end

        def graceful_stop
          finished
          super
        end
      end

   ########################################################################
   # TcpMaintenaceServer
   ########################################################################

      class CmondTcpMaintenaceServer < TcpMaintenaceServer
        def initialize( port, p, r, d, w, alive_packet_sender )
          @p, @r, @d, @w, @alive_packet_sender = p, r, d, w, alive_packet_sender
          super( port )
          c = Configurations.instance
          @cpeerd_maintenance_port = c.cpeerd_maintenance_tcpport
          @crepd_maintenance_port  = c.crepd_maintenance_tcpport
        end

        def do_help
          @io.syswrite( [ 
                         "quit",
                         "version",
                         "mode [unknown(0)|offline(10)|readonly(20)|rep(23)|fin_rep(25)|del_rep(27)|online(30)]",
                         "auto [off|auto]",
                         "debug [on|off]",
                         "shutdown",
                         "inspect",
                         "gc_profiler [off|on|report]",
                         "gc [start|count]",
                         "status [-s] [period] [count]", 
                         nil
                        ].join("\n") )
        end

        def do_shutdown
          ServerStatus.instance.status = ServerStatus::OFFLINE 
          @alive_packet_sender.send_alive_packet
          # Todo:
          Thread.new {
            sleep 0.5
            Log.stop
            Process.exit 0
          }
          # Todo:
          CmondMain.instance.stop
        end

        def do_mode
          para = @a.shift
          if (para)
            para.downcase!
            ServerStatus.instance.status_name = para
            RemoteControl.set_mode_of_every_local_target
          end
          x = ServerStatus.instance.status_name
          @io.syswrite( "run mode: #{x}\n" )
          @alive_packet_sender.send_alive_packet
        end

        def do_backdoor_mode
          para = @a.shift
          # Todo: Log this
          # Todo: is this good?
          if ( $AUTO_PILOT )
            if (para)
              para.downcase!
              ServerStatus.instance.status_name = para
              RemoteControl.set_mode_of_every_local_target
            end
            x = ServerStatus.instance.status_name
            @io.syswrite( "run mode: #{x}\n" )
          else
            if (para)
              @io.syswrite( "run mode cannot be automatically altered when auto is disable.\n" )
            else
              x = ServerStatus.instance.status_name
              @io.syswrite( "run mode: #{x}\n" )
            end
          end
          @alive_packet_sender.send_alive_packet
        end

        def do_status
          opt_short = false
          opt_period = nil
          opt_count = 1
          while ( opt = @a.shift )
            opt_short = true if opt == "-s"
            opt_period = opt.to_i if opt_period.nil? and opt.match(/[0-9]/)
            opt_count  = opt.to_i if ! opt_period.nil? and opt.match(/[0-9]/)
          end
          while ( 0 < opt_count )
            t = Time.new
            if ( opt_short )

              # Todo
              @io.syswrite( sprintf(" %-10s cmond : %-12s %-4s  %s", @hostname, ServerStatus.instance.status_name, 
                                    ($AUTO_PILOT ? "auto":"off"), "") +
                            sprintf("   cpeerd : %-12s %-4s  %s", ServerStatus.status_to_s(@p.mode), @p.auto, @p.error ) + 
                            sprintf("   crepd : %-12s %-4s  %s\n", ServerStatus.status_to_s(@r.mode), @r.auto, @r.error ))

            else
              @io.syswrite "#{t.iso8601}\n"
              @io.syswrite( sprintf " %-10s cmond : %-12s %-4s  %s\n", @hostname, ServerStatus.instance.status_name, ($AUTO_PILOT ? "auto":"off"), "" )

              @io.syswrite( sprintf " %-10s cpeerd: %-12s %-4s  %s\n", @p.host, ServerStatus.status_to_s(@p.mode), @p.auto, @p.error )
              @io.syswrite( sprintf " %-10s crepd : %-12s %-4s  %s\n", @r.host, ServerStatus.status_to_s(@r.mode), @r.auto, @r.error )
              # Todo: p [ @d.mode, @d.auto, @d.error ]
              @w.each { |x|
                @io.syswrite( sprintf " %-10s cmond : %-12s %-4s  %s\n", x.host, ServerStatus.status_to_s(x.mode), x.auto, x.error )
              }
              @io.syswrite "\n"
            end
            sleep opt_period unless opt_period.nil?
            opt_count = opt_count - 1
          end
        end

      end

    end
  end
end

