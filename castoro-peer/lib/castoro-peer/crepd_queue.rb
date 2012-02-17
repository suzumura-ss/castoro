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
require 'castoro-peer/pipeline'

module Castoro
  module Peer

    # Todo: These definitions could be moved into the configuration
    DIR_REPLICATION = "/var/castoro/replication"
    DIR_WAITING     = "#{DIR_REPLICATION}/waiting"
    DIR_PROCESSING  = "#{DIR_REPLICATION}/processing"
    DIR_SLEEPING    = "#{DIR_REPLICATION}/sleeping"
    DIR_TMP         = "#{DIR_REPLICATION}/tmp"

    class ReplicationQueue < Pipeline
      include Singleton
    end


    class ReplicationEntryBase
      attr_reader :basket, :action

      def initialize( args )
        @basket = args[ :basket ]
        @action = args[ :action ]
      end

      def to_s
        inspect
      end
    end

    module ReplicationAttributes
      attr_reader :ttl, :hosts

      def initialize_attributes( args )
        if ( args )
          # these parameters come from JSON string
          @ttl = args[ 'ttl' ] or raise InvalidArgumentPermanentError, "ttl is not given."
          @hosts = args[ 'hosts' ] or raise InvalidArgumentPermanentError, "hosts is not given."
        end
        @ttl = default_ttl unless @ttl
        @hosts = [] unless @hosts
      end

      def append_myself
        @hosts.push StorageServers.instance.myhost
      end

      def default_ttl
        StorageServers.instance.members.size * 2
      end

      def decrease_ttl
        @ttl -= 1
      end

      def ttl_and_hosts
        ttl = ( @ttl ) ? @ttl.to_s : 'nil'
        hosts = ( @hosts ) ? @hosts.join(',') : 'nil'
        "ttl=#{ttl} hosts=#{hosts}"
      end
    end


    class ReplicationEntry < ReplicationEntryBase
      include ReplicationAttributes

      attr_reader :dir, :filename, :path, :alternative

      # new( :dir => dir, :filename => filename )
      # new( :basket => basket, :action => action )
      # new( :basket => basket, :action => action, :args => args )
      # args = { :ttl => ttl, :hosts => hosts }
      def initialize( args )
        @filename = args[ :filename ]
        if ( @filename )
          # "123.4.5.replicate"           new replication
          # "123.4.5.delete"              new deletion
          # "123.4.5.replicate.server101" replication; failover replication has done
          # "123.4.5.delete.server101"    deletion;    failover deletion has done
          content, type, revision, action, @alternative = @filename.split('.')
          @basket = Basket.new( content, type, revision )
          @action = case action
                    when 'replicate' ; :replicate
                    when 'delete'    ; :delete
                    else             ; raise InternalServerError, "invalid action: #{@filename}"
                    end
          self.dir = args[ :dir ]

        else
          super
          @alternative =nil
          @filename = "#{@basket}.#{@action}"
          self.dir = DIR_WAITING
        end

        initialize_attributes( args[ :args ] )
      end

      def dir=( x )
        @dir = x
        @path = "#{@dir}/#{@filename}"
      end

      def read
        if ( 0 < File.size( @path ) )
          args = JSON.load( File.read( @path ) )
          initialize_attributes( args )
        end
      rescue JSON::JSONError => e
        Log.warning e, "#{@path}"
      end

      def write
        tmp  = "#{DIR_TMP}/#{@filename}.#{Process.pid}.#{Thread.current.object_id}"
        File.open( tmp, "w" ) do |io|
          args = { :ttl => @ttl, :hosts => @hosts }
          io.puts( args.to_json )
        end
        File.rename( tmp, @path )
      rescue => e
        Log.warning e, "#{tmp} #{@path} #{@basket}"
      end

      def write_without_attribute
        File.open( @path, "w" ) {}
      rescue => e
        Log.warning e, "#{@path} #{@basket}"
      end
    end


    class ReplicationQueueDirectories
      include Singleton

      HIGH_THRESHOLD_LENGTH = 100
      MIDDLE_THRESHOLD_LENGTH = 60
      LOW_THRESHOLD_LENGTH = 30
      SLEEP_DURATION   = 10      # in seconds
      PUSH_INTERVAL    = 0.050   # in seconds

      def initialize
        # set up required directories
        Dir.exists? DIR_REPLICATION or Dir.mkdir DIR_REPLICATION
        [ DIR_WAITING, DIR_PROCESSING, DIR_SLEEPING, DIR_TMP ].each do |dir|
          Dir.exists? dir or Dir.mkdir dir
          File.writable? dir or raise StandardError, "no write permission: #{dir}"
        end

        @last_mtimes = [ -1, -1 ]
      end

      # salvage abondoned entries
      def salvage
        [ DIR_PROCESSING, DIR_SLEEPING ].each do |dir|
          Dir.open( dir ) do |d|
            d.each do |x|
              unless ( x == "." || x == ".." )
                a = "#{dir}/#{x}"
                b = "#{DIR_WAITING}/#{x}"
                File.rename( a, b )
                Log.notice "moved #{a} to #{b}"
              end
            end
          end
        end
      end

      def changed?
        mtimes = [ File.mtime( DIR_WAITING ), File.mtime( DIR_SLEEPING ) ]
        return ( @last_mtimes != mtimes )
      ensure
        @last_mtimes = mtimes
      end

      def fillup( queue )
        if ( queue.size < LOW_THRESHOLD_LENGTH )
          fillup_impl( queue, DIR_WAITING, 0 )
        end

        if ( queue.size < LOW_THRESHOLD_LENGTH )
          fillup_impl( queue, DIR_SLEEPING, SLEEP_DURATION )
        end

        if ( HIGH_THRESHOLD_LENGTH <= queue.size )
          sleep 3
        elsif ( MIDDLE_THRESHOLD_LENGTH <= queue.size )
          sleep 2
        else
          sleep 1
        end
      end

      def fillup_impl( queue, dir, asleep )
        t = Time.new - asleep
        h = Hash.new
        Dir.open( dir ) do |d|
          d.each do |x|
            unless ( x == "." || x == ".." )
              u = File.mtime "#{dir}/#{x}"
              if ( asleep == 0 or 0 < asleep && u < t )
                h[x] = u
              end
            end
          end
        end

        ( h.sort { |a, b| a[1] <=> b[1] } ).each do |x|
          queue.enq ReplicationEntry.new( :dir => dir, :filename => x[0] )
          break if HIGH_THRESHOLD_LENGTH <= queue.size
          sleep PUSH_INTERVAL
        end
      end

      def acquire( entry )
        path = entry.path
        target = "#{DIR_PROCESSING}/#{entry.filename}"

        if ( File.exists? path )
          unless ( File.exists? target )
            begin
              File.rename( path, target )
              entry.dir = DIR_PROCESSING
              entry.read
              return true
            rescue Errno::ENOENT
              # intended, file of the path gets processed by another thread.
            end
          end
        end
        return false
      end
        
      def release( entry )
        File.delete( entry.path )
      end

      def move_to_sleep( entry, alternative )
        path = entry.path
        target = "#{DIR_SLEEPING}/#{entry.filename}"
        target += ".#{alternative}" if alternative
        t = Time.new
        File.utime( t, t, path )
        File.rename( path, target )
      end

      def insert( entry )
        entry.write
      end

      def insert_without_attribute( entry )
        entry.write_without_attribute
      end

      def exists?( entry )
        target = "#{DIR_PROCESSING}/#{entry.filename}"
        File.exists? target
      end

      def delete( basket, action )
        [ DIR_WAITING, DIR_SLEEPING, DIR_PROCESSING ].each do |dir|
          x = "#{dir}/#{basket}.#{action}"
          Dir.glob( [ x, "#{x}.*" ] ).each do |path|
            begin
              File.delete( path )
              Log.notice "deleted: #{path} #{basket}"
            rescue => e
              Log.warning e, "#{path} #{basket}"
            end
          end
        end
      end

    end

  end
end
