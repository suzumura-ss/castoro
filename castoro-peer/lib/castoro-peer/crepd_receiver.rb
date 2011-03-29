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
require 'thread'
require 'socket'
require 'json'

require 'castoro-peer/configurations'
require 'castoro-peer/basket'
require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/log'
require 'castoro-peer/manipulator'
require 'castoro-peer/server_status'
require 'castoro-peer/scheduler'

module Castoro
  module Peer
    
    class TCPReplicationServer < PreThreadedTcpServer
      def initialize( port = Configurations.instance.ReplicationTCPCommunicationPort, host = '0.0.0.0', maxConnections = 20  )
        super
      end

      def serve( io )
        channel = TcpServerChannel.new
        processor = ReplicationReceiverImplementation.new( channel, io )
        begin
          processor.run
        rescue => e
          Log.warning e
          channel.send( io, e )
        end
      end
    end

    class ReplicationReceiverImplementation
      def initialize( channel, io )
        @config = Configurations.instance

        @channel, @io = channel, io
        @directory_entries = []
        @basket = nil
        @dst = nil
        @csm_executor = Csm.create_executor
      end

      def run
        while true
          @channel.receive( @io )
          break if @channel.closed?
          @command, @args = @channel.parse
          @ip, @port = @channel.get_peeraddr
          @command.upcase!
          ret = nil

          MaintenaceServerSingletonScheduler.instance.check_point

          begin

            accept = case ServerStatus.instance.status
                     when ServerStatus::ACTIVE       ; true
                     when ServerStatus::DEL_REP      ; true
                     when ServerStatus::FIN_REP      ; true
                     when ServerStatus::REP          ; true
                     when ServerStatus::READONLY     ; false
                     when ServerStatus::MAINTENANCE  ; false
                     when ServerStatus::UNKNOWN      ; false
                     else ; false
                     end
            unless ( accept )
              raise RetryableError, "server status: #{ServerStatus.instance.status} #{ServerStatus.instance.status_name} for #{@basket}"
            end

            case @command
            when 'NOP'
              #
            when 'CATCH'
              @number_of_dirs  = 0
              @number_of_files = 0
              @total_file_size = 0
              @started_time = Time.new
              ret = process_catch_command
            when 'DELETE'
              ret = process_delete_command
              # Todo: too ugry
              if ( ret.nil? )
                send_drop_multicast_packet
                insert_replication_candidate( 'delete' )
              end
            when 'DIRECTORY'
              process_directory_command
            when 'FILE'
              process_file_command
            when 'DATA'
              process_data_command
            when 'END'
              process_end_command
            when 'CANCEL'
              process_cancel_command
            when 'PREPARE'
              # Todo: implement this
            when 'FINALIZE'
              process_finalize_command
              send_insert_multicast_packet
              insert_replication_candidate( 'replicate' )
            else
              raise InvalidArgumentPermanentError, "Unknown command:"
            end
            if ( ret )
              @channel.send( @io, ret )
            else
              @channel.send( @io, @args )
            end

          rescue AlreadyExistsPermanentError => e
            Log.warning e, "#{@command} #{@args.inspect} from #{@ip}:#{@port}"
            @channel.send( @io, e )
          rescue InvalidArgumentPermanentError => e
            Log.warning e, "#{@command} #{@args.inspect} from #{@ip}:#{@port}"
            @channel.send( @io, e )
          rescue => e
            Log.warning e, "from #{@ip}:#{@port}"
            @channel.send( @io, e )
          end
        end
      end

      def process_catch_command
        @dst.close if @dst and not @dst.closed?
        begin
          basket_text = @args[ 'basket' ] or raise PermanentError
          @basket = Basket.new_from_text( basket_text )
        rescue => e
          raise InvalidArgumentPermanentError, "#{e.class} #{e.message}: Invalid basket: #{basket_text} ;"
        end

        Log.debug( "CATCH: #{@basket} #{@path_r} from #{@ip}:#{@port}" )

        @path_a = @basket.path_a
        if ( File.exist? @path_a )
            return Hash[ :exists => @path_a ]
        end

        begin
          @path_r = @basket.path_r
        rescue => e
          raise RetryableError, "#{e.class} #{e.message} for #{@basket}"
        end

        # Has to confirm if its parent directory exists
        # If not, should create it before proceeding

        csm_request = Csm::Request::Catch.new( @path_r )
        begin
          @csm_executor.execute( csm_request )
        rescue => e
          raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r}"
        end
        return nil
      end

      def process_delete_command
        @dst.close if @dst and not @dst.closed?
        begin
          basket_text = @args[ 'basket' ] or raise PermanentError
          @basket = Basket.new_from_text( basket_text )
        rescue => e
          raise InvalidArgumentPermanentError, "#{e.class} #{e.message}: Invalid basket: #{basket_text} ;"
        end

        @path_a = @basket.path_a
        @path_d = @basket.path_d
        Log.debug( "DELETE: #{@basket} #{@path_d} from #{@ip}:#{@port}" )

        unless ( File.exist? @path_a )
          return Hash[ :doesnot_exist => @path_a ]
        end

        csm_request = Csm::Request::Delete.new( @path_a, @path_d )
        begin
          @csm_executor.execute( csm_request )
        rescue => e
          raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_a}"
        end

        Log.notice( "DELETED: #{@basket} #{@path_a} from #{@ip}:#{@port}; moved to #{@path_d}")
        return nil
      end

      def process_directory_command
        @dst.close if @dst and not @dst.closed?
        path = @args[ 'path' ] or raise InvalidArgumentPermanentError, "path is not given: #{@basket} ;"
        absolute_path = "#{@path_r}/#{path}"
        Log.debug( "DIRECTORY: #{@basket} #{absolute_path} from #{@ip}:#{@port}" )

        unless ( path == '.' )
          begin
            Dir.mkdir( absolute_path, 0755 )
          rescue => e
            raise PermanentError, "#{e.class} #{e.message}: mkdir #{absolute_path} for #{@basket}"
          end
        end
        @directory_entries.push @args
        @number_of_dirs = @number_of_dirs + 1
      end

      def process_file_command
        @dst.close if @dst and not @dst.closed?
        path = @args[ 'path' ] or raise InvalidArgumentPermanentError, "path is not given: #{@basket} ;"
        @file_path = "#{@path_r}/#{path}"
        Log.debug( "FILE: #{@basket} #{@file_path} from #{@ip}:#{@port}" )
        @dst = File.new( @file_path, "w" )
        # @dst will be closed in the method process_data_command
        size = @args[ 'size' ].to_i
        @mode  = @args[ 'mode' ].to_i
        @atime = @args[ 'atime' ].to_i
        @mtime = @args[ 'mtime' ].to_i
        @number_of_files = @number_of_files + 1
      end

      def process_data_command
        # @dst should be kept open here, which should be already opened 
        # in the method process_file_command
        size = @args[ 'size' ].to_i
        sending_size = size
        unit_size = @config.ReplicationTransmissionDataUnitSize
        while ( 0 < size )
          MaintenaceServerSingletonScheduler.instance.check_point
          n = ( unit_size < size ) ? unit_size : size
          m = IO.copy_stream( @io, @dst, n )
          size = size - m
        end
        @dst.close if @dst and not @dst.closed?
        MaintenaceServerSingletonScheduler.instance.check_point
        File.utime( @atime, @mtime, @file_path )
        File.chmod( @mode, @file_path )
        receiving_size = File.size( @file_path )
        unless ( receiving_size == sending_size )
          raise RetryableError, "File size does not match: sending_size=#{sending_size} receiving_size=#{receiving_size} #{@file_path} #{@basket}"
        end
        @total_file_size = @total_file_size + receiving_size
      end

      def process_end_command
        @dst.close if @dst and not @dst.closed?
        @directory_entries.reverse.each { |h|
          path = h[ 'path' ]
          mode = h[ 'mode' ].to_i
          atime = h[ 'atime' ].to_i
          mtime = h[ 'mtime' ].to_i
          absolute_path = "#{@path_r}/#{path}"
          Log.debug( "END: #{@basket} #{absolute_path} mode: #{mode} atime: #{atime} mtime: #{mtime} from #{@ip}:#{@port}" )
          File.utime( atime, mtime, absolute_path )
          File.chmod( mode, absolute_path )
        }
      end

      def process_cancel_command
        @dst.close if @dst and not @dst.closed?
        if ( File.exist? @path_r )
          csm_request = Csm::Request::Cancel.new( @path_r, @basket.path_c( @path_r ) )
          begin
            @csm_executor.execute( csm_request )
          rescue => e
            raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r} #{@path_a}"
          end
        end
        Log.notice( "CANCELD: #{@basket} #{@path_r} from #{@ip}:#{@port}" )
      end

      def process_finalize_command
        @dst.close if @dst and not @dst.closed?
        if ( File.exist? @path_a )
          raise AlreadyExistsPermanentError, "Basket already exists: #{@basket} #{@path_a}"
        end
        csm_request = Csm::Request::Finalize.new( @path_r, @path_a )
        begin
          @csm_executor.execute( csm_request )
        rescue => e
          raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r} #{@path_a}"
        end
        @elapsed_time = Time.new - @started_time
        Log.notice( "REPLICATED: #{@basket} #{@basket.path_a} from #{@ip}:#{@port} dirs=#{@number_of_dirs} files=#{@number_of_files} bytes=#{@total_file_size} time=#{"%0.3fs" % @elapsed_time}" )
      end

      def send_insert_multicast_packet
        # Todo: codes regarding multicast could be enhanced
        channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
        host = @config.HostnameForClient
        ip   = @config.MulticastAddress
        port = @config.GatewayUDPCommandPort
        args = Hash[ 'basket', @basket.to_s, 'host', host, 'path', @path_a ]
        channel.send( 'INSERT', args, ip, port )
      end

      def send_drop_multicast_packet
        # Todo: codes regarding multicast could be enhanced
        channel = UdpMulticastClientChannel.new( ExtendedUDPSocket.new )
        host = @config.HostnameForClient
        ip   = @config.MulticastAddress
        port = @config.GatewayUDPCommandPort
        args = Hash[ 'basket', @basket.to_s, 'host', host, 'path', @path_d ]
        channel.send( 'DROP', args, ip, port )
      end

      def insert_replication_candidate( action )
        a = action
        begin
          file = "#{DIR_WAITING}/#{@basket.to_s}.#{action}"
          f = File.new( file, "w" )
          f.close
        rescue => e
          Log.warning e, "#{file} #{@basket.to_s}"
        end
        queue = $ReplicationSenderQueue
        if ( queue )
          queue.enq "#{@basket.to_s}.#{action}"
        end
      end

    end

  end
end
