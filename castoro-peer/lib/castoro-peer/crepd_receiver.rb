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
require 'json'

require 'castoro-peer/configurations'
require 'castoro-peer/basket'
require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'
require 'castoro-peer/log'
require 'castoro-peer/manipulator'
require 'castoro-peer/server_status'
require 'castoro-peer/scheduler'
require 'castoro-peer/crepd_queue'
require 'castoro-peer/pre_threaded_tcp_server'

module Castoro
  module Peer
    
    class ReplicationReceiveServer < PreThreadedTcpServer
      def initialize
        port = Configurations.instance.crepd_transmission_tcpport
        host = '0.0.0.0'
        maxConnections = 20
        super( port, host, maxConnections )
      end

      def serve( io )
        receiver = ReplicationReceiver.new( io )
        begin
          receiver.initiate
        rescue => e
          Log.warning e
        end
      end
    end

    class ReplicationReceiver
      def initialize( io )
        @io = io
        @channel = TcpServerChannel.new
        @config = Configurations.instance
        @fd = nil
        @csm_executor = Csm.create_executor
        @command = nil
        @basket = nil
      end

      def initiate
        loop do
          begin
            @channel.receive( @io )
            break if @channel.closed?
            unless ( ServerStatus.instance.replication_activated? )
              raise RetryableError, "server status: #{ServerStatus.instance.status} #{ServerStatus.instance.status_name} for #{@basket}" 
            end
            @command, @args = @channel.parse
            @ip, @port = @io.ip, @io.port
            @response = @args
            dispatch  # some commands alter @response during their process
            @channel.send( @io, @response )
          rescue => e
            Log.warning e, "#{@command} #{@args} from #{@ip}:#{@port}"
            @channel.send( @io, e )
          end
        end
      ensure
        @fd.close if @fd and not @fd.closed?
      end

      def dispatch
        @command.upcase!
        case @command
        when 'NOP'       ; do_nop
        when 'CATCH'     ; do_catch
        when 'DELETE'    ; do_delete
        when 'DIRECTORY' ; do_directory
        when 'FILE'      ; do_file
        when 'DATA'      ; do_data
        when 'END'       ; do_end
        when 'CANCEL'    ; do_cancel
        when 'FINALIZE'  ; do_finalize
        else             ; raise InvalidArgumentPermanentError, "Unknown command: #{@command}"
        end
      end

      def do_nop
        # Do nothing
      end

      def parse_basket
        basket_text = @args[ 'basket' ] or raise PermanentError
        @basket = Basket.new_from_text( basket_text )
        @path_a = @basket.path_a
      rescue => e
        raise InvalidArgumentPermanentError, "#{e.class} #{e.message}: Invalid basket: #{basket_text}"
      end

      def do_catch
        @started = Time.new
        @dirs, @files, @bytes = 0, 0, 0
        @directory_entries = []

        parse_basket
        @entry = ReplicationEntry.new( :basket => @basket, :action => :replicate, :args => @args )
        Log.debug "CATCH: #{@entry.inspect} from #{@ip}:#{@port}" if $DEBUG

        if ( File.exist? @path_a )
          register_entry
          @response = { :exists => @path_a }
        else
          begin
            @path_r = @basket.path_r
            csm_request = Csm::Request::Catch.new( @path_r )
            @csm_executor.execute( csm_request )
          rescue => e
            raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r}"
          end
        end
      end

      def do_delete
        parse_basket
        @entry = ReplicationEntry.new( :basket => @basket, :action => :delete, :args => @args )
        Log.debug "DELETE: #{@entry.inspect} from #{@ip}:#{@port}" if $DEBUG

        register_entry
        ReplicationQueueDirectories.instance.delete( @basket, :replicate )

        @path_d = @basket.path_d
        if ( File.exist? @path_a )
          begin
            csm_request = Csm::Request::Delete.new( @path_a, @path_d )
            @csm_executor.execute( csm_request )
          rescue => e
            raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_a} #{@path_d}"
          end
          Log.notice "DELETED: #{@basket} #{@path_a} from #{@ip}:#{@port}; moved to #{@path_d} #{@entry.ttl_and_hosts}"
          send_multicast_packet( 'DROP', @path_d )
        else
          @response = { :doesnot_exist => @path_a }
        end
      end

      def parse_attributes( args )
        path = args[ 'path' ] or raise InvalidArgumentPermanentError, "path is not given: #{@basket}"
        if ( path == '.'  or path == '..' )
          raise InvalidArgumentPermanentError, "#{path} is not allowed: #{@basket}"
        end
        @path = "#{@path_r}/#{path}"
        @mode  = args[ 'mode' ]
        @atime = args[ 'atime' ]
        @mtime = args[ 'mtime' ]
      end

      def apply_attributes
        File.chmod( @mode, @path )
        File.utime( @atime, @mtime, @path )
      end

      def do_directory
        parse_attributes( @args )
        Log.debug "DIRECTORY: #{@basket} #{@path} from #{@ip}:#{@port}" if $DEBUG

        begin
          Dir.mkdir( @path, 0755 )
        rescue => e
          raise PermanentError, "#{e.class} #{e.message}: mkdir #{@path} for #{@basket}"
        end

        @directory_entries.push @args
        @dirs += 1
      end

      def do_file
        parse_attributes( @args )
        Log.debug "FILE: #{@basket} #{@path} from #{@ip}:#{@port}" if $DEBUG
        @fd = File.new( @path, "w" )  # @fd will be closed in the method do_data
      end

      def do_data
        sent = @args[ 'size' ]
        unit_size = @config.crepd_transmission_data_unit_size

        rest = sent
        while ( 0 < rest )
          n = ( unit_size < rest ) ? unit_size : rest
          rest -= IO.copy_stream( @io, @fd, n )  # @fd has been opened in the method do_file
          MaintenaceServerSingletonScheduler.instance.check_point
        end
        @fd.close

        apply_attributes
        received = File.size( @path )
        ( sent == received ) or raise RetryableError, "File size does not match: sent=#{sent} received=#{received} #{@path} #{@basket}"
        @files += 1
        @bytes += received
      end

      def do_end
        @directory_entries.reverse.each do |args|
          parse_attributes( args )
          Log.debug "END: #{@basket} #{@path} mode: #{@mode} atime: #{@atime} mtime: #{@mtime} from #{@ip}:#{@port}" if $DEBUG
          apply_attributes
        end
      end

      def do_cancel
        if ( File.exist? @path_r )
          csm_request = Csm::Request::Cancel.new( @path_r, @basket.path_c( @path_r ) )
          begin
            @csm_executor.execute( csm_request )
          rescue => e
            raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r} #{@path_a}"
          end
        end
        Log.notice "CANCELD: #{@basket} #{@path_r} from #{@ip}:#{@port}"
      end

      def do_finalize
        if ( File.exist? @path_a )
          raise AlreadyExistsPermanentError, "Basket already exists: #{@basket} #{@path_a}"
        end

        csm_request = Csm::Request::Finalize.new( @path_r, @path_a )
        begin
          @csm_executor.execute( csm_request )
        rescue => e
          raise RetryableError, "#{e.class} #{e.message} for #{@basket} #{@path_r} #{@path_a}"
        end
        @elapsed = Time.new - @started
        Log.notice "REPLICATED: #{@basket} #{@basket.path_a} from #{@ip}:#{@port} dirs=#{@dirs} files=#{@files} bytes=#{@bytes} time=#{"%0.3fs" % @elapsed} #{@entry.ttl_and_hosts}"

        send_multicast_packet( 'INSERT', @path_a )
        register_entry
      end

      def send_multicast_packet( command, path )
        socket = ExtendedUDPSocket.new
        socket.set_multicast_if Configurations.instance.gateway_comm_ipaddr_nic
        channel = UdpClientChannel.new( socket )
        host = @config.hostname_for_client
        ip   = @config.MulticastAddress
        port = @config.gateway_learning_udpport_multicast
        args = { 'basket' => @basket.to_s, 'host' => host, 'path' => path }
        channel.send( command, args, ip, port )
      end

      def register_entry
        if ( satisfied? )
          Log.debug "register_entry satisfied. #{@basket} #{@entry.action} #{@entry.ttl_and_hosts}" if $DEBUG
        else
          @entry.decrease_ttl
          if ( 0 < @entry.ttl )
            ReplicationQueueDirectories.instance.insert( @entry )
            ReplicationQueue.instance.enq @entry
          else
            Log.warning "TTL exceeded. #{@basket} #{@entry.action} #{@entry.ttl_and_hosts}"
          end
        end
      end

      def satisfied?
        hosts = @entry.hosts
        StorageServers.instance.colleague_hosts.each do |h|
          Log.debug "satisfied? #{@basket} #{@entry.action} hosts=#{hosts.join(',')} h=#{h} #{hosts.include? h}" if $DEBUG
          hosts.include? h or return false
        end
        return true
      end
    end

  end
end
