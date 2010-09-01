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
require 'castoro-peer/maintenace_server'
require 'castoro-peer/crepd_sender'
require 'castoro-peer/scheduler'

module Castoro
  module Peer

    $AUTO_PILOT = true

    # Todo: This could be moved to the configuration; this is also written in cpeerd_worker.rb
    DIR_REPLICATION = "/var/castoro/replication"
    DIR_WAITING     = "#{DIR_REPLICATION}/waiting"
    DIR_PROCESSING  = "#{DIR_REPLICATION}/processing"
    DIR_SLEEPING    = "#{DIR_REPLICATION}/sleeping"

    $ReplicationSenderQueue = nil

########################################################################
# Controller of the replication workers
########################################################################

    class ReplicationWorkers
      include Singleton

      def initialize
        c = Configurations.instance
        @w = []
        $ReplicationSenderQueue = queue = Queue.new
        @w << UdpReplicationInternalCommandReceiver.new( queue, c.ReplicationUDPCommandPort )
        @w << ReplicationSenderManager.new( queue )
        c.NumberOfReplicationSender.times      { @w << ReplicationSender.new( queue ) }
        @m = TcpMaintenaceServer.new( c.CrepdMaintenancePort )
        @h = TCPHealthCheckPatientServer.new( c.CrepdHealthCheckPort )
      end

      def start_workers
        ReplicationSenderManager.reset_the_status_of_waiting_entries
        @w.reverse_each { |w| w.start }
      end

      def stop_workers
        @w.each { |w|
#          p [ 'stop_workers', w ]
          # Todo: somewhat unusual
          Thread.new {
            w.graceful_stop
          }
        }
      end

      def start_maintenance_server
        @m.start
        @h.start
      end

      def stop_maintenance_server
        @m.graceful_stop
        @h.graceful_stop
      end

   ########################################################################
   # Workers
   ########################################################################

      class ReplicationSenderManager < Worker
        HIGH_THRESHOLD_LENGTH = 100
        MIDDLE_THRESHOLD_LENGTH = 60
        LOW_THRESHOLD_LENGTH = 30
        SLEEP_DURATION   = 10      # in seconds
        PUSH_INTERVAL    = 0.050   # in seconds

        def initialize( queue )
          @queue = queue
          Dir.exists? DIR_REPLICATION or Dir.mkdir DIR_REPLICATION
          Dir.exists? DIR_WAITING     or Dir.mkdir DIR_WAITING
          Dir.exists? DIR_PROCESSING  or Dir.mkdir DIR_PROCESSING
          Dir.exists? DIR_SLEEPING    or Dir.mkdir DIR_SLEEPING
          File.writable? DIR_WAITING    or raise StandardError, "no write permission: #{DIR_WAITING}"
          File.writable? DIR_PROCESSING or raise StandardError, "no write permission: #{DIR_PROCESSING}"
          File.writable? DIR_SLEEPING   or raise StandardError, "no write permission: #{DIR_SLEEPING}"
          super
          @last_mtime_w = nil
          @last_mtime_s = nil
        end
        
        def serve
          unless ( ReplicationSenderManager.activated? )
            sleep 3
            return
          end

          MaintenaceServerScheduler.instance.check_point

          mtime_w = File.mtime( DIR_WAITING )
          mtime_s = File.mtime( DIR_SLEEPING )
          if ( @last_mtime_w and @last_mtime_w == mtime_w and
               @last_mtime_s and @last_mtime_s == mtime_s )
            sleep 3
          end
          @last_mtime_w = mtime_w
          @last_mtime_s = mtime_s

          if ( @queue.size < LOW_THRESHOLD_LENGTH )
            d = Dir.open( DIR_WAITING )
            h = Hash.new
            d.each { |x|
              unless ( x == "." || x == ".." )
                h[x] = File.mtime "#{DIR_WAITING}/#{x}"
              end
            }
            d.close
            (h.sort { |a, b| a[1] <=> b[1] }).each {|x|
              @queue.enq x[0]
              break if HIGH_THRESHOLD_LENGTH <= @queue.size
              sleep PUSH_INTERVAL
            }
          end

          if ( @queue.size < LOW_THRESHOLD_LENGTH )
            t = Time.new - SLEEP_DURATION
            d = Dir.open( DIR_SLEEPING )
            h = Hash.new
            d.each { |x|
              unless ( x == "." || x == ".." )
                u = File.mtime "#{DIR_SLEEPING}/#{x}"
                h[x] = u if u < t
              end
            }
            d.close
            (h.sort { |a, b| a[1] <=> b[1] }).each {|x|
              @queue.enq x[0]
              break if HIGH_THRESHOLD_LENGTH <= @queue.size
              sleep PUSH_INTERVAL
            }
          end

          size = @queue.size
          if ( HIGH_THRESHOLD_LENGTH <= size )
            sleep 3
          elsif ( MIDDLE_THRESHOLD_LENGTH <= size )
            sleep 2
          else
            sleep 1
          end

        rescue => e
          Log.waring e
          sleep 10
        end

        def self.activated?
          case ServerStatus.instance.status
          when ServerStatus::ACTIVE       ; true
          when ServerStatus::DEL_REP      ; true
          when ServerStatus::FIN_REP      ; true
          when ServerStatus::REP          ; true
          when ServerStatus::READONLY     ; false
          when ServerStatus::MAINTENANCE  ; false
          when ServerStatus::UNKNOWN      ; false
          else ; false
          end
        end

        def self.reset_the_status_of_waiting_entries
          d = Dir.open( DIR_PROCESSING )
          d.each { |x|
            unless ( x == "." || x == ".." )
              File.rename( "#{DIR_PROCESSING}/#{x}", "#{DIR_WAITING}/#{x}" )
            end
          }
          d.close

          d = Dir.open( DIR_SLEEPING )
          d.each { |x|
            unless ( x == "." || x == ".." )
              File.rename( "#{DIR_SLEEPING}/#{x}", "#{DIR_WAITING}/#{x}" )
            end
          }
          d.close
        end
      end

      class ReplicationSender < Worker
        def initialize( queue )
          @queue = queue
          super
        end

        def serve
          unless ( ReplicationSenderManager.activated? )
            sleep 3
            return
          end

          x = @queue.deq
          wtg = "#{DIR_WAITING}/#{x}"
          slp = "#{DIR_SLEEPING}/#{x}"
          prc = "#{DIR_PROCESSING}/#{x}"
          move_on = false

          ReplicationSenderManager.activated? or return
          File.exists? prc and return

          org = nil
          if ( File.exists? wtg )
            org = wtg
          elsif ( File.exists? slp )
            org = slp
          end
          if ( org )
            begin
              File.rename( org, prc )
              move_on = true
            rescue Errno::ENOENT
              # intended, nothing to do
            end
          end

          move_on or return

          # x could be, for example, 
          # "123.4.5.replicate"           as a new replication
          # "123.4.5.delete"              as a new deletion
          # "123.4.5.replicate.server101" as a replication; a skipped replication has done
          # "123.4.5.delete.server101"    as a deletion;    a skipped deletion has done
          content_id, type_id, revision_number, action, alternative = x.split('.')

          basket = Basket.new( content_id, type_id, revision_number )

          if ( alternative )
            alternative_host_candidates = []
          else
            alternative_host_candidates = StorageServers.instance.alternative_hosts.dup
          end

          host = StorageServers.instance.target
          alternative_host = nil
          done = false

          begin
            @sender = ReplicationSenderImplementation.new

            case action
            when "replicate"
              Log.debug( "Start sending replication: #{basket} to #{host}" )
              File.exist? basket.path_a or raise NotFoundError, "No such basket exists: #{basket.path_a}"
              @sender.do_replicate_command( basket, host )
              done = true

            when "delete"
              Log.debug( "Start sending deletion: #{basket} to #{host}" )
              # File.exist? basket.path_a and raise PermanentError, "basket still exists: #{basket.path_a}"
              @sender.do_delete_command( basket, host )
              done = true

            else
              raise PermanentError, "Unknown action: #{action} #{basket}"
            end

          rescue NotFoundError => e
            Log.warning e
            done = true

          rescue RetryableError => e
            Log.warning e
            host = alternative_host = alternative_host_candidates.shift
            retry if host
            done = false

          rescue PermanentError => e
            Log.err e
            done = true

          rescue AlreadyExistsPermanentError => e
            Log.warning e
            done = true

          rescue InvalidArgumentPermanentError => e
            Log.err e
            done = true

          rescue => e
            Log.warning e
            done = false
          end

          # p [ "done=#{done}", "alternative_host=#{alternative_host}" ]

          if ( done )
            unless ( alternative_host )
              # replication or deletion of a basket to the next host successfully finished,
              # or no action was demaned
              File.delete( prc )
            else
              # an attempt of replicating/deleting a basket to the next host has failed, 
              # but, replicating/deleting a basket to an alternative host has succeeded
              t = Time.new
              File.utime( t, t, prc )
              File.rename( prc, "#{slp}.#{alternative_host}" )
            end
          else
            # failed, somthing went wrongly
            t = Time.new
            File.utime( t, t, prc )
            File.rename( prc, slp )
          end
        rescue => e
          Log.warning e  # unintended exception
          sleep 10       # prevent the situation of out of control

        ensure
          sleep 0.010
          finished if @stop_requested
        end
      end


      class UdpReplicationInternalCommandReceiver < Worker
        def initialize( queue, port )
          @queue = queue
          @socket = ExtendedUDPSocket.new
          @socket.bind( '127.0.0.1', port )
          super
        end

        def serve
          channel = UdpServerChannel.new
          channel.receive( @socket )
          command, args = channel.parse
          basket_text = args[ 'basket' ]
          basket = nil
          basket = Basket.new_from_text( basket_text ) if basket_text
          action = nil
          case command
          when 'REPLICATE' ; action = 'replication'
          when 'DELETE'    ; action = 'delete'
          end
          if ( basket and action )
            @queue.enq "#{basket.to_s}.#{action}"
          end
        rescue => e
          Log.warn e, "#{file} #{basket.to_s}"
        end

        def graceful_stop
          finished
          super
        end
      end


      class TcpMaintenaceServer < PreThreadedTcpServer
        def initialize( port )
          super( port, '0.0.0.0', 10 )
          @config = Configurations.instance
        end

        def serve( io )
          while ( line = io.gets )
            line.chomp!
            next if line =~ /\A\s*\Z/

            program = $0.sub(/.*\//, '')

            begin
              a = line.split(' ')
              case c = a.shift.downcase
              when 'quit'
                break
              when 'help'
                io.puts( [ 
                          "quit",
                          "auto [off|auto]",
                          "mode [unknown(0)|offline(10)|readonly(20)|rep(23)|fin_rep(25)|del_rep(27)|online(30)]",
                          "debug [on|off]",
                          "reload [configration_file]",
                          "shutdown",
                          nil
                         ].join("\r\n") )

              when 'shutdown'
                #  Todo: should use graceful-stop.
                io.puts( "Shutdown is going ...\r\n" )
                Log.notice( "Shutdown is requested." )
                # Todo:
                Thread.new {
                  sleep 2
                  Process.exit 0
                }
                CrepdMain.instance.stop

              when 'health'
                io.puts( "#{ServerStatus.instance.status_name} #{($AUTO_PILOT) ? "auto" : "off"} #{($DEBUG) ? "on" : "off"}\r\n" )

              when 'mode'
                p = a.shift
#                if ( $AUTO_PILOT )
#                  if (p)
#                    io.puts( "run mode cannot be manually altered when auto is enable.\r\n" )
#                  else
#                    x = ServerStatus.instance.status_name
#                    io.puts( "run mode: #{x}\r\n" )
#                  end
#                else
                if (p)
                  p.downcase!
                  ServerStatus.instance.status_name = p
                end
                x = ServerStatus.instance.status_name
                io.puts( "run mode: #{x}\r\n" )
#                end

              when '_mode'
                p = a.shift
                if ( $AUTO_PILOT )
                  if (p)
                    p.downcase!
                    ServerStatus.instance.status_name = p
                  end
                  x = ServerStatus.instance.status_name
                  io.puts( "run mode: #{x}\r\n" )
                else
                  if (p)
                    io.puts( "run mode cannot be automatically altered when auto is disable.\r\n" )
                  else
                    x = ServerStatus.instance.status_name
                    io.puts( "run mode: #{x}\r\n" )
                  end
                end

              when 'auto'
                p = a.shift
                if (p)
                  p.downcase!
                  case (p) 
                  when 'auto' ; $AUTO_PILOT = true
                  when 'off'  ; $AUTO_PILOT = false
                  when nil  ; 
                  else raise StandardError, "400 Unknown parameter: #{p} ; auto [off|auto]"
                  end
                end
                io.puts( "auto: " + ( ($AUTO_PILOT) ? "auto" : "off")  + "\r\n" )

              when 'reload'
                file = a.shift
                begin
                  # Todo:
                  # XXXWorkers.instance.stop_workers
                  entries = @config.reload( file )
                  # Todo:
                  # XXXWorkers.instance.start_workers
                  io.puts( "#{entries.inspect}\r\n" )
                rescue => e
                  io.puts( "#{e.class} - #{e.message}" )
                end

              when 'debug'
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

              else
                raise StandardError, "400 Unknown command: #{c} ; try help command"
              end
            rescue StandardError => e
              io.puts( "#{e.message}\r\n" )
            rescue => e
              io.puts( "500 Internal Server Error: #{e.class} #{e.message}\r\n" )
            end
          end
        end
      end

    end
  end
end

