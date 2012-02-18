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

      CONFIGURATION_FILE_CANDIDATES = [ 
                                       'peer.conf',
                                       'peer-dev-env.conf',
                                       '/etc/castoro/peer.conf',
                                      ]

      def Configurations.file=( file )
        @@initial_file = file
      end
          
      def default_configuration_file
        files = CONFIGURATION_FILE_CANDIDATES
        files.map { |f|
          File.exist? f and return f
        }
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
        @entries.keys.map { |item|
          Configurations.class_eval {
            if ( method_defined? item )
              remove_method( item )
            end
            define_method( item ) {
              @mutex.synchronize {
                @entries.include? item or raise ConfigurationError, "Unknown configuration item #{item}"
                @entries[ item ]
              }
            }
          }
        }
      end

      @file = nil
    end


    class ConfigurationFile
      def initialize
        @file = nil
        @ifconfig = Ifconfig.instance
        @default_entries = Hash.new
        [
         :HostnameForClient,
         :MulticastAddress,
         :MulticastNetwork,
         :MulticastIf,

         :GatewayUDPCommandPort,
         :PeerTCPCommandPort,
         :PeerUDPCommandPort,
         :WatchDogUDPCommandPort,
         :ReplicationUDPCommandPort,
         :ReplicationTCPCommunicationPort,

         :CmondMaintenancePort,
         :CpeerdMaintenancePort,
         :CrepdMaintenancePort,

         :CmondHealthCheckPort,
         :CpeerdHealthCheckPort,
         :CrepdHealthCheckPort,

         :BasketBaseDir,
         :NumberOfUDPCommandProcessor,
         :NumberOfTCPCommandProcessor,
         :NumberOfBasketStatusQueryDB,
         :NumberOfCsmController,
         :NumberOfUdpResponseSender,
         :NumberOfTcpResponseSender,
         :NumberOfMulticastCommandSender,
         :NumberOfReplicationDBClient,
         :PeriodOfAlivePacketSender,
         :PeriodOfStatisticsLogger,

         :NumberOfReplicationSender,

         :Dir_w_user,
         :Dir_w_group,
         :Dir_w_perm,

         :Dir_a_user,
         :Dir_a_group,
         :Dir_a_perm,

         :Dir_d_user,
         :Dir_d_group,
         :Dir_d_perm,

         :Dir_c_user,
         :Dir_c_group,
         :Dir_c_perm,

         :StorageHostsFile,
         :StorageGroupsFile,

         :EffectiveUser,

         :ReplicationTransmissionDataUnitSize,

         :UseManipulatorDaemon,
         :ManipulatorSocket,

        ].each { |item| @default_entries[ item ] = nil }
      end

      def load( file )
        @file = file
        @entries = @default_entries.dup
        do_load
        load_storage_hosts_file
        load_storage_groups_file
        validate
        @entries
      end

      private

      def validate
        i = @entries[ :MulticastIf ]
        n = @entries[ :MulticastNetwork ]
        if ( i and n )
          Log.warning 'MulticastNetwork is ignored because MulticastIf is already given in the configuration file: #{@file}'
          n = nil
        elsif ( i.nil? and n )
          i = @ifconfig.multicast_interface_by_network_address( n )
        elsif ( i.nil? and n.nil? )
          i = @ifconfig.default_interface_address
        else
          # good
        end
        unless ( @ifconfig.has_interface?( i ) )
          raise ConfigurationError, "The interface address described in #{@file} does not exist in this machine: #{i}"
        end
        @entries[ :MulticastIf ] = i
        @entries[ :MulticastNetwork ] = n

        unless ( @entries[ :HostnameForClient ] )
          @entries[ :HostnameForClient ] = @ifconfig.default_hostname
        end

        @entries[ :BasketBaseDir ] or raise ConfigurationError, "BasketBaseDir is not sepecfied in #{@file}"
        
        check_existence( :BasketBaseDir )
        @entries[ :StorageHostsFile ] or raise ConfigurationError, "StorageHostsFile is not sepecfied in #{@file}"
        @entries[ :StorageGroupsFile ] or raise ConfigurationError, "StorageGroupsFile is not sepecfied in #{@file}"

        @entries[ :CmondMaintenancePort ] or raise ConfigurationError, "CmondMaintenancePort is not sepecfied in #{@file}"
        @entries[ :CpeerdMaintenancePort ] or raise ConfigurationError, "CpeerdMaintenancePort is not sepecfied in #{@file}"
        @entries[ :CrepdMaintenancePort ] or raise ConfigurationError, "CrepdMaintenancePort is not sepecfied in #{@file}"

        @entries[ :CmondHealthCheckPort ] or raise ConfigurationError, "CmondHealthCheckPort is not sepecfied in #{@file}"
        @entries[ :CpeerdHealthCheckPort ] or raise ConfigurationError, "CpeerdHealthCheckPort is not sepecfied in #{@file}"
        @entries[ :CrepdHealthCheckPort ] or raise ConfigurationError, "CrepdHealthCheckPort is not sepecfied in #{@file}"
        
        @entries[ :ReplicationTransmissionDataUnitSize ] or raise ConfigurationError, "ReplicationTransmissionDataUnitSize is not specified in #{@file}"
        unless ( 0 < @entries[ :ReplicationTransmissionDataUnitSize ] )
          raise ConfigurationError, "ReplicationTransmissionDataUnitSize in #{@file} is not a positive number: #{@entries[ :ReplicationTransmissionDataUnitSize ]}"
        end

        @entries[ :UseManipulatorDaemon ] = ["yes", "true", "on"].include? @entries[ :UseManipulatorDaemon ]
        check_existence( :ManipulatorSocket ) if @entries[ :UseManipulatorDaemon ]
      end

      def check_existence( symbol )
        path = @entries[ symbol ]
        File.exist? path  or raise ConfigurationError, "A path #{symbol} in #{@file} does not exist: #{path}"
      end

      def do_load
        File.open( @file , File::RDONLY ) do |f|
          while line = f.gets do
            next if line =~ /\A\#/
            next if line =~ /\A\;/
            next if line =~ /\A\s*\Z/
            line.chomp!
            # p line
            if ( line =~ /\A\s*(.+?)\s+(.*?)\s*\Z/ )
              item, value = $1, $2
              symbol = item.to_sym
              # p [ item, value ]
              if ( @entries.has_key? symbol )
                if ( item.match(/\A(NumberOf|PeriodOf)/i) or item.match(/(Port|Size)\Z/i) )
                  @entries[ symbol ] = value.to_i
                else
                  @entries[ symbol ] = value
                end
              else
                raise ConfigurationError, "#{@file}:#{$.}: Unknown parameter: #{line}"
              end
            else
              raise ConfigurationError, "#{@file}:#{$.}: Invalid line: #{line}"
            end
          end
        end
      end

      def load_storage_hosts_file
        check_existence( :StorageHostsFile )
        @entries[ :StorageHostsData ] = YAML::load_file( @entries[ :StorageHostsFile ] )
      end
      
      def load_storage_groups_file
        check_existence( :StorageGroupsFile )
        @entries[ :StorageGroupsData ] = JSON::parse IO.read( @entries[ :StorageGroupsFile ] )
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      f = './peer-dev-env.conf'
      Configurations.file = f

      x = Configurations.instance
      p x.MulticastNetwork
      p x.MulticastIf

      x.load()
      p x.MulticastNetwork
      p x.MulticastIf
      x.load( f )
      p x.MulticastNetwork
      p x.MulticastIf
      x.reload
      p x.MulticastNetwork
      p x.MulticastIf
    end
  end
end

__END__

time ruby -I ../..  -e "require 'configurations'; 1000000.times{ x=Castoro::Peer::Configurations.instance.MulticastNetwork }"
time ruby -I ../..  -e "require 'configurations'; c=Castoro::Peer::Configurations.instance; 1000000.times{ x=c.MulticastNetwork }"
