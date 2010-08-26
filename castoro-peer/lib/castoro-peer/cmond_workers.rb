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
          socket.write( "_mode #{ServerStatus.instance.status_name}\n" )
          socket.set_receive_timed_out( TIMED_OUT_DURATION )
          begin
            socket.gets
          rescue Errno::EAGAIN  # "Resource temporarily unavailable"
            Log.warning "Remote control: response timed out #{TIMED_OUT_DURATION}s: #{host}:#{port} #{ServerStatus.instance.status_name}"
          rescue => e
            Log.warning e, "Remote control: #{host}:#{port} #{ServerStatus.instance.status_name}"
          ensure
            socket.close if socket and ! socket.closed?
          end
        end
      end
    end

    class CmondWorkers
      include Singleton

      def initialize
        c = Configurations.instance
        @s = StorageSpaceMonitor.new( c.BasketBaseDir )

        @w = []
#        @w << SampleWorker.new( PRIORITY_7 )
        @a = AlivePacketSender.new( PRIORITY_7, c.MulticastAddress, c.WatchDogCommandPort, @s )
        @my_host = StorageServers.instance.my_host
        @p = CxxxdCommnicationWorker.new( PRIORITY_7, @my_host, c.CpeerdHealthCheckPort )
        @r = CxxxdCommnicationWorker.new( PRIORITY_7, @my_host, c.CrepdHealthCheckPort )
        @colleague_hosts = StorageServers.instance.colleague_hosts
        @colleague_hosts.each { |h| @w << CxxxdCommnicationWorker.new( PRIORITY_7, h, c.CmondHealthCheckPort ) }
        @d = nil
        @z = SupervisorWorker.new( PRIORITY_7, @p, @r, @d, @w, @s )
        @m = TcpMaintenaceServer.new( PRIORITY_7, c.CmondMaintenancePort, @p, @r, @d, @w, @s )
        @h = TCPHealthCheckPatientServer.new( PRIORITY_7, c.CmondHealthCheckPort )
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
        INTERVAL = 1
        THRESHOLD = 3

        def initialize( priority, host, port )
          @host, @port = host, port
          super
          @socket = nil
          @interval = INTERVAL
          @target = Time.new + @interval
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
              rescue => e
                Log.warning e, "Health check: attempt of connecting to #{@host}:#{@port}"
                error = e.message
                @socket.close if @socket and ! @socket.closed?
                @socket = nil
              end
              elapsed = Time.new - start_time
              Log.notice "Health check: connection establishment to #{@host}:#{@port} took #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
            end

            if ( @socket )
              start_time = Time.new
              # Use write() here and don't use puts().
              # puts in Ruby 1.9.1 emits a write() system call twice.
              # The one is for the message and the other is for "\n"
              @socket.write( "\n" )
              elapsed = Time.new - start_time
              Log.notice "Health check: command write() to #{@host}:#{@port} took #{"%.3fs" % (elapsed)}" if THRESHOLD < elapsed 
              # @socket.set_receive_timed_out( TIMED_OUT_DURATION )
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
                error = e.message
                Log.warning e, "#{@host}:#{@port}"
                @socket.close if @socket and ! @socket.closed?
                @socket = nil
              end
            end
          rescue => e
            Log.warning e, "#{@host}:#{@port}"
            error = "#{e.message}"
            @socket.close if @socket and ! @socket.closed?
            @socket = nil
          end

          # Todo: has to be guarded with a Mutex
          @mode, @auto, @error = mode, auto, error
#          p [ @host, @port, @mode, @auto, @error ]

        rescue => e
          Log.err e, "#{@host}:#{@port}"

        ensure
          rest = @target - Time.new
          if ( rest < 0 )
            @target = @target + @interval * ( 1 + ( ( 0 - rest ) / @interval ).to_i )
            rest = @target - Time.new
            rest = @interval if rest <= 0 or @interval < rest
          else
            @target = @target + @interval
          end
          sleep rest
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
        def initialize( priority, p, r, d, w, space_monitor )
          @p, @r, @d, @w = p, r, d, w
          @space_monitor = space_monitor
          super
          @error = false
          # @lsat_min = ServerStatus::ACTIVE
          @config = Configurations.instance
        end

        def serve
          begin
            error = false
            error = true if @p.error or @r.error
            @w.each { |x| error = true if x.error }
#            p [ @error, error, @error != error ]

            min = error ? ServerStatus::REP : ServerStatus::ACTIVE
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
                Log.notice( "error recovered" )
              end
            end

            # if ( min != @lsat_min and min < @lsat_min and min < ServerStatus.instance.status )  # Todo: falling down and rising up? ...
            if ( min < ServerStatus.instance.status )  # Todo: falling down and rising up? ...
              if ( $AUTO_PILOT )
                ServerStatus.instance.status = min
                sleep 0.01

                Thread.new {
                  RemoteControl.set_mode( @p.host, @config.CpeerdMaintenancePort )
                  RemoteControl.set_mode( @r.host, @config.CrepdMaintenancePort )
                }

                status = ServerStatus.instance.status
                unless ( status == ServerStatus::UNKNOWN )
                  ip      = @config.MulticastAddress
                  port    = @config.WatchDogCommandPort
                  channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
                  host    = @config.HostnameForClient
                  args    = {
                    'host'      => host,
                    'status'    => status,
                    'available' => @space_monitor.space_bytes,
                  }

                  channel.send( 'ALIVE', args, ip, port )
                end

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
        def initialize( priority, ip, port, space_monitor )
          @channel       = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
          @ip, @port     = ip, port
          @host          = Configurations.instance.HostnameForClient
          @period        = Configurations.instance.PeriodOfAlivePacketSender
          @space_monitor = space_monitor
          super
        end

        def serve
          status = ServerStatus.instance.status
          unless ( status == ServerStatus::UNKNOWN )
            args = Hash[ 'host', @host, 'status', status, 'available', @space_monitor.space_bytes ]
            @channel.send( 'ALIVE', args, @ip, @port )
          end
          sleep @period
        end

        def graceful_stop
          finished
          super
        end
      end

   ########################################################################
   # TcpMaintenaceServer
   ########################################################################

      class TcpMaintenaceServer < PreThreadedTcpServer
        def initialize( priority, port, p, r, d, w, space_monitor )
          @p, @r, @d, @w = p, r, d, w
          @space_monitor = space_monitor
          super( port, '0.0.0.0', 10, priority )
          @config = Configurations.instance
        end

        def serve( io )
          begin
            serve_impl( io )
          rescue => e
            Log.err e
          end
          sleep 0.01
        end

        def serve_impl( io )
          @socket = io
          program = $0.sub(/.*\//, '')
          
          while ( line = io.gets )
            line.chomp!
            next if line =~ /\A\s*\Z/

            begin
              a = line.split(' ')
              command = a.shift.downcase
              case command
              when 'quit'
                break
              when 'help'
                io.puts( [ 
                          "quit",
                          "auto [off|auto]",
                          "mode [unknown(0)|offline(10)|readonly(20)|rep(23)|fin_rep(25)|del_rep(27)|online(30)]",
                          "debug [on|off]",
                          "status [-s] [period] [count]", 
#                          "stat [-s] [period] [count]", 
#                          "dump",
                          "reload [configration_file]",
                          "shutdown",
                          nil
                         ].join("\r\n") )

              when 'shutdown'
                #  Todo: should use graceful-stop.
                io.puts( "Shutdown is going ...\r\n" )
                Log.notice( "Shutdown is requested." )

                status  = ServerStatus::MAINTENANCE
                ip      = @config.MulticastAddress
                port    = @config.WatchDogCommandPort
                channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
                host    = @config.HostnameForClient
                args    = {
                  'host'      => host, 
                  'status'    => status, 
                  'available' => @space_monitor.space_bytes,
                }

                channel.send( 'ALIVE', args, ip, port )
                sleep 0.1
                channel.send( 'ALIVE', args, ip, port )
                sleep 0.1
                channel.send( 'ALIVE', args, ip, port )
                # Todo:
                Thread.new {
                  sleep 0.5
                  Process.exit 0
                }
                # Todo:
                CmondMain.instance.stop

              when 'health'
                io.puts( "#{ServerStatus.instance.status_name} #{($AUTO_PILOT) ? "auto" : "off"} #{($DEBUG) ? "on" : "off"}\r\n" )

              when 'mode'
                para = a.shift
                # Todo: is change of mode allowed in auto pilot mode?
#                if ( $AUTO_PILOT )
#                  if (para)
#                    io.puts( "run mode cannot be manually altered when auto is enable.\r\n" )
#                  else
#                    x = ServerStatus.instance.status_name
#                    io.puts( "run mode: #{x}\r\n" )
#                  end
#                else
                if (para)
                  para.downcase!
                  ServerStatus.instance.status_name = para
                  my_host = StorageServers.instance.my_host
                  Thread.new {
                    RemoteControl.set_mode( my_host, @config.CpeerdMaintenancePort )
                  }
                  Thread.new {
                    RemoteControl.set_mode( my_host, @config.CrepdMaintenancePort )
                  }
#                  end
                end
                x = ServerStatus.instance.status_name
                io.puts( "run mode: #{x}\r\n" )
                status = ServerStatus.instance.status
                # print [ 'mode', status ]
                if ( para and status != ServerStatus::UNKNOWN )
                  ip      = @config.MulticastAddress
                  port    = @config.WatchDogCommandPort
                  channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
                  host    = @config.HostnameForClient
                  args    = {
                    'host'      => host, 
                    'status'    => status,
                    'available' => @space_monitor.space_bytes,
                  }
                  channel.send( 'ALIVE', args, ip, port )
                end

              when '_mode'
                para = a.shift
                # Todo: Log this
                # Todo: is this good?
                if ( $AUTO_PILOT )
                  if (para)
                    para.downcase!
                    ServerStatus.instance.status_name = para
                    my_host = StorageServers.instance.my_host
                    Thread.new {
                      RemoteControl.set_mode( my_host, @config.CpeerdMaintenancePort )
                    }
                    Thread.new {
                      RemoteControl.set_mode( my_host, @config.CrepdMaintenancePort )
                    }
                  end
                  x = ServerStatus.instance.status_name
                  io.puts( "run mode: #{x}\r\n" )
                else
                  if (parap)
                    io.puts( "run mode cannot be automatically altered when auto is disable.\r\n" )
                  else
                    x = ServerStatus.instance.status_name
                    io.puts( "run mode: #{x}\r\n" )
                  end
                end
                status = ServerStatus.instance.status
                if ( para status != ServerStatus::UNKNOWN )
                  ip      = @config.MulticastAddress
                  port    = @config.WatchDogCommandPort
                  channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
                  host    = @config.HostnameForClient
                  args    = {
                    'host'      => host,
                    'status'    => status,
                    'available' => @space_monitor.space_bytes,
                  }
                  channel.send( 'ALIVE', args, ip, port )
                end

              when 'auto'
                p = a.shift
                if (p)
                  p.downcase!
                  case (p) 
                  when 'auto' ; $AUTO_PILOT = true
                  when 'off'  ; $AUTO_PILOT = false
                  when nil  ; 
                    # Todo: does error message need  400?
                  else raise StandardError, "400 Unknown parameter: #{p} ; auto [off|auto]"
                  end
                end
                io.puts( "auto: " + ( ($AUTO_PILOT) ? "auto" : "off")  + "\r\n" )

              when 'reload'
                file = a.shift
                begin
                  # Todo:
                  # CmondWorkers.instance.stop_workers
                  entries = @config.reload( file )
                  # Todo:
                  # CmondWorkers.instance.start_workers
                  io.puts( "#{entries.inspect}\r\n" )
                rescue => e
                  io.puts( "#{e.class} - #{e.message}" )
                end

              when 'debug'
                # Todo: don't use p
                p = a.shift
                if (p)
                  p.downcase!
                  case (p) 
                  when 'on' ; $DEBUG = true
                  when 'off'; $DEBUG = false
                  when nil  ; 
                  else raise StandardError, "400 Unknown parameter: #{p} ; debug [on|off]"
                  end
                end
                io.puts( "debug mode: " + ( ($DEBUG) ? "on" : "off")  + "\r\n" )
                #            when 'stop'
                #              Main.instance.stop
                #            when 'start'
                #              Main.instance.start

              when 'status'
                my_host = StorageServers.instance.my_host
                opt_short = false
                opt_period = nil
                opt_count = 1
                while ( opt = a.shift )
                  opt_short = true if opt == "-s"
                  opt_period = opt.to_i if opt_period.nil? and opt.match(/[0-9]/)
                  opt_count  = opt.to_i if ! opt_period.nil? and opt.match(/[0-9]/)
                end
                while ( 0 < opt_count )
                  t = Time.new
                  if ( opt_short )

                    # Todo
                    io.puts( sprintf(" %-10s cmond : %-12s %-4s  %s", my_host, ServerStatus.instance.status_name, 
                                     ($AUTO_PILOT ? "auto":"off"), "") +
                             sprintf("   cpeerd : %-12s %-4s  %s", ServerStatus.status_to_s(@p.mode), @p.auto, @p.error ) + 
                             sprintf("   crepd : %-12s %-4s  %s", ServerStatus.status_to_s(@r.mode), @r.auto, @r.error ))

                  else
                    io.puts t.iso8601
                    io.puts( sprintf " %-10s cmond : %-12s %-4s  %s", my_host, ServerStatus.instance.status_name, ($AUTO_PILOT ? "auto":"off"), "" )

                    io.puts( sprintf " %-10s cpeerd: %-12s %-4s  %s", @p.host, ServerStatus.status_to_s(@p.mode), @p.auto, @p.error )
                    io.puts( sprintf " %-10s crepd : %-12s %-4s  %s", @r.host, ServerStatus.status_to_s(@r.mode), @r.auto, @r.error )
                    # Todo: p [ @d.mode, @d.auto, @d.error ]
                    @w.each { |x|
                      io.puts( sprintf " %-10s cmond : %-12s %-4s  %s", x.host, ServerStatus.status_to_s(x.mode), x.auto, x.error )
                    }
                    io.puts ""
                  end
                  sleep opt_period unless opt_period.nil?
                  opt_count = opt_count - 1
                end
                # io.puts( StorageServers.instance.my_host )
                # io.puts( StorageServers.instance.colleague_hosts )
                

              when 'stat'
                io.puts( "400 not implemented yet." )

              else
                raise StandardError, "400 Unknown command: #{command} ; try help command"
              end
            rescue StandardError => e
              io.puts( "#{e.message}\r\n" )
            rescue => e
              io.puts( "500 Internal Server Error: #{e.class} #{e.message}\r\n" )
            end
          end
        end
      end


      class StatisticsLogger < Worker
        def serve
          begin
            total = 0
            a = STATISTICS_TARGETS.map { |t|
              x = t.instance
              total = total + x.size
              "#{x.nickname}=#{x.size}"
            }
            if ( 0 < total )
              Log.notice( "STAT: #{a.join(' ')}" )
            end
          rescue => e
            Log.warning e
          ensure
            sleep @config.PeriodOfStatisticsLogger
          end
        end
      end

    end
  end
end

