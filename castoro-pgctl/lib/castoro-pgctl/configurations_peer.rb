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
require 'castoro-pgctl/configurations_base'
require 'yaml'
require 'json'
require 'castoro-pgctl/exceptions'

module Castoro
  module Peer

    module Configurations
      class Peer < Base
        include Singleton

        @@file = '/etc/castoro/peer.conf'

        def self.file= file
          @@file = file
        end

        def configuration_file
          @@file
        end
      end


      class ConfigurationFile < ConfigurationFileBase
        def load
          super
          load_storage_hosts_file
          load_storage_groups_file
        end

        def validate
          super
          @global.data[ :type_id_rangesHash ] = Hash.new.tap do |h|
            @services.each do |s|
              h[ s[ :basket_keyconverter ] ] = s[ :type_id_ranges ]
            end
          end
        end

        private

        def load_storage_hosts_file
          file = @global.data[ :config_host_file ] || @global.data[ :StorageHostsFile ]
          file or raise ArgumentError, "Neither config_host_file nor StorageHostsFile is specified"
          @global.data[ :StorageHostsData ] = YAML::load_file file
        end
        
        def load_storage_groups_file
          file = @global.data[ :config_group_file ] || @global.data[ :StorageGroupsFile ]
          file or raise ArgumentError, "Neither config_group_file nore StorageGroupsFile is specified"
          @global.data[ :StorageGroupsData ] = JSON::parse( IO.read( file ) )
        end
      end


      class GlobalSection < Section
        def initialize
          super(
                # peer.conf in castoro-2 format
                :peer_hostname                              => [ :optional,  :string ],
                :gateway_comm_ipaddr_multicast              => [ :optional,  :string ],
                :gateway_comm_ipaddr_network                => [ :optional,  :string ],
                :gateway_comm_ipaddr_nic                    => [ :optional,  :string ],
                :peer_comm_ipaddr_multicast                 => [ :optional,  :string ],
                :peer_comm_ipaddr_network                   => [ :optional,  :string ],
                :peer_comm_ipaddr_nic                       => [ :optional,  :string ],
                :gateway_learning_udpport_multicast         => [ :optional,  :number ],
                :peer_comm_tcpport                          => [ :optional,  :number ],
                :peer_comm_udpport_multicast                => [ :optional,  :number ],
                :gateway_watchdog_udpport_multicast         => [ :optional,  :number ],
                :crepd_transmission_tcpport                 => [ :optional,  :number ],
                :crepd_registration_udpport                 => [ :optional,  :number ],
                :cmond_maintenance_tcpport                  => [ :optional,  :number ],
                :cpeerd_maintenance_tcpport                 => [ :optional,  :number ],
                :crepd_maintenance_tcpport                  => [ :optional,  :number ],
                :cmond_healthcheck_tcpport                  => [ :optional,  :number ],
                :cpeerd_healthcheck_tcpport                 => [ :optional,  :number ],
                :crepd_healthcheck_tcpport                  => [ :optional,  :number ],
                :cpeerd_number_of_udp_command_processor     => [ :optional,  :number ],
                :cpeerd_number_of_tcp_command_processor     => [ :optional,  :number ],
                :cpeerd_number_of_basket_status_query_db    => [ :optional,  :number ],
                :cpeerd_number_of_csm_controller            => [ :optional,  :number ],
                :cpeerd_number_of_udp_response_sender       => [ :optional,  :number ],
                :cpeerd_number_of_tcp_response_sender       => [ :optional,  :number ],
                :cpeerd_number_of_multicast_command_sender  => [ :optional,  :number ],
                :cpeerd_number_of_replication_db_client     => [ :optional,  :number ],
                :cmond_period_of_watchdog_sender            => [ :optional,  :number ],
                :cpeerd_period_of_statistics_logger         => [ :optional,  :number ],
                :config_group_file                          => [ :optional,  :string, :path ],
                :config_host_file                           => [ :optional,  :string, :path ],
                :effective_user                             => [ :optional,  :string ],
                :crepd_transmission_data_unit_size          => [ :optional,  :number ],
                :crepd_number_of_replication_sender         => [ :optional,  :number ],
                :manipulator_in_use                         => [ :optional,  :boolean ],
                :manipulator_socket                         => [ :optional,  :string ],
                :basket_basedir                             => [ :optional,  :string ],
                :dir_w_user                                 => [ :optional,  :string ],
                :dir_w_group                                => [ :optional,  :string ],
                :dir_w_perm                                 => [ :optional,  :octal  ],
                :dir_a_user                                 => [ :optional,  :string ],
                :dir_a_group                                => [ :optional,  :string ],
                :dir_a_perm                                 => [ :optional,  :octal  ],
                :dir_d_user                                 => [ :optional,  :string ],
                :dir_d_group                                => [ :optional,  :string ],
                :dir_d_perm                                 => [ :optional,  :octal  ],
                :dir_c_user                                 => [ :optional,  :string ],
                :dir_c_group                                => [ :optional,  :string ],
                :dir_c_perm                                 => [ :optional,  :octal  ],

                # peer.conf in castoro-1 format
                :HostnameForClient                          => [ :optional,  :string ],
                :MulticastAddress                           => [ :optional,  :string ],
                :MulticastNetwork                           => [ :optional,  :string ],
                :MulticastIf                                => [ :optional,  :string ],
                :MulticastNetwork                           => [ :optional,  :string ],
                :GatewayUDPCommandPort                      => [ :optional,  :number ],
                :PeerTCPCommandPort                         => [ :optional,  :number ],
                :PeerUnicastUDPCommandPort                  => [ :optional,  :number ],
                :PeerMulticastUDPCommandPort                => [ :optional,  :number ],
                :WatchDogCommandPort                        => [ :optional,  :number ],
                :ReplicationTCPCommandPort                  => [ :optional,  :number ],
                :ReplicationUDPCommandPort                  => [ :optional,  :number ],
                :ReplicationTCPCommunicationPort            => [ :optional,  :number ],
                :BasketBaseDir                              => [ :optional,  :string ],
                :NumberOfExpressCommandProcessor            => [ :optional,  :number ],
                :NumberOfRegularCommandProcessor            => [ :optional,  :number ],
                :NumberOfBasketStatusQueryDB                => [ :optional,  :number ],
                :NumberOfCsmController                      => [ :optional,  :number ],
                :NumberOfUdpResponseSender                  => [ :optional,  :number ],
                :NumberOfTcpResponseSender                  => [ :optional,  :number ],
                :NumberOfMulticastCommandSender             => [ :optional,  :number ],
                :NumberOfReplicationDBClient                => [ :optional,  :number ],
                :PeriodOfAlivePacketSender                  => [ :optional,  :number ],
                :PeriodOfStatisticsLogger                   => [ :optional,  :number ],
                :NumberOfReplicationSender                  => [ :optional,  :number ],
                :CmondMaintenancePort                       => [ :optional,  :number ],
                :CgetdMaintenancePort                       => [ :optional,  :number ],
                :CpeerdMaintenancePort                      => [ :optional,  :number ],
                :CrepdMaintenancePort                       => [ :optional,  :number ],
                :CmondHealthCheckPort                       => [ :optional,  :number ],
                :CgetdHealthCheckPort                       => [ :optional,  :number ],
                :CpeerdHealthCheckPort                      => [ :optional,  :number ],
                :CrepdHealthCheckPort                       => [ :optional,  :number ],
                :Dir_w_user                                 => [ :optional,  :string ],
                :Dir_w_group                                => [ :optional,  :string ],
                :Dir_w_perm                                 => [ :optional,  :octal  ],
                :Dir_a_user                                 => [ :optional,  :string ],
                :Dir_a_group                                => [ :optional,  :string ],
                :Dir_a_perm                                 => [ :optional,  :octal  ],
                :Dir_d_user                                 => [ :optional,  :string ],
                :Dir_d_group                                => [ :optional,  :string ],
                :Dir_d_perm                                 => [ :optional,  :octal  ],
                :Dir_c_user                                 => [ :optional,  :string ],
                :Dir_c_group                                => [ :optional,  :string ],
                :Dir_c_perm                                 => [ :optional,  :octal  ],
                :StorageHostsFile                           => [ :optional,  :string, :path ],
                :StorageGroupsFile                          => [ :optional,  :string, :path ],
                :EffectiveUser                              => [ :optional,  :string ],
                :ReplicationTransmissionDataUnitSize        => [ :optional,  :number ],
                :UseManipulatorDaemon                       => [ :optional,  :boolean ],
                :ManipulatorSocket                          => [ :optional,  :string ],
                )
        end
      end


      class ServiceSection < Section
        def initialize
          super(
                :service_name                               => [ :mandatory, :string ],
                :type_id_ranges                             => [ :mandatory, :string ],
                :basket_keyconverter                        => [ :mandatory, :string ],
                )
        end
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      c = Configurations::Peer
      c.file = '../../../castoro-peer/etc/castoro/peer.conf-sample-ja.conf'
      p c.instance
    end
  end
end
