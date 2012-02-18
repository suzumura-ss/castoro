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

require 'singleton'
require 'yaml'
require 'json'
require 'castoro-peer/log'
require 'castoro-peer/ifconfig'
require 'castoro-peer/errors'

module Castoro
  module Peer

    class Configurations
      include Singleton

      CONFIGURATION_FILE_CANDIDATES = [ 'peer.conf', '/etc/castoro/peer.conf' ]

      def self.file= file
        @@initial_file = file
      end
          
      def default_configuration_file
        files = CONFIGURATION_FILE_CANDIDATES
        files.map do |f|
          return f if File.exist? f
        end
        raise StandardError, "No configuration file is found. Default files are #{files.join(' ')}"
      end

      def initialize
        @mutex = Mutex.new
        @entries = nil
        @file = @@initial_file if defined? @@initial_file
        @file = default_configuration_file if @file.nil?
        @config_file = ConfigurationFile.new
        self.load
      end

      def load( file = nil )
        @mutex.synchronize {
          f = file || @file
          f = "#{Dir.getwd}/#{f}" unless f.match(/\A\//)
          Log.notice( "Loading configration file: #{f}" )
          # print "#{caller.join("\n")}\n"
          @entries = @config_file.load( f )  # exceptions might be raised
          @file = f
          # Log.notice( "Configuration data in #{@file}: #{@entries.inspect}" )
          define_readers()
          @entries
        }
      end

      def reload( file = nil )
        @mutex.synchronize {
          f = file || @file
          f = "#{Dir.getwd}/#{f}" unless f.match(/\A\//)
          Log.notice( "Reloading configration file: #{f}" )
          @entries = @config_file.load( f )
          Log.notice( "Configuration data in #{f}: #{@entries.inspect}" )
          define_readers()
          @entries
        }
      rescue => e
        s = 'Keep running with the previously loaded configurations. ' + 
          'New configurations are ignored due to an error in the file'
        Log.err( "#{s}: #{file}: #{e.class} #{e.message}" )
        raise
      end

      private

      def define_readers
        @entries.keys.map do |item|
          Configurations.class_eval do
            if ( method_defined? item )
              remove_method( item )
            end
            define_method( item ) do
              @mutex.synchronize do
                @entries[ item ]
              end
            end
          end
        end
      end
    end


    class ConfigurationFile
      def initialize
        @global = nil
        @services = []
      end

      def load file
        load_configuration_file file
        @global.validate
        @data = @global.data.dup
        load_storage_hosts_file
        load_storage_groups_file
        @data[ :TypeIdRangesHash ] = Hash.new.tap do |h|
          @services.each do |s|
            s.validate
            h[ s[ :BasketKeyConverterModuleName ] ] = s[ :TypeIdRanges ]
          end
        end
        @data
      rescue => e
        raise ConfigurationError, "#{e}"
      end

      private

      def load_configuration_file file
        section = nil
        File.open( file , File::RDONLY ) do |f|
          begin
            while line = f.gets do
              case line
              when /\A[#;]/, /\A\s*\Z/  # Comment
                next
              when /\A\s*(\w+)\s+(.*?)\s*\Z/  # Parameter
                # print "PARAMETER: #{$1} #{$2}\n"
                section or raise ArgumentError, "Section is not yet specified"
                section.register $1.to_sym, $2
              when /\A\s*\[\s*(\w+)\s*\]\s*\Z/  # Section header
                # print "SECTION: #{$1}\n"
                case $1
                when 'global'  ; @global = section = GlobalSection.new
                when 'service' ; @services.push( section = ServiceSection.new )
                else ; raise NameError, "Unknown section name"
                end
              else
                raise ArgumentError, "Invalid line"
              end
            end
          rescue => e
            raise ConfigurationError, "#{e}: #{file}:#{$.}: #{line}"
          end
        end
      end

      def load_storage_hosts_file
        @data[ :StorageHostsData ] = YAML::load_file( @global[ :StorageHostsFile ] )
      end
      
      def load_storage_groups_file
        @data[ :StorageGroupsData ] = JSON::parse( IO.read @global[ :StorageGroupsFile ] )
      end


      class Section
        attr_reader :data

        def initialize entries
          @entries = entries
          @data = {}
        end

        def register key, value
          ( necessity, type, path = @entries[ key ] ) or raise NameError, "Unknown parameter"
          @data[ key ] = case type 
                         when :string
                           if path
                             File.exist?( value ) or raise NameError, "The path does not exist"
                           end
                           value
                         when :number  # positive integer number only
                           value.match( /\A\d+\Z/ ) or raise ArgumentError, "Invalid number"
                           value.to_i
                         when :boolean
                           evaluate_boolean value
                         end
        end
        
        def validate
          @entries.each do |key, spec|
            if :mandatory == spec[0]
              @data.has_key?( key ) or raise ArgumentError, "#{key} is not specified"
            end
          end
        end

        def []( key )
          @data[ key ]
        end
        
        private

        def evaluate_boolean value
          return true  if %w( yes true on  ).include? value
          return false if %w( no false off ).include? value
          raise ArgumentError, "Invalid boolean"
        end
      end


      class GlobalSection < Section
        def initialize
          super(
                :HostnameForClient                    => [ :optional,  :string ],
                :MulticastAddress                     => [ :optional,  :string ],
                :MulticastNetwork                     => [ :optional,  :string ],
                :MulticastIf                          => [ :optional,  :string ],
                :GatewayUDPCommandPort                => [ :mandatory, :number ],
                :PeerTCPCommandPort                   => [ :mandatory, :number ],
                :PeerUDPCommandPort                   => [ :mandatory, :number ],
                :WatchDogUDPCommandPort               => [ :mandatory, :number ],
                :ReplicationTCPCommunicationPort      => [ :mandatory, :number ],
                :ReplicationUDPCommandPort            => [ :mandatory, :number ],
                :CmondMaintenancePort                 => [ :mandatory, :number ],
                :CpeerdMaintenancePort                => [ :mandatory, :number ],
                :CrepdMaintenancePort                 => [ :mandatory, :number ],
                :CmondHealthCheckPort                 => [ :mandatory, :number ],
                :CpeerdHealthCheckPort                => [ :mandatory, :number ],
                :CrepdHealthCheckPort                 => [ :mandatory, :number ],
                :NumberOfUDPCommandProcessor          => [ :mandatory, :number ],
                :NumberOfTCPCommandProcessor          => [ :mandatory, :number ],
                :NumberOfBasketStatusQueryDB          => [ :mandatory, :number ],
                :NumberOfCsmController                => [ :mandatory, :number ],
                :NumberOfUdpResponseSender            => [ :mandatory, :number ],
                :NumberOfTcpResponseSender            => [ :mandatory, :number ],
                :NumberOfMulticastCommandSender       => [ :mandatory, :number ],
                :NumberOfReplicationDBClient          => [ :mandatory, :number ],
                :PeriodOfAlivePacketSender            => [ :mandatory, :number ],
                :PeriodOfStatisticsLogger             => [ :mandatory, :number ],
                :StorageGroupsFile                    => [ :mandatory, :string, :path ],
                :StorageHostsFile                     => [ :mandatory, :string, :path ],
                :EffectiveUser                        => [ :mandatory, :string ],
                :ReplicationTransmissionDataUnitSize  => [ :mandatory, :number ],
                :NumberOfReplicationSender            => [ :mandatory, :number ],
                :UseManipulatorDaemon                 => [ :mandatory, :boolean ],
                :ManipulatorSocket                    => [ :optional,  :string, :path ],
                :BasketBaseDir                        => [ :mandatory, :string, :path ],
                :Dir_w_user                           => [ :mandatory, :string ],
                :Dir_w_group                          => [ :mandatory, :string ],
                :Dir_w_perm                           => [ :mandatory, :number ],
                :Dir_a_user                           => [ :mandatory, :string ],
                :Dir_a_group                          => [ :mandatory, :string ],
                :Dir_a_perm                           => [ :mandatory, :number ],
                :Dir_d_user                           => [ :mandatory, :string ],
                :Dir_d_group                          => [ :mandatory, :string ],
                :Dir_d_perm                           => [ :mandatory, :number ],
                :Dir_c_user                           => [ :mandatory, :string ],
                :Dir_c_group                          => [ :mandatory, :string ],
                :Dir_c_perm                           => [ :mandatory, :number ],
                )
        end

        def validate
          super
          validate_hostname
          validate_manipulator
          validate_network
        end

        private

        def validate_hostname
          unless @data[ :HostnameForClient ]
            @data[ :HostnameForClient ] = Ifconfig.instance.default_hostname
          end
        end

        def validate_manipulator
          if @data[ :UseManipulatorDaemon ]
            @data[ :ManipulatorSocket ] or raise ConfigurationError, "ManipulatorSocket is not specified"
          end
        end

        def validate_network
          ip  = @data[ :MulticastIf ]
          net = @data[ :MulticastNetwork ]
          if ip
            raise ConfigurationError, "Both MulticastIf and MulticastNetwork are specified" if net
          else
            if net
              ip = Ifconfig.instance.multicast_interface_by_network_address( net )
            else
              ip = Ifconfig.instance.default_interface_address
            end
          end
          Ifconfig.instance.has_interface?( ip ) or raise ConfigurationError, "This host does not have the IP address: #{ip}"
          @data[ :MulticastIf ] = ip
        end
      end


      class ServiceSection < Section
        def initialize
          super(
                :ServiceName                          => [ :mandatory, :string ],
                :TypeIdRanges                         => [ :mandatory, :string ],
                :BasketKeyConverterModuleName         => [ :mandatory, :string ],
                )
        end
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      f = '../../config/etc/peer.conf-sample-en.conf'
      f = 'peer.conf'
      Configurations.file = f

      x = Configurations.instance
      p x.MulticastIf
      p x.TypeIdRangesHash

      x.load()
      p x.MulticastIf
      x.load( f )
      p x.MulticastIf
      x.reload
      p x.MulticastIf
    end
  end
end

__END__

time ruby -I ..  -e "require 'configurations'; 1000000.times{ x=Castoro::Peer::Configurations.instance.MulticastIf }"
time ruby -I ..  -e "require 'configurations'; c=Castoro::Peer::Configurations.instance; 1000000.times{ x=c.MulticastIf }"
