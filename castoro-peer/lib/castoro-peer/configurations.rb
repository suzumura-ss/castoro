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

require 'yaml'
require 'erb'
require 'ipaddr'

require 'castoro-peer/log'
require 'castoro-peer/ifconfig'

module Castoro
  module Peer

    class ConfigurationError < StandardError ; end

    class Configurations

      DEFAULT_FILE = '/etc/castoro/peer.conf'.freeze

      DEFAULT_SETTINGS = {
        'hostname_for_client'                 => nil,
        'multicast_address'                   => '239.192.1.1',
        'multicast_if'                        => nil,

        'gateway_udp_command_port'            => 30109,
        'peer_tcp_command_port'               => 30111,
        'peer_unicast_udp_command_port'       => 30111,
        'peer_multicast_udp_command_port'     => 30112,
        'watchdog_command_port'               => 30113,
        'replication_tcp_command_port'        => 30149,
        'replication_udp_command_port'        => 30149,
        'replication_tcp_communication_port'  => 30148,

        'cmond_maintenance_port'              => 30100,
        'cpeerd_maintenance_port'             => 30102,
        'crepd_maintenance_port'              => 30103,
        'cmond_healthcheck_port'              => 30105,
        'cpeerd_healthcheck_port'             => 30107,
        'crepd_healthcheck_port'              => 30108,

        'basket_base_dir'                     => '/expdsk',

        'number_of_express_command_processor' => 10,
        'number_of_regular_command_processor' => 10,
        'number_of_basket_status_query_db'    => 10,
        'number_of_csm_controller'            => 3,
        'number_of_udp_response_sender'       => 10,
        'number_of_tcp_response_sender'       => 10,
        'number_of_multicast_command_sender'  => 3,
        'number_of_replication_db_client'     => 1,
        'number_of_replication_sender'        => 3,

        'period_of_alive_packet_sender'       => 4,
        'period_of_statistics_logger'         => 60,

        'dir_w_user'                          => 'castoro',
        'dir_w_group'                         => 'castoro',
        'dir_w_perm'                          => '0777',

        'dir_a_user'                          => 'root',
        'dir_a_group'                         => 'castoro',
        'dir_a_perm'                          => '0555',

        'dir_d_user'                          => 'root',
        'dir_d_group'                         => 'castoro',
        'dir_d_perm'                          => '0555',

        'dir_c_user'                          => 'root',
        'dir_c_group'                         => 'castoro',
        'dir_c_perm'                          => '0555',

        'effective_user'                      => 'castoro',

        'replication_transmission_datasize'   => 1048576,

        'use_manipulator_daemon'              => true,
        'manipulator_socket'                  => '/var/castoro/manipulator.sock',

        'aliases'                             => {},
        'groups'                              => [],
      }.freeze

      ##
      # initialize.
      #
      # === Args
      #
      # +file+::
      #   fullpath for configuration file.
      #
      def initialize file
        @file = (file || DEFAULT_FILE).freeze

        c  = YAML.load(ERB.new(IO.read(@file)).result) || {}
        @h = DEFAULT_SETTINGS.merge c
        class << @h
          alias :apply  :[]
          alias :update :[]=
          def []  key
            self.apply key.to_s
          end
          def []= key, val
            self.update key.to_s, val
          end
        end

        validate

        @storage_servers = define_storage_servers
      end

      ##
      # the indexer.
      #
      # === Args
      #
      # +key+::
      #   key of configurations.
      #
      def [] key; @h[key]; end

      ##
      # accessor for replication hosts infomation.
      #
      attr_reader :storage_servers

      private

      def define_storage_servers #:nodoc:

        hostname = @h[:hostname_for_client]
        groups   = @h[:groups]  || []
        aliases  = @h[:aliases] || {}

        g = groups.select { |a| a.include? hostname }
        raise ConfigurationError, "hostname does not exist in replication groups." if g.empty?

        g.flatten!
        n = g.size
        g.concat g.dup
        i = g.index hostname
        hosts = g.slice i, n
        h = hosts.map { |x| aliases[x] || x }
        h.shift

        colleague_hosts   = h.dup
        target            = h.shift
        alternative_hosts = h

        ret = Object.new
        ret.instance_variable_set :@colleague_hosts  , colleague_hosts.freeze
        ret.instance_variable_set :@target           , target.freeze
        ret.instance_variable_set :@alternative_hosts, alternative_hosts.freeze
        class << ret; attr_reader :colleague_hosts, :target, :alternative_hosts; end
        ret.freeze

        ret
      end

      def validate #:nodoc:
        ifconfig = IfConfig.new

        i = @h[:multicast_if]
        n = @h[:multicast_network]
        i = if i and n
              Log.warning "multicast_network is ignored because multicast_if is already given in the configuration file: #{@file}"
              i
            elsif i.nil? and n
              ifconfig.multicast_interface_by_network_address n
            elsif i.nil? and n.nil?
              ifconfig.default_interface_address
            else
              i
            end
        unless ifconfig.has_interface? i
          raise ConfigurationError, "The interface address described in #{@file} does not exist in this machine: #{i}"
        end
        @h[:multicast_if] = i

        @h[:hostname_for_client] ||= ifconfig.default_hostname
        @h[:hostname_for_client].sub!(/\..*/, '')

        ipaddress_check :multicast_address

        file_existence_check :basket_base_dir

        port_num_check :gateway_udp_command_port
        port_num_check :peer_tcp_command_port
        port_num_check :peer_unicast_udp_command_port
        port_num_check :peer_multicast_udp_command_port
        port_num_check :watchdog_command_port
        port_num_check :replication_tcp_command_port
        port_num_check :replication_udp_command_port
        port_num_check :replication_tcp_communication_port

        port_num_check :cmond_maintenance_port
        port_num_check :cpeerd_maintenance_port
        port_num_check :crepd_maintenance_port
        port_num_check :cmond_healthcheck_port
        port_num_check :cpeerd_healthcheck_port
        port_num_check :crepd_healthcheck_port

        positive_num_check :number_of_express_command_processor
        positive_num_check :number_of_regular_command_processor
        positive_num_check :number_of_basket_status_query_db
        positive_num_check :number_of_csm_controller
        positive_num_check :number_of_udp_response_sender
        positive_num_check :number_of_tcp_response_sender
        positive_num_check :number_of_multicast_command_sender
        positive_num_check :number_of_replication_db_client
        positive_num_check :number_of_replication_sender

        positive_num_check :period_of_alive_packet_sender
        positive_num_check :period_of_statistics_logger

        positive_num_check :replication_transmission_datasize

        file_existence_check :manipulator_socket if @h[:use_manipulator_daemon]

        user_check  :dir_w_user
        user_check  :dir_a_user
        user_check  :dir_d_user
        user_check  :dir_c_user

        group_check :dir_w_group
        group_check :dir_a_group
        group_check :dir_d_group
        group_check :dir_c_group

      end

      def required_check key #:nodoc:
        @h[key] or raise ConfigurationError, "#{key} is not specified in #{@file}"
      end

      def positive_num_check key #:nodoc:
        required_check key
        raise ConfigurationError, "#{key} in #{@file} is not a positive number: #{@h[key]}" unless @h[key] > 0
      end

      def port_num_check key #:nodoc:
        positive_num_check key
        # well-known port cannnot be set.
        raise ConfigurationError, "#{key} in #{@file} is invalid port number: #{@h[key]}" unless (1023 < @h[key] and @h[key] < 65536)
      end

      def file_existence_check key #:nodoc:
        required_check key
        File.exist? @h[key] or raise ConfigurationError, "A path #{key} in #{@file} does not exist: #{@h[key]}"
      end

      def ipaddress_check key #:nodoc:
        required_check key
        IPAddr.new(@h[key]) rescue raise ConfigurationError, "#{key} in #{@file} is invalid ipaddress: #{@h[key]}"
      end

      def user_check key #:nodoc:
        required_check key
        Etc.getpwnam(@h[key]) rescue raise ConfigurationError "#{key} in #{@file} is invalid user: #{@h[key]}"
      end

      def group_check key #:nodoc:
        required_check key
        Etc.getgrnam(@h[key]) rescue raise ConfigurationError "#{key} in #{@file} is invalid group: #{@h[key]}"
      end

    end

  end
end

