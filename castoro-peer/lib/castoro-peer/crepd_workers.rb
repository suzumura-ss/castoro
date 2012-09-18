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

require 'castoro-peer/log'
require 'castoro-peer/basket'
require 'castoro-peer/configurations'
require 'castoro-peer/worker'
require 'castoro-peer/pre_threaded_tcp_server'
require 'castoro-peer/maintenace_server'
require 'castoro-peer/server_status'
require 'castoro-peer/storage_servers'
require 'castoro-peer/scheduler'
require 'castoro-peer/pipeline'
require 'castoro-peer/crepd_queue'
require 'castoro-peer/crepd_sender'
require 'castoro-peer/crepd_receiver'

module Castoro
  module Peer

    $AUTO_PILOT = true

    class ReplicationWorkers
      def initialize
        c = Configurations.instance
        Basket.setup c.type_id_rangesHash, c.basket_basedir
        @w = []
        @w << ReplicationInternalCommandReceiver.new( c.crepd_registration_udpport )
        @w << ReplicationQueueDirectoriesMonitor.new
        @w << ReplicationReceiveServer.new
        c.crepd_number_of_replication_sender.times { @w << ReplicationSenderManager.new }
        @m = CrepdTcpMaintenaceServer.new( c.crepd_maintenance_tcpport )
        @h = TCPHealthCheckPatientServer.new( c.crepd_healthcheck_tcpport )
      end

      def start_workers
        @m.start
        @h.start
        @w.reverse_each { |w| w.start }
      end

      def stop_workers
        @w.each do |w|
          Thread.new { w.graceful_stop }  # Todo: this code is somewhat unusual
        end
        @m.graceful_stop
        @h.graceful_stop
      end
    end


    class ReplicationQueueDirectoriesMonitor < Worker
      def serve
        if ( ServerStatus.instance.replication_activated? )
          sleep 3 unless ReplicationQueueDirectories.instance.changed?
          ReplicationQueueDirectories.instance.fillup( ReplicationQueue.instance )
        else
          sleep 3
        end
      rescue => e
        Log.warning e
        sleep 10
      end
    end


    class ReplicationSenderManager < Worker
      def serve
        if ( ServerStatus.instance.replication_activated? )
          work
        else
          sleep 3
        end
      rescue => e
        Log.warning e  # unintended exception
        sleep 10       # prevent the deamon from being out of control
      ensure
        sleep 0.010
        finished if @stop_requested
      end

      def work
        entry = ReplicationQueue.instance.deq
        ReplicationQueueDirectories.instance.acquire( entry ) or return
        entry.read
        entry.append_myself
        sender = FailoverableReplicationSender.new( entry )
        sender.initiate
        x = ReplicationQueueDirectories.instance
        case sender.status
        when :success  ; x.release( entry )
        when :failover ; x.move_to_sleep( entry, sender.alternative )
        when :failure  ; x.move_to_sleep( entry, nil )
        else           ; raise PermanentError, "Unknown status: #{sender.status} #{entry.basket}"
        end
      end
    end


    class FailoverableReplicationSender
      attr_reader :alternative

      def initialize( entry )
        @entry = entry
        @done = nil
      end

      def status
        if ( @done )
          if ( @alternative )
            # an attempt of replicating/deleting the basket to the next host has failed, 
            # however, replicating/deleting the basket to an alternative host has succeeded
            :failover 
          else
            # replication or deletion of the basket to the next host successfully finished,
            # or no action was demaned.
            :success
          end
        else
          # failed, somthing went wrong
          :failure
        end
      end

      def initiate
        host = StorageServers.instance.target
        candidates = ( @entry.alternative ) ? [] : StorageServers.instance.alternative_hosts.dup

        begin
          sender = ReplicationSender.new( @entry, host )
          sender.initiate
          @done = true

        rescue NotFoundError, StillExistsError => e
          Log.warning e
          @done = true

        rescue RetryableError => e
          Log.warning e
          host = @alternative = candidates.shift
          retry if host  # failover
          @done = false  # no candidate is available.

        rescue AlreadyExistsPermanentError => e
          Log.warning e
          @done = true

        rescue InvalidArgumentPermanentError => e
          Log.err e
          @done = true

        rescue PermanentError => e
          Log.err e
          @done = true

        rescue => e
          Log.warning e
          @done = false
        end
      end
    end


    class ReplicationInternalCommandReceiver < Worker
      def initialize( port )
        @socket = ExtendedUDPSocket.new
        @socket.bind( '127.0.0.1', port )
        super
        @queue = ReplicationQueue.instance
      end

      def serve
        channel = UdpServerChannel.new @socket
        channel.receive
        command, args = channel.parse
        basket_text = args[ 'basket' ]
        if ( basket_text )
          basket = Basket.new_from_text( basket_text )
          case command
          when 'REPLICATE' ; @queue.enq ReplicationEntry.new( :basket => basket, :action => :replication )
          when 'DELETE'    ; @queue.enq ReplicationEntry.new( :basket => basket, :action => :delete )
          end
        end
      rescue => e
        Log.warning e, "#{command} #{args}"
      end

      def graceful_stop
        finished
        super
      end
    end


    class CrepdTcpMaintenaceServer < TcpMaintenaceServer
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
                       nil
                      ].join("\n") )
      end

      def do_shutdown
        # Todo:
        Thread.new {
          sleep 2
          Log.stop
          Process.exit 0
        }
        CrepdMain.instance.stop
      end
    end

  end
end

