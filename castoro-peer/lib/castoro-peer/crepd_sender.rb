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
require 'find'
require 'json'

require 'castoro-peer/log'
require 'castoro-peer/basket'
require 'castoro-peer/channel'
require 'castoro-peer/configurations'
require 'castoro-peer/scheduler'
require 'castoro-peer/extended_tcp_socket'
require 'castoro-peer/crepd_queue'

module Castoro
  module Peer

    class ReplicationSender
      def initialize( entry, host )
        @entry, @host = entry, host
        @basket = @entry.basket
        @config = Configurations.instance
        @port = @config.crepd_transmission_tcpport
        @connection = nil
      end

      def initiate
        m = case @entry.action
            when :replicate ; :replicate
            when :delete    ; :delete
            else ; raise PermanentError, "Unknown action: #{@entry.action} #{@basket}"
            end

        args = { :basket => @basket.to_s, :ttl => @entry.ttl, :hosts => @entry.hosts }
        send( m, args )  # this invokes either replicate or delete.

      ensure
        @connection.close if @connection
      end

      def connect
        @connection = Connection.new( @basket )
        @connection.connect( @host, @port )
      end

      def replicate( args )
        File.exist? @basket.path_a or
          raise NotFoundError, "No such basket exists: #{@basket} #{@basket.path_a}"

        connect

        started = Time.new
        Log.notice "Replicating #{@basket} to #{@host}:#{@port} started. #{@entry.ttl_and_hosts}"

        response = @connection.communicate( 'CATCH', args )
        if ( response.has_key? 'exists' )
          Log.notice "Replicating #{@basket} to #{@host}:#{@port} is no needed since the host already has it."
        else
          @dirs, @files, @bytes = 0, 0, 0
          transmit_directories_and_files
          elapsed = Time.new - started
          Log.notice "Replicating #{@basket} to #{@host}:#{@port} done. dirs=#{@dirs} files=#{@files} bytes=#{@bytes} time=#{"%0.3fs" % elapsed}"
        end
      end

      def transmit_directories_and_files
        a = @basket.path_a
        n = a.size
        Find.find( a ) do |path|
          filename = path[ n + 1, path.size - n ]
          transmit_item( path, filename ) if filename
        end

        @connection.communicate( 'END' )

        ReplicationQueueDirectories.instance.exists?( @entry ) or 
          raise PermanentError, "a queue file has been deleted during replication. #{@basket}"

        @connection.communicate( 'FINALIZE' )

      rescue => e
        begin
          Log.warning "Cancelling replication #{@basket} #{@host}:#{@port} reason: #{e.message}"
          @connection.communicate( 'CANCEL' )
        rescue => x
          Log.warning "Error occurred during CANCEL. #{@basket} #{@host}:#{@port} reason: #{x.message}"
        end
        raise  # raise the original exception
      end

      def transmit_item( path, filename )
        s = File.stat( path )
        args = { :path => filename, :mode => s.mode, :uid => s.uid, :gid => s.gid, :size => s.size, 
          :atime => s.atime.to_i, :mtime => s.mtime.to_i, :ctime => s.ctime.to_i }

        if FileTest.directory?( path )
          @connection.communicate( 'DIRECTORY', args )
          @dirs += 1

        elsif FileTest.file?( path )
          @connection.communicate( 'FILE', args )
          transmit_data( path, s.size )
          @files += 1
          @bytes += s.size

        else
          # Todo: what should we do for other types of entry such as a symbolic link?
        end

        t = File.stat( path )
        unless ( s.ino == t.ino and s.mtime == t.mtime and s.size == t.size )
          raise RetryableError, "#{path} modified during replication. #{@basket}"
        end
      end

      def transmit_data( path, size )
        unit_size = @config.crepd_transmission_data_unit_size

        File.open( path, 'r' ) do |src|
          @connection.send( 'DATA', { :size => size } )
          rest = size
          while ( 0 < rest )
            n = ( unit_size < rest ) ? unit_size : rest
            rest -= IO.copy_stream( src, @connection.socket, n )
            MaintenaceServerSingletonScheduler.instance.check_point
          end
        end

        @connection.receive
      end

      def delete( args )
        File.exist? @basket.path_a and
          raise StillExistsError, "Basket still exists: #{@basket} #{@basket.path_a}"

        connect

        # File.exist? @basket.path_a is not performed here intentionally.
        Log.notice "Deleting #{@basket} to #{@host}:#{@port} started. #{@entry.ttl_and_hosts}"

        response = @connection.communicate( 'DELETE', args )
        if ( response.has_key? 'doesnot_exist' )
          Log.notice "Deleting #{@basket} to #{@host}:#{@port} no needed."
        else
          Log.notice "Deleting #{@basket} to #{@host}:#{@port} done."
        end
      end
    end
    

    class Connection
      # Todo: These paramemters could be configurable.
      TIMED_OUT_FOR_CONNECTING = 10  # in seconds
      TIMED_OUT_FOR_RECEIVING  = 60  # in seconds

      attr_reader :socket

      def initialize( basket )
        @basket = basket
        @socket = nil
      end

      def connect( host, port )
        @host, @port = host, port

        begin
          @socket = ExtendedTCPSocket.new
          @socket.connect( @host, @port, TIMED_OUT_FOR_CONNECTING )
        rescue SocketError => e
          Log.warning e, "#{@host}:#{@port}"
          raise PermanentError, "#{e.message}: #{@host}:#{@port}"
        rescue => e
          Log.warning e, "#{@host}:#{@port}"
          raise RetryableError, "#{e.message}: #{@host}:#{@port}"
        end

        @channel = TcpClientChannel.new @socket
      end

      def close
        if ( @socket )
          @socket.close unless @socket.closed?
        end
      end

      def communicate( command, args = nil )
        send( command, args )
        receive
      end

      def send( command, args )
        @command = command

        begin
          @channel.send command, args
        rescue IOError => e  # e.g. "closed stream occurred"
          raise RetryableError, "#{e.class} #{e.message}, sending #{@command}: #{@basket} to #{@host}:#{@port}"
        end
      end

      def receive
        unless ( IO.select( [@socket], nil, nil, TIMED_OUT_FOR_RECEIVING ) )
          m = "Response from a remote host timed out #{TIMED_OUT_FOR_RECEIVING}s: #{@basket} to #{@host}:#{@port}"
          Log.warning m
          raise RetryableError, m
        end

        @channel.receive
        if ( @channel.closed? )
          raise RetryableError, "Connection is unexpectedly closed, waiting response of #{@command}: #{@basket} to #{@host}:#{@port}"
        end

        command, args = @channel.parse
        interpret( args ) if args
        args
      end

      def interpret( args )
        error = args[ 'error' ]
        if ( error )
          code = error[ 'code' ]
          message = error[ 'message' ]
          case code
          when 'Castoro::Peer::RetryableError'                ; raise RetryableError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::PermanentError'                ; raise PermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::AlreadyExistsPermanentError'   ; raise AlreadyExistsPermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::InvalidArgumentPermanentError' ; raise InvalidArgumentPermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          else                                                ; raise RetryableError, "#{code} #{message} ; #{@basket} to #{@host}:#{@port}"
          end
        end
      end

    end

  end
end
