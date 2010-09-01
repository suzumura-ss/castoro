
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

require 'castoro-peer/basket'
require 'castoro-peer/pre_threaded_tcp_server'
require 'castoro-peer/worker'
require 'castoro-peer/ticket'
require 'castoro-peer/database'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/channel'
require 'castoro-peer/manupulator'
require 'castoro-peer/log'
require 'castoro-peer/pipeline'
require 'castoro-peer/storage_servers'
require 'castoro-peer/server_status'
require 'castoro-peer/maintenace_server'

module Castoro
  module Peer

    $AUTO_PILOT = true

    # Todo: This could be moved to the configuration; this is also written in crepd_worker.rb
    DIR_REPLICATION = "/var/castoro/replication"
    DIR_WAITING     = "#{DIR_REPLICATION}/waiting"

########################################################################
# Tickets
########################################################################

    class CommandReceiverTicket < Ticket
      attr_accessor :socket, :channel, :command, :command_sym, :args, :basket, :host, :message
    end

    class CommandSenderTicket < Ticket
    end

########################################################################
# Ticket Pools
########################################################################

    class CommandReceiverTicketPool < SingletonTicketPool
      def fullname; 'Command receiver ticket pool' ; end
      def nickname; 'ctp' ; end

      def create_ticket
        super( CommandReceiverTicket )
      end
    end

#    class RegularCommandReceiverTicketPool < SingletonTicketPool
#      def fullname; 'Regular command receiver ticket pool' ; end
#      def nickname; 'rcr' ; end
#
#      def create_ticket
#        super( CommandReceiverTicket )
#      end
#    end

#    class ExpressCommandReceiverTicketPool < RegularCommandReceiverTicketPool
#      def fullname; 'Express command receiver ticket pool' ; end
#      def nickname; 'ecr' ; end
#    end

    class MulticastCommandSenderTicketPool < SingletonTicketPool
      def fullname; 'Multicast command sender ticket pool' ; end
      def nickname; 'mtp' ; end

      def create_ticket
        super( CommandSenderTicket )
      end
    end

########################################################################
# Pipelines
########################################################################

    class RegularCommandReceiverPL < SingletonPipeline
      def fullname; 'Regular command receiver pipeline' ; end
      def nickname; 'rc' ; end
    end

    class ExpressCommandReceiverPL < SingletonPipeline
      def fullname; 'Express command receiver pipeline' ; end
      def nickname; 'ec' ; end
    end

    class TcpAcceptorPL < SingletonPipeline
      def fullname; 'TCP acceptor pipeline' ; end
      def nickname; 'ta' ; end
    end

    # Todo: this could be shared with other DatabasePLs
    class BasketStatusQueryDatabasePL  < SingletonPipeline
      def fullname; 'Basket status query database pipeline' ; end
      def nickname; 'bs' ; end
    end

    class CsmControllerPL < SingletonPipeline
      def fullname; 'Storage manupulator pipeline' ; end
      def nickname; 'sm' ; end
    end

    class MulticastCommandSenderPL < SingletonPipeline
      def fullname; 'Multicast command sender pipeline' ; end
      def nickname; 'ms' ; end
    end

    class ResponseSenderPL  # This class is a delegator class
      include Singleton

      def enq( ticket )
        if ( ticket.channel.tcp? )
          TcpResponseSenderPL.instance.enq ticket
        else
          UdpResponseSenderPL.instance.enq ticket
        end
      end
    end

    class TcpResponseSenderPL < SingletonPipeline
      def fullname; 'TCP response sender pipeline' ; end
      def nickname; 'tr' ; end
    end

    class UdpResponseSenderPL < SingletonPipeline
      def fullname; 'UDP response sender pipeline' ; end
      def nickname; 'ur' ; end
    end

    class ReplicationPL < SingletonPipeline
      def fullname; 'Replication request pipeline' ; end
      def nickname; 're' ; end
    end

########################################################################
# Controller of the front end workers
########################################################################

    class CpeerdWorkers
      include Singleton

      STATISTICS_TARGETS = [
                            CommandReceiverTicketPool,
                            MulticastCommandSenderTicketPool,
                            RegularCommandReceiverPL,
                            ExpressCommandReceiverPL,
                            BasketStatusQueryDatabasePL,
                            CsmControllerPL,
                            MulticastCommandSenderPL,
                            TcpResponseSenderPL,
                            UdpResponseSenderPL,
                            ReplicationPL,
                           ]

      def initialize
        c = Configurations.instance
        @w = []
#        @w << AlivePacketSender.new( PRIORITY_7, c.MulticastAddress, c.WatchDogCommandPort )
        @w << UdpCommandReceiver.new( PRIORITY_7, ExpressCommandReceiverPL.instance, c.PeerMulticastUDPCommandPort )
        @w << UdpCommandReceiver.new( PRIORITY_7, ExpressCommandReceiverPL.instance, c.PeerUnicastUDPCommandPort )
        @w << UdpCommandReceiver.new( PRIORITY_7, RegularCommandReceiverPL.instance, c.GatewayUDPCommandPort )
        @w << UdpCommandReceiver.new( PRIORITY_7, RegularCommandReceiverPL.instance, c.WatchDogCommandPort )
        @w << TcpCommandAcceptor.new( PRIORITY_7, TcpAcceptorPL.instance, c.PeerTCPCommandPort )
        5.times { @w << TcpCommandReceiver.new( PRIORITY_7, TcpAcceptorPL.instance, RegularCommandReceiverPL.instance ) }
        c.NumberOfExpressCommandProcessor.times   { @w << CommandProcessor.new( PRIORITY_7, ExpressCommandReceiverPL.instance ) }
        c.NumberOfRegularCommandProcessor.times   { @w << CommandProcessor.new( PRIORITY_7, RegularCommandReceiverPL.instance ) }
        c.NumberOfBasketStatusQueryDB.times { @w << BasketStatusQueryDB.new( PRIORITY_7 ) }
        c.NumberOfCsmController.times      { @w << CsmController.new( PRIORITY_7 ) }
        c.NumberOfUdpResponseSender.times  { @w << UdpResponseSender.new( PRIORITY_7, UdpResponseSenderPL.instance ) }
        c.NumberOfTcpResponseSender.times  { @w << TcpResponseSender.new( PRIORITY_7, TcpResponseSenderPL.instance ) }
        c.NumberOfMulticastCommandSender.times { @w << MulticastCommandSender.new( PRIORITY_7, c.MulticastAddress, c.GatewayUDPCommandPort ) }
        c.NumberOfReplicationDBClient.times  { @w << ReplicationDBClient.new( PRIORITY_7 ) }
        @w << StatisticsLogger.new( PRIORITY_7 )
        @m = TcpMaintenaceServer.new( PRIORITY_7, c.CpeerdMaintenancePort )
        @h = TCPHealthCheckPatientServer.new( PRIORITY_7, c.CpeerdHealthCheckPort )
      end

      def start_workers
        @w.reverse_each { |w| w.start }
      end

      def stop_workers
        @w.each { |w|
#          p [ 'stop_workers', w ]
          w.graceful_stop
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
   # Command receiver workers
   ########################################################################

      class UdpCommandReceiver < Worker
        def initialize( priority, pipeline, port )
          @pipeline = pipeline
          @socket = ExtendedUDPSocket.new
          @socket.bind( Configurations.instance.MulticastAddress, port )
          super
        end

        def serve
          channel = UdpServerChannel.new
          ticket = CommandReceiverTicketPool.instance.create_ticket
          channel.receive( @socket, ticket )
          ticket.channel = channel
          ticket.socket = nil
          ticket.mark
          @pipeline.enq ticket
        end

        def graceful_stop
          finished
          super
        end
      end


      class TcpCommandAcceptor < Worker
        def initialize( priority, pipeline, port )
          @pipeline = pipeline
          sockaddr = Socket.pack_sockaddr_in( port, '0.0.0.0' )
          @socket = Socket.new( Socket::AF_INET, Socket::SOCK_STREAM, 0 )
          @socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true )
          @socket.setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
          @socket.do_not_reverse_lookup = true
          @socket.bind( sockaddr )
          @socket.listen( 10 )
          super
        end

        def serve
          begin
            client_socket, client_sockaddr = @socket.accept
            @pipeline.enq client_socket
          rescue IOError => e
            return if e.message.match( /closed stream/ )
            Log.warning e
          rescue Errno::EBADF => e
            return if e.message.match( /Bad file number/ )
            Log.warning e
          rescue => e
            Log.warning e
          end
        end

        def graceful_stop
          @socket.close if @socket
          finished
          super
        end
      end


      class TcpCommandReceiver < Worker
        def initialize( priority, pipeline1, pipeline2 )
          @pipeline1 = pipeline1
          @pipeline2 = pipeline2
          super
        end

        def serve
          client = @pipeline1.deq
          if ( client.nil? )
            @finished = true
            return
          end
          loop do
            ticket = CommandReceiverTicketPool.instance.create_ticket
            channel = TcpServerChannel.new
            channel.receive( client, ticket )
            if ( channel.closed? )
              CommandReceiverTicketPool.instance.delete( ticket )
              return
            end
            ticket.channel = channel
            ticket.socket = client
            ticket.mark
            @pipeline2.enq ticket
          end
        end

        def graceful_stop
          # Todo: who will receive this 'nil'?
          @pipeline1.enq nil
          super
        end
      end


      class CommandProcessor < Worker
        def initialize( priority, pipeline )
          @pipeline = pipeline
          super
          @config = Configurations.instance
        end

        def serve
          ticket = @pipeline.deq
          ticket.mark
          command, args = ticket.channel.parse
          basket_text = args[ 'basket' ]
          # Todo: basket_text.nil? and raise an exception
          basket = Basket.new_from_text( basket_text ) if basket_text
          ticket.command, ticket.args, ticket.basket = command, args, basket
          ticket.host = @config.HostnameForClient
          command_sym = nil
          case command
          when 'GET'
            path_a = basket.path_a
            if ( File.exist? path_a )
              basket_text = basket.to_s
              ticket.push Hash[ 'basket', basket_text, 'paths', { ticket.host => path_a } ]
              ResponseSenderPL.instance.enq ticket
              t = MulticastCommandSenderTicketPool.instance.create_ticket
              t.push( 'INSERT', Hash[ 'basket', basket_text, 'host', ticket.host, 'path', path_a ] )
              MulticastCommandSenderPL.instance.enq t
            else
              ticket.mark
              if ( ticket.channel.tcp? )
                raise NotFoundError, path_a 
              else
                ticket.finish
                Log.debug( "Get received, but not found: #{basket_text}" ) if $DEBUG
                #########
                ####  basket id is required
                #########
                Log.debug( sprintf( "%s %.1fms [%s] %s is not found", ticket.command.slice(0,3), ticket.duration * 1000, 
                                    ( ticket.durations.map { |x| "%.1f" % (x * 1000) } ).join(', '), basket_text ) ) if $DEBUG
                CommandReceiverTicketPool.instance.delete( ticket )
              end
            end
          when 'NOP'
            ticket.push Hash[]
            ResponseSenderPL.instance.enq ticket
          when 'INSERT'
            # Todo: insert the entry into the database
          when 'DROP'
            # Todo: drop the entry from the database
          when 'ALIVE'
            # Todo: mark the host alive
          when 'CREATE'  ; command_sym = :CREATE
          when 'CLONE'   ; command_sym = :CLONE
          when 'DELETE'  ; command_sym = :DELETE
          when 'CANCEL'  ; command_sym = :CANCEL
          when 'FINALIZE'; command_sym = :FINALIZE
          else
            raise BadRequestError, "Unknown command: #{command}"
          end
          if ( command_sym )
            accept = case ServerStatus.instance.status
                     when ServerStatus::ACTIVE       ; true
                     when ServerStatus::DEL_REP      ; command_sym == :CANCEL or command_sym == :FINALIZE or command_sym == :DELETE
                     when ServerStatus::FIN_REP      ; command_sym == :CANCEL or command_sym == :FINALIZE
                     when ServerStatus::REP          ; false
                     when ServerStatus::READONLY     ; false
                     when ServerStatus::MAINTENANCE  ; false
                     when ServerStatus::UNKNOWN      ; false
                     else ; false
                     end
            if ( accept )
              ticket.command_sym = command_sym
              path_x = args[ 'path' ]
              ticket.push DbRequestQueryBasketStatus.new( basket, path_x )
              BasketStatusQueryDatabasePL.instance.enq ticket
            else
              Log.notice( "#{command_sym.to_s}: ServerStatusError server status: #{ServerStatus.instance.status_name}: #{basket}" )
              raise ServerStatusError, "server status: #{ServerStatus.instance.status_name}"
            end
          else
            # Todo:
            # INSERT, DROP, ALIVE are implemented in crepd_workers.rb
            CommandReceiverTicketPool.instance.delete( ticket )
          end
        rescue => e
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        end
      end


      class BasketStatusQueryDB < Worker
        def serve
          @config = Configurations.instance

          ticket = BasketStatusQueryDatabasePL.instance.deq
          request = ticket.pop
          # Todo: make them configurable
          @root = 'root'
          @user = 'quanp'
          status = request.execute  # an exception might be raised
          b = ticket.basket
          path_x = ticket.args[ 'path' ]
          a = case ticket.command_sym
              when :CREATE
                case status
                when S_ABCENSE
                  #CsmRequest.new( config, 'mkdir', @user, @user, '0777', b.path_w )
                  user  = @config.Dir_w_user
                  group = @config.Dir_w_group
                  perm  = @config.Dir_w_perm
                  CsmRequest.new( @config, 'mkdir', user, group, perm, b.path_w )
                else
                  reason = case status
                           when S_ABCENSE;  'Internal server error: Something goes wrongly.'
                           when S_WORKING;  b.path_w
                           when S_ARCHIVED; b.path_a
                           when S_DELETED;  b.path_d
                           else
                             raise UnknownBasketStatusInternalServerError, status
                           end
                  raise AlreadyExistsError, reason
                end
              when :CLONE
                status == S_ARCHIVED or raise NotFoundError, b.path_a
                user  = @config.Dir_w_user
                group = @config.Dir_w_group
                perm  = @config.Dir_w_perm
                CsmRequest.new( @config, 'copy', user, group, perm, b.path_a, b.path_w )
              when :DELETE
                status == S_ARCHIVED or raise NotFoundError, b.path_a
                user  = @config.Dir_d_user
                group = @config.Dir_d_group
                perm  = @config.Dir_d_perm
                CsmRequest.new( @config, 'mv', user, group, perm, b.path_a, b.path_d )
              when :CANCEL
                case status
                when S_WORKING, :S_ABCENSE
                  File.exist? path_x or raise NotFoundError, path_x
                  user  = @config.Dir_c_user
                  group = @config.Dir_c_group
                  perm  = @config.Dir_c_perm
                  CsmRequest.new( @config, 'mv', user, group, perm, path_x, b.path_c( path_x ) )
                  #              when S_ARCHIVED
                  #                CsmRequest.new( @config, 'mv', @root, @user, '0555', b.path_a, b.path_d )
                else
                  reason = case status
                           when S_ABCENSE;  'The basket does not exist.'
                           when S_WORKING;  'Something goes wrongly.'
                           when S_ARCHIVED; "The basket has been already finilized: #{b.path_a}"
                           when S_DELETED;  "The basket has been already deleted: #{b.path_d}"
                           else
                             raise UnknownBasketStatusInternalServerError, status
                           end
                  raise PreconditionFailedError, reason
                end
              when :FINALIZE, :S_ABCENSE
                # status == S_WORKING or raise PreconditionFailedError, path_x
                File.exist? path_x or raise NotFoundError, path_x
                user  = @config.Dir_a_user
                group = @config.Dir_a_group
                perm  = @config.Dir_a_perm
                CsmRequest.new( @config, 'mv', user, group, perm, path_x, b.path_a )
              else
                raise InternalServerError, "Unknown command symbol' #{ticket.command_sym.inspect}"
              end
          ticket.push a
          CsmControllerPL.instance.enq ticket

        rescue NotFoundError => e
          t = MulticastCommandSenderTicketPool.instance.create_ticket
          t.push( 'DROP', Hash[ 'basket', b.to_s, 'host', ticket.host, 'path', b.path_a ] )
          MulticastCommandSenderPL.instance.enq t
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        rescue => e
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        end
      end

      class CsmController < Worker
        def serve
          ticket = CsmControllerPL.instance.deq
          ticket.mark
          request = ticket.pop
          result = request.execute
          ticket.mark
          basket = ticket.basket
          h = { 'basket' => basket.to_s }
          case ticket.command_sym
          when :CREATE
            m = "CREATE: #{basket} #{basket.path_w}"
            h.merge! Hash[ 'host', ticket.host, 'path', basket.path_w ]
          when :CLONE
            m = "CLONE: #{basket} #{basket.path_w}"
            h.merge! Hash[ 'host', ticket.host, 'path', basket.path_w ]
          when :DELETE
            m = "DELETE: #{basket} #{basket.path_d}"
            t = MulticastCommandSenderTicketPool.instance.create_ticket
            t.push( 'DROP', Hash[ 'basket', basket.to_s, 'host', ticket.host, 'path', basket.path_d ] )
            MulticastCommandSenderPL.instance.enq t
            ReplicationPL.instance.enq [ 'delete', basket ]  # Todo: should not use DB's enum here
          when :CANCEL
            m = "CANCEL: #{basket} #{basket.path_c}"
          when :FINALIZE
            m = "FINALIZE: #{basket} #{basket.path_a}"
            t = MulticastCommandSenderTicketPool.instance.create_ticket
            t.push( 'INSERT', Hash[ 'basket', basket.to_s, 'host', ticket.host, 'path', basket.path_a ] )
            MulticastCommandSenderPL.instance.enq t
            ReplicationPL.instance.enq [ 'replicate', basket ]  # Todo: should not use DB's enum here
          else
            raise InternalServerError, "Unknown command symbol' #{ticket.command_sym.inspect}"
          end
          ticket.message = m
          ticket.push h
          ResponseSenderPL.instance.enq ticket
        rescue => e
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        end
      end


      class ResponseSender < Worker
        def initialize( priority, pipeline )
          @pipeline = pipeline
          super
        end

        def serve
          ticket = @pipeline.deq
          ticket.mark
          basket = ticket.basket  # Todo: what is doing for NOP?
          basket_text = basket.to_s
          result = ticket.pop
          message = ticket.message
          socket = @socket || ticket.socket
          begin
            ticket.channel.send( socket, result )
          rescue IOError => e  # e.g. "closed stream occurred"
            Log.warning e, basket_text
          rescue => e
            Log.err e, basket_text
          end
# Todo: socket.close was written here. why does this worked?
#          socket.close if ticket.channel.tcp?
          ticket.finish
          Log.notice( sprintf( "%s %.1fms", message, ticket.duration * 1000 ) ) if message
          command = ticket.command
          Log.debug( sprintf( "%s %.1fms [%s] %s", ticket.command.slice(0,3), ticket.duration * 1000, 
                              ( ticket.durations.map { |x| "%.1f" % (x * 1000) } ).join(', '), basket_text ) ) if $DEBUG
        ensure
          CommandReceiverTicketPool.instance.delete( ticket ) if ticket
        end
      end

      class UdpResponseSender < ResponseSender
        def initialize( priority, pipeline )
          @socket = ExtendedUDPSocket.new
          super
        end
      end


      class TcpResponseSender < ResponseSender
        def initialize( priority, pipeline )
          @socket = nil
          super
        end
      end


      class MulticastCommandSender < Worker
        def initialize( priority, ip, port )
          @channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
          @ip, @port = ip, port
          super
        end

        def serve
          ticket = MulticastCommandSenderPL.instance.deq
          command, args = ticket.pop2
          @channel.send( command, args, @ip, @port )
          MulticastCommandSenderTicketPool.instance.delete( ticket )
        end
      end


      class ReplicationDBClient < Worker
        def initialize( priority )
          Dir.exists? DIR_WAITING or raise StandardError, "no directory exists: #{DIR_WAITING}"
          super
          @config = Configurations.instance
          @ip = '127.0.0.1'
          @port = @config.ReplicationUDPCommandPort
          @channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
        end

        def serve
          action, basket = ReplicationPL.instance.deq
          begin
            file = "#{DIR_WAITING}/#{basket.to_s}.#{action}"
            f = File.new( file, "w" )
            f.close
          rescue => e
            Log.warn e, "#{file} #{basket.to_s}"
          end

          begin
            args = Hash[ 'basket', basket.to_s ]
            case action
            when 'replicate' ; @channel.send( 'REPLICATE', args, @ip, @port )
            when 'delete'    ; @channel.send( 'DELETE',    args, @ip, @port )
            end
          rescue => e
            Log.warn e, "#{action} #{basket.to_s}"
          end
        end
      end


      class TcpMaintenaceServer < PreThreadedTcpServer
        def initialize( priority, port )
          super( port, '0.0.0.0', 10, priority )
          @config = Configurations.instance
        end

        def serve( io )
          while ( line = io.gets )
            line.chomp!
            next if line =~ /\A\s*\Z/

            program = $0.sub(/.*\//, '')
            host = @config.HostnameForClient

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
                          "stat [-s] [period] [count]", 
                          "dump",
                          "inspect",
                          "gc_profiler [off|on|report]",
                          "gc [start|count]",
                          "version",
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
                # Todo:
                CpeerdMain.instance.stop

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
                  # CpeerdWorkers.instance.stop_workers
                  entries = @config.reload( file )
                  # Todo:
                  # CpeerdWorkers.instance.start_workers
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
                #            when 'stop'
                #              Main.instance.stop
                #            when 'start'
                #              Main.instance.start
              when 'dump'
                t = Time.new
                crlf = "\r\n"
                a = STATISTICS_TARGETS.map { |s| x = s.instance; sprintf( "  (%-3s) %-40s\r\n%s", x.nickname, x.fullname, x.dump.join(crlf) ) }
                io.puts "#{t.iso8601}.#{t.usec} #{host} #{program}\r\n#{a.join("\r\n\r\n")}\r\n\r\n"

              when 'inspect'
                t = Time.new
                io.write "#{t.iso8601}.#{t.usec} #{host} #{program} ObjectSpace.each_object:\n"
#                last_status_of_profiler = GC::Profiler.enabled?
#                GC::Profiler.enable

                # rb_garbage_collect() is already called in os_obj_of() for ObjectSpace.each_object()
                # So, no neccesary to call GC.start here
#                GC.start

#                GC::Profiler.report(io)
#                io.write "\n"
#                ObjectSpace.each_object(Object) { |x|
                count = 0
                ObjectSpace.each_object { |x|
                  begin
                    io.write "#{"0x%08x" % x.object_id}\t#{x.class}\t#{x.inspect}\n"
                  rescue NotImplementedError => e
                    io.write "#{e}\n"
                  end
                  count = count + 1
                }
                io.write "The number of objects including NotImplementedError: #{count}\n"
#                GC::Profiler.report(io)
#                io.write "\n"
#                if ( last_status_of_profiler )
#                  GC::Profiler.enable
#                else
#                  GC::Profiler.disable
#                end

              when 'gc_profiler'
                t = Time.new
                x = a.shift
                if (x)
                  x.downcase!
                  case (x) 
                  when 'off'    ; GC::Profiler.disable
                  when 'on'     ; GC::Profiler.enable
                  when 'report'
                    io.write( "#{t.iso8601}.#{t.usec} #{host} #{program} GC::Profiler.report:\r\n" )
                    GC::Profiler.report(io)
                  when nil  ; 
                  else raise StandardError, "400 Unknown parameter: #{x} ; gc_profiler [off|on|report]"
                  end
                end
                io.write( "#{t.iso8601}.#{t.usec} #{host} #{program} gc_profiler: " + ( (GC::Profiler.enabled?) ? "on" : "off")  + "\r\n" )

                when 'gc'
                t = Time.new
                x = a.shift
                if (x)
                  x.downcase!
                  case (x) 
                  when 'start'
                    t1 = Time.new
                    GC.start
                    t2 = Time.new
                    io.write( "#{t.iso8601}.#{t.usec} #{host} #{program} GC finished: #{"%.1fms" % (t2 - t1)}\n" )
                  when 'count'
                    io.write( "#{t.iso8601}.#{t.usec} #{host} #{program} GC.count: #{GC.count}\n" )
                  else
                    raise StandardError, "400 Unknown parameter: #{x} ; gc [start|count]"
                  end
                else
                  io.write( "Usage: gc [start|count]\n" )
                end

              when 'version'
                t = Time.new
                io.write( "#{t.iso8601}.#{t.usec} #{host} #{program} Version: #{PROGRAM_VERSION}\r\n" )

              when 'stat'
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
                    a = STATISTICS_TARGETS.map { |s| x = s.instance; "#{x.nickname}=#{x.size}" }
                    io.puts "#{t.iso8601}.#{t.usec} #{host} #{program} #{a.join(' ')}"
                  else
                    a = STATISTICS_TARGETS.map { |s| x = s.instance; sprintf( "  (%-3s) %-40s %d", x.nickname, x.fullname, x.size ) }
                    crlf = "\r\n"
                    io.puts "#{t.iso8601}.#{t.usec} #{host} #{program}\r\n#{a.join(crlf)}\r\n\r\n"
                  end
                  sleep opt_period unless opt_period.nil?
                  opt_count = opt_count - 1
                end
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


      class StatisticsLogger < Worker
        def initialize( priority )
          super
          @config = Configurations.instance
        end

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

