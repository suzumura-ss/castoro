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

require 'castoro-peer/configurations'
require 'castoro-peer/basket'
require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/extended_tcp_socket'
require 'castoro-peer/log'
require 'castoro-peer/scheduler'

module Castoro
  module Peer

    class ReplicationSenderImplementation
      # Todo
      TIMED_OUT_IN_SECOND = 10

      def initialize
        @config = Configurations.instance
        super
      end

      def check_error( args )
        if ( args and args.has_key? 'error' )
          details = args['error']
          code, message = details['code'], details['message']
          case code
          when 'Castoro::Peer::RetryableError'
            raise RetryableError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::PermanentError'
            raise PermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::AlreadyExistsPermanentError'
            raise AlreadyExistsPermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          when 'Castoro::Peer::InvalidArgumentPermanentError'
            raise InvalidArgumentPermanentError, "#{message} ; #{@basket} to #{@host}:#{@port}"
          else
            raise RetryableError, "#{code} - #{message} ; #{@basket} to #{@host}:#{@port}"
          end
        end
      end

      def sending( command, args )
        @command = command
        begin
          @channel.send( @socket, command, args )
        rescue IOError => e # e.g. "closed stream occurred"
          raise RetryableError, "#{e.class} \"#{e.message}\", sending #{@command}: #{@basket} to #{@host}:#{@port}"
        end
      end

      def receiving
        @channel.receive( @socket )
        if ( @channel.closed? )
          raise RetryableError, "Connection is unexpectedly closed, waiting response of #{@command}: #{@basket} to #{@host}:#{@port}"
        end
        @channel.parse
      end

      def do_replicate_command( basket, host )  # Todo: name this function more properly
        @basket = basket
        # okay to transer???
        File.exist? @basket.path_a or raise PermanentError, "Replication abandoned due to no existence of basket: #{@basket} #{@basket.path_a}"
        @number_of_dirs  = 0
        @number_of_files = 0
        @total_file_size = 0
        @started_time = Time.new
        @host = host
        @port = @config.ReplicationTCPCommunicationPort
        Log.notice( "Replicating #{@basket} to #{@host}:#{@port} started." )

        @socket = nil
        begin
          @socket = ExtendedTCPSocket.new
          @socket.connect( @host, @port, TIMED_OUT_IN_SECOND )
        rescue SocketError => e
          Log.warning e, "#{@host}:#{@port}"
          raise PermanentError, "#{e.message}: #{@host}:#{@port}"
        rescue => e
          Log.warning e, "#{@host}:#{@port}"
          raise RetryableError, "#{e.message}: #{@host}:#{@port}"
        end

        @channel = TcpClientChannel.new
        command, args = nil, nil
        sending( 'CATCH', Hash[ 'basket', @basket.to_s ] )
        @socket.set_receive_timed_out( TIMED_OUT_IN_SECOND )
        begin
          command, args = receiving
        rescue Errno::EAGAIN  # "Resource temporarily unavailable"
          m = "Response from a remote host timed out #{TIMED_OUT_IN_SECOND}s: #{@basket} to #{@host}:#{@port}"
          Log.warning m
          raise RetryableError, m
        end
        @socket.reset_receive_timed_out
        check_error( args )

        if ( args.has_key? 'exists' )
          Log.notice( "Replicating #{@basket} to #{@host}:#{@port} is no needed since the host already has it." )
          return
        end

        error_occurred = false

        begin
          do_replication
          sending( 'FINALIZE', nil )
          command, args = receiving
          check_error( args )
          @elapsed_time = Time.new - @started_time
          Log.notice( "Replicating #{@basket} to #{@host}:#{@port} done. dirs=#{@number_of_dirs} files=#{@number_of_files} bytes=#{@total_file_size} time=#{"%0.3fs" % @elapsed_time}" )
        rescue => e
          error_occurred = true
        end
        if ( error_occurred )
          begin
            sending( 'CANCEL', nil )
            command, args = receiving
            check_error( args )
            Log.warning( "Replicating #{@basket}  #{@host}:#{@port} canceled." )
          rescue => e
            raise
          end
        end

      ensure
        if ( @socket )
          @socket.close unless @socket.closed?
        end
      end

      def do_delete_command( basket, host )  # Todo: name this function more properly
        @basket = basket
        # okay to transer
        #      File.exist? @basket.path_a and raise PermanentError, "Deletion abandoned due to the existence of basket: #{@basket} #{@basket.path_a}"
        @host = host
        @port = @config.ReplicationTCPCommunicationPort
        Log.notice( "Deleting #{@basket} to #{@host}:#{@port} started." )

        @socket = nil
        begin
          @socket = ExtendedTCPSocket.new
          @socket.connect( @host, @port, TIMED_OUT_IN_SECOND )
        rescue SocketError => e
          Log.warning e, "#{@host}:#{@port}"
          raise PermanentError, "#{e.message}: #{@host}:#{@port}"
        rescue => e
          Log.warning e, "#{@host}:#{@port}"
          raise RetryableError, "#{e.message}: #{@host}:#{@port}"
        end

        @channel = TcpClientChannel.new
        command, args = nil, nil
        sending( 'DELETE', Hash[ 'basket', @basket.to_s ] )
        @socket.set_receive_timed_out( TIMED_OUT_IN_SECOND )
        begin
          command, args = receiving
        rescue Errno::EAGAIN  # "Resource temporarily unavailable"
          m = "Response from a remote host timed out #{TIMED_OUT_IN_SECOND}s: #{@basket} to #{@host}:#{@port}"
          Log.warning m
          raise RetryableError, m
        end
        @socket.reset_receive_timed_out
        check_error( args )

        if ( args.has_key? 'doesnot_exist' )
          Log.notice( "Deleting #{@basket} to #{@host}:#{@port} no needed." )
          return
        end

        Log.notice( "Deleting #{@basket} to #{@host}:#{@port} done." )

      ensure
        if ( @socket )
          @socket.close unless @socket.closed?
        end
      end


      def file_stat_hash( path, s )
        Hash[ :path => path,
              :mode => s.mode,
              :uid => s.uid,
              :gid => s.gid,
              :size => s.size.to_i,
              :atime => s.atime.to_i,
              :mtime => s.mtime.to_i,
              :ctime => s.ctime.to_i,
            ]
      end

      def do_replication
        unit_size = @config.ReplicationTransmissionDataUnitSize
        Find.find( @basket.path_a ) do |path|

          MaintenaceServerScheduler.instance.check_point

          if FileTest.directory?( path )
            # p [ 'd', path ]
            @number_of_dirs = @number_of_dirs + 1
            s = File.stat( path )

            a = @basket.path_a
            b = ".#{path[a.size, path.size-a.size]}"

            x = file_stat_hash( b, s )
            sending( 'DIRECTORY', x )
            command, args = receiving
            check_error( args )

          elsif FileTest.file?( path )
            # p [ 'f', path ]
            @number_of_files = @number_of_files + 1

            s = File.stat( path )

            a = @basket.path_a
            b = ".#{path[a.size, path.size-a.size]}"

            x = file_stat_hash( b, s )
            sending( 'FILE', x )
            command, args = receiving
            check_error( args )

            src = File.new( path, 'r' )
            size = s.size
            sending_size = size
            x = Hash[ :size => size ]
            sending( 'DATA', x )
            while ( 0 < size )
              MaintenaceServerScheduler.instance.check_point
              n = ( unit_size < size ) ? unit_size : size
              m = IO.copy_stream( src, @socket, n )
              size = size - m
            end
            MaintenaceServerScheduler.instance.check_point
            src.close
            @total_file_size = @total_file_size + sending_size
            command, args = receiving
            check_error( args )

          else
            # p [ '?', path ]
            # Todo: what should we do for other types of entry such as a symbolic link?
          end
        end
        sending( 'END', nil )
        command, args = receiving
        check_error( args )
      end
    end
    
  end
end


__END__
ruby -e "require 'socket'; s=Time.new; begin ; s=TCPSocket.new("127.0.0.1", 9999); rescue => e; p [e.class, e.message, (Time.new-s)*1000]; end"
[Errno::ECONNREFUSED, "Connection refused - connect(2)", 1.009499]

ruby -e "require 'socket'; s=Time.new; begin ; s=TCPSocket.new('stdext125', 9999); rescue => e; p [e.class, e.message, Time.new-s]; end"
[Errno::ETIMEDOUT, "Connection timed out - connect(2)", 191.032275801]
