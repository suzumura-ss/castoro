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

require 'castoro-peer/basket'
require 'castoro-peer/pre_threaded_tcp_server'
require 'castoro-peer/worker'
require 'castoro-peer/ticket'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/channel'
require 'castoro-peer/manipulator'
require 'castoro-peer/log'
require 'castoro-peer/pipeline'
require 'castoro-peer/storage_servers'
require 'castoro-peer/server_status'
require 'castoro-peer/maintenace_server'
require 'castoro-peer/crepd_queue'

module Castoro
  module Peer

    $AUTO_PILOT = true

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
      def fullname; 'Storage manipulator pipeline' ; end
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
        @w << UdpCommandReceiver.new( ExpressCommandReceiverPL.instance, c.PeerMulticastUDPCommandPort )
        @w << UdpCommandReceiver.new( ExpressCommandReceiverPL.instance, c.PeerUnicastUDPCommandPort )

        # Todo: neither INSERT nor DROP is interested here
        # #@w << UdpCommandReceiver.new( RegularCommandReceiverPL.instance, c.GatewayUDPCommandPort )

        # Todo: ALIVE is not interested here
        # @w << UdpCommandReceiver.new( RegularCommandReceiverPL.instance, c.WatchDogCommandPort )

        @w << TcpCommandAcceptor.new( TcpAcceptorPL.instance, c.PeerTCPCommandPort )
        5.times { @w << TcpCommandReceiver.new( TcpAcceptorPL.instance, RegularCommandReceiverPL.instance ) }
        c.NumberOfExpressCommandProcessor.times   { @w << CommandProcessor.new( ExpressCommandReceiverPL.instance ) }
        c.NumberOfRegularCommandProcessor.times   { @w << CommandProcessor.new( RegularCommandReceiverPL.instance ) }
        c.NumberOfBasketStatusQueryDB.times { @w << BasketStatusQueryDB.new() }
        c.NumberOfCsmController.times      { @w << CsmController.new() }
        c.NumberOfUdpResponseSender.times  { @w << UdpResponseSender.new( UdpResponseSenderPL.instance ) }
        c.NumberOfTcpResponseSender.times  { @w << TcpResponseSender.new( TcpResponseSenderPL.instance ) }
        c.NumberOfMulticastCommandSender.times { @w << MulticastCommandSender.new( c.MulticastAddress, c.GatewayUDPCommandPort ) }
        c.NumberOfReplicationDBClient.times  { @w << ReplicationDBClient.new() }
        @w << StatisticsLogger.new()
        @m = CpeerdTcpMaintenaceServer.new( c.CpeerdMaintenancePort )
        @h = TCPHealthCheckPatientServer.new( c.CpeerdHealthCheckPort )
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
        def initialize( pipeline, port )
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
        def initialize( pipeline, port )
          @pipeline, @port = pipeline, port
          super
          @socket = nil
        end

        def serve
          sockaddr = Socket.pack_sockaddr_in( @port, '0.0.0.0' )
          @socket.close if @socket and not @socket.closed?
          @socket = Socket.new( Socket::AF_INET, Socket::SOCK_STREAM, 0 )
          @socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true )
          @socket.setsockopt( Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true )
          @socket.do_not_reverse_lookup = true
          @socket.bind( sockaddr )
          @socket.listen( 10 )

          loop do
            client_socket = nil
            begin
              client_socket, client_sockaddr = @socket.accept
            rescue IOError, Errno::EBADF => e
              # IOError "closed stream"
              # Errno::EBADF "Bad file number"
              if ( @stop_requested )
                @finished = true
                return
              else
                raise e
              end
            end
            if ( @stop_requested )
              @socket.close if @socket and not @socket.closed?
              @finished = true
              return
            end
            @pipeline.enq client_socket
          end
        end

        def graceful_stop
          @stop_requested = true
          @socket.close if @socket
          super
        end
      end


      class TcpCommandReceiver < Worker
        def initialize( pipeline1, pipeline2 )
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
        class Ignore < Exception ; end

        @@Commands = {
          'NOP'      => :NOP,
          'GET'      => :GET,
          'CREATE'   => :CREATE,
          'CLONE'    => :CLONE,
          'DELETE'   => :DELETE,
          'CANCEL'   => :CANCEL,
          'FINALIZE' => :FINALIZE,
          'INSERT'   => :INSERT,
          'DROP'     => :DROP,
          'ALIVE'    => :ALIVE,
        }

        def initialize( pipeline )
          @pipeline = pipeline
          super
          @hostname = Configurations.instance.HostnameForClient
        end

        def serve
          ticket = @pipeline.deq
          ticket.mark
          command, args = ticket.channel.parse
          ticket.command, ticket.args, = command, args
          basket_text = args[ 'basket' ]
          basket = Basket.new_from_text( basket_text ) if basket_text
          ticket.host, ticket.basket = @hostname, basket

          command_sym = @@Commands[ command ] or raise BadRequestError, "Unknown command: #{command}"
          threshold = case command_sym
                      when :CREATE            ; ServerStatus::ONLINE
                      when :DELETE            ; ServerStatus::DEL_REP
                      when :FINALIZE, :CANCEL ; ServerStatus::FIN_REP
                      #                       ; ServerStatus::REP
                      when :GET, :NOP         ; ServerStatus::READONLY
                      else    # :INSERT, :DROP, :ALIVE, :CLONE
                        raise Ignore
                      end

          unless ServerStatus.instance.equal_or_greater_than? threshold
            Log.warning( "#{command_sym}: ServerStatusError server status: #{ServerStatus.instance.status_name}: #{basket}" )
            if command_sym == :GET and not ticket.channel.tcp? 
              raise Ignore
            else
              raise ServerStatusError, "server status: #{ServerStatus.instance.status_name}"
            end
          end

          case command_sym
          when :GET
            do_get ticket, basket, args['island']
          when :NOP
            ticket.push Hash[]
            ResponseSenderPL.instance.enq ticket
          else   # :CREATE, :DELETE, :FINALIZE, :CANCEL
            ticket.command_sym = command_sym
            BasketStatusQueryDatabasePL.instance.enq ticket
          end

        rescue Ignore
          CommandReceiverTicketPool.instance.delete( ticket )
        rescue => e
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        end

        def do_get ticket, basket, island
          path_a = basket.path_a
          if ( File.exist? path_a )
            basket_text = basket.to_s
            ticket.push Hash[ 'basket', basket_text, 'paths', { ticket.host => path_a } ].tap do |h|
              h['island'] = island if island
            end
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
        end
      end


      # Todo: BasketStatusQueryDB could be disolved into CommandProcessor
      class BasketStatusQueryDB < Worker
        def serve
          ticket = BasketStatusQueryDatabasePL.instance.deq
          b = ticket.basket
          path_x = ticket.args[ 'path' ]
          status = S_ABCENSE
          if ( File.exist?( b.path_a ) )
            status = S_ARCHIVED
          elsif ( path_x and File.exist?( path_x ) )
            status = S_WORKING
          end
          a = case ticket.command_sym
              when :CREATE
                case status
                when S_ABCENSE
                  # Has to confirm if its parent directory exists
                  # If not, should create it before proceeding
                  Csm::Request::Create.new( b.path_w )
                else
                  reason = case status
                           when S_ABCENSE;  'Internal server error: Something goes wrongly.'
                           when S_WORKING;  b.path_w
                           when S_ARCHIVED; b.path_a
                           when S_DELETED;  b.path_d  # It is okay with the same basket id being created.
                           else
                             raise UnknownBasketStatusInternalServerError, status
                           end
                  ticket.message = "CREATE failed: AlreadyExistsError: #{b} #{reason}"
                  raise AlreadyExistsError, reason
                end
              when :CLONE
                status == S_ARCHIVED or raise NotFoundError, b.path_a
                Csm::Request::Clone.new( b.path_a, b.path_w )
              when :DELETE
                status == S_ARCHIVED or raise NotFoundError, b.path_a
                Csm::Request::Delete.new( b.path_a, b.path_d )
              when :CANCEL
                case status
                when S_WORKING, :S_ABCENSE
                  File.exist? path_x or raise NotFoundError, path_x
                  Csm::Request::Cancel.new( path_x, b.path_c( path_x ) )
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
              when :FINALIZE
                case status
                when S_ARCHIVED
                  ticket.message = "FINALIZE failed: AlreadyExistsError: #{b} #{b.path_a}"
                  raise AlreadyExistsError, b.path_a
                end
                File.exist? path_x or raise NotFoundError, path_x
                Csm::Request::Finalize.new( path_x, b.path_a )
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


      # Todo: CsmController could be also disolved into CommandProcessor
      class CsmController < Worker
        def initialize
          super
          @csm_executor = Csm.create_executor
        end

        def serve
          ticket = CsmControllerPL.instance.deq
          ticket.mark
          basket = ticket.basket

          case ticket.command_sym
          when :DELETE
            ReplicationQueueDirectories.instance.delete( basket, :replicate )
          end

          csm_request = ticket.pop
          @csm_executor.execute( csm_request )
          ticket.mark
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
            ReplicationPL.instance.enq [ :delete, basket ]  # Todo: should not use DB's enum here
          when :CANCEL
            m = "CANCEL: #{basket} #{basket.path_c}"
          when :FINALIZE
            m = "FINALIZE: #{basket} #{basket.path_a}"
            t = MulticastCommandSenderTicketPool.instance.create_ticket
            t.push( 'INSERT', Hash[ 'basket', basket.to_s, 'host', ticket.host, 'path', basket.path_a ] )
            MulticastCommandSenderPL.instance.enq t
            ReplicationPL.instance.enq [ :replicate, basket ]  # Todo: should not use DB's enum here
          else
            raise InternalServerError, "Unknown command symbol' #{ticket.command_sym.inspect}"
          end
          ticket.message = m
          ticket.push h
          ResponseSenderPL.instance.enq ticket
        rescue => e
          Log.err e
          ticket.push e
          ResponseSenderPL.instance.enq ticket
        end
      end


      class ResponseSender < Worker
        def initialize( pipeline )
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
          ip, port = nil, nil
          if ( ticket.channel.tcp? )
            ip, port = ticket.channel.get_peeraddr
          else
            # Todo: should be implemented for UDP
          end
          ticket.finish
          Log.notice( sprintf( "%s %s:%d %.1fms", message, ip, port, ticket.duration * 1000 ) ) if message
          command = ticket.command
          Log.debug( sprintf( "%s %.1fms [%s] %s", ticket.command.slice(0,3), ticket.duration * 1000, 
                              ( ticket.durations.map { |x| "%.1f" % (x * 1000) } ).join(', '), basket_text ) ) if $DEBUG
        ensure
          CommandReceiverTicketPool.instance.delete( ticket ) if ticket
        end
      end

      class UdpResponseSender < ResponseSender
        def initialize( pipeline )
          @socket = ExtendedUDPSocket.new
          super
        end
      end


      class TcpResponseSender < ResponseSender
        def initialize( pipeline )
          @socket = nil
          super
        end
      end


      class MulticastCommandSender < Worker
        def initialize( ip, port )
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
        def initialize
          ReplicationQueueDirectories.instance
          super
          @ip = '127.0.0.1'
          @port = Configurations.instance.ReplicationUDPCommandPort
          @channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
        end

        def serve
          action, basket = ReplicationPL.instance.deq
          entry = ReplicationEntry.new( :basket => basket, :action => action )
          ReplicationQueueDirectories.instance.insert_without_attribute( entry )

          begin
            args = Hash[ 'basket', basket.to_s ]
            case action
            when :replicate ; @channel.send( 'REPLICATE', args, @ip, @port )
            when :delete    ; @channel.send( 'DELETE',    args, @ip, @port )
            end
          rescue => e
            Log.warning e, "#{action} #{basket}"
          end
        end
      end


      class CpeerdTcpMaintenaceServer < TcpMaintenaceServer
        def initialize( port )
          super
          @hostname = Configurations.instance.HostnameForClient
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
                         "stat [-s] [period] [count]", 
                         "dump",
                         nil
                        ].join("\n") )
        end

        def do_shutdown
          # Todo:
          Thread.new {
            sleep 2
            Process.exit 0
          }
          # Todo:
          CpeerdMain.instance.stop
        end

        def do_dump
          t = Time.new
          a = STATISTICS_TARGETS.map { |s| x = s.instance; sprintf( "  (%-3s) %-40s\n%s", x.nickname, x.fullname, x.dump.join("\n") ) }
          @io.syswrite "#{t.iso8601}.#{t.usec} #{@hostname} #{@program}\n#{a.join("\n\n")}\n\n"
        end

        def do_stat
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
              @io.syswrite "#{t.iso8601}.#{t.usec} #{@hostname} #{@program} #{a.join(' ')}\n"
            else
              a = STATISTICS_TARGETS.map { |s| x = s.instance; sprintf( "  (%-3s) %-40s %d", x.nickname, x.fullname, x.size ) }
              @io.syswrite "#{t.iso8601}.#{t.usec} #{@hostname} #{@program}\n#{a.join("\n")}\n\n"
            end
            sleep opt_period unless opt_period.nil?
            opt_count = opt_count - 1
          end
        end

      end

      class StatisticsLogger < Worker
        def initialize
          super
          @period = Configurations.instance.PeriodOfStatisticsLogger
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
            sleep @period
          end
        end
      end

    end
  end
end

