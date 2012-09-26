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
        validate
        @data[ :type_id_rangesHash ] = Hash.new.tap do |h|
          @services.each do |s|
            s.validate
            h[ s[ :basket_keyconverter ] ] = s[ :type_id_ranges ]
          end
        end
        @data
      rescue => e
        raise ConfigurationError, "#{e.class} \"#{e.message}\" #{e.backtrace.slice(0,5).inspect}"
      end

      private

      def validate
        hostname = @data[ :peer_hostname ]
        groups = @data[ :StorageGroupsData ]
        g = groups.select { |a| a.include? hostname }
        g.flatten!
        unless g.index( hostname )
          raise ConfigurationError, "Hostname #{hostname} is not included in #{@global[ :config_group_file ]}"
        end
      end

      def load_configuration_file file
        section = nil
        File.open( file , "r:binary" ) do |f|  # Any character encoding such as UTF-8 is accepted
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
            raise ConfigurationError, "#{e}: #{file}:#{$.}: #{line.chomp}"
          end
        end
      end

      def load_storage_hosts_file
        @data[ :StorageHostsData ] = YAML::load_file( @global[ :config_host_file ] )
      end
      
      def load_storage_groups_file
        @data[ :StorageGroupsData ] = JSON::parse( IO.read @global[ :config_group_file ] )
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
                         when :octal   # deal it as a string. ex. "0777"
                           value.match( /\A0\d+\Z/ ) or raise ArgumentError, "Invalid octal number"
                           value
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
                :peer_hostname                              => [ :optional,  :string ],
                :gateway_comm_ipaddr_multicast              => [ :optional,  :string ],
                :gateway_comm_ipaddr_network                => [ :optional,  :string ],
                :gateway_comm_ipaddr_nic                    => [ :optional,  :string ],
                :peer_comm_ipaddr_multicast                 => [ :optional,  :string ],
                :peer_comm_ipaddr_network                   => [ :optional,  :string ],
                :peer_comm_ipaddr_nic                       => [ :optional,  :string ],
                :gateway_learning_udpport_multicast         => [ :mandatory, :number ],
                :peer_comm_tcpport                          => [ :mandatory, :number ],
                :peer_comm_udpport_multicast                => [ :mandatory, :number ],
                :gateway_watchdog_udpport_multicast         => [ :mandatory, :number ],
                :crepd_transmission_tcpport                 => [ :mandatory, :number ],
                :crepd_registration_udpport                 => [ :mandatory, :number ],
                :cmond_maintenance_tcpport                  => [ :mandatory, :number ],
                :cpeerd_maintenance_tcpport                 => [ :mandatory, :number ],
                :crepd_maintenance_tcpport                  => [ :mandatory, :number ],
                :cmond_healthcheck_tcpport                  => [ :mandatory, :number ],
                :cpeerd_healthcheck_tcpport                 => [ :mandatory, :number ],
                :crepd_healthcheck_tcpport                  => [ :mandatory, :number ],
                :cpeerd_number_of_udp_command_processor     => [ :mandatory, :number ],
                :cpeerd_number_of_tcp_command_processor     => [ :mandatory, :number ],
                :cpeerd_number_of_basket_status_query_db    => [ :mandatory, :number ],
                :cpeerd_number_of_csm_controller            => [ :mandatory, :number ],
                :cpeerd_number_of_udp_response_sender       => [ :mandatory, :number ],
                :cpeerd_number_of_tcp_response_sender       => [ :mandatory, :number ],
                :cpeerd_number_of_multicast_command_sender  => [ :mandatory, :number ],
                :cpeerd_number_of_replication_db_client     => [ :mandatory, :number ],
                :cmond_period_of_watchdog_sender            => [ :mandatory, :number ],
                :cpeerd_period_of_statistics_logger         => [ :mandatory, :number ],
                :config_group_file                          => [ :mandatory, :string, :path ],
                :config_host_file                           => [ :mandatory, :string, :path ],
                :effective_user                             => [ :mandatory, :string ],
                :crepd_transmission_data_unit_size          => [ :mandatory, :number ],
                :crepd_number_of_replication_sender         => [ :mandatory, :number ],
                :manipulator_in_use                         => [ :mandatory, :boolean ],
                :manipulator_socket                         => [ :optional,  :string, :path ],
                :basket_basedir                             => [ :mandatory, :string, :path ],
                :dir_w_user                                 => [ :mandatory, :string ],
                :dir_w_group                                => [ :mandatory, :string ],
                :dir_w_perm                                 => [ :mandatory, :octal  ],
                :dir_a_user                                 => [ :mandatory, :string ],
                :dir_a_group                                => [ :mandatory, :string ],
                :dir_a_perm                                 => [ :mandatory, :octal  ],
                :dir_d_user                                 => [ :mandatory, :string ],
                :dir_d_group                                => [ :mandatory, :string ],
                :dir_d_perm                                 => [ :mandatory, :octal  ],
                :dir_c_user                                 => [ :mandatory, :string ],
                :dir_c_group                                => [ :mandatory, :string ],
                :dir_c_perm                                 => [ :mandatory, :octal  ],
                )
        end

        def validate
          super
          validate_hostname
          validate_manipulator
          validate_network :gateway_comm_ipaddr_nic, :gateway_comm_ipaddr_network
          validate_network :peer_comm_ipaddr_nic,    :peer_comm_ipaddr_network
        end

        private

        def validate_hostname
          unless @data[ :peer_hostname ]
            @data[ :peer_hostname ] = Ifconfig.instance.default_hostname
          end
        end

        def validate_manipulator
          if @data[ :manipulator_in_use ]
            @data[ :manipulator_socket ] or raise ConfigurationError, "manipulator_socket is not specified"
          end
        end

        def validate_network nic, network
          ip  = @data[ nic ]
          net = @data[ network ]
          if ip
            raise ConfigurationError, "Both #{nic} and #{network} are specified" if net
          else
            if net
              ip = Ifconfig.instance.multicast_interface_by_network_address( net )
            else
              ip = Ifconfig.instance.default_interface_address
            end
          end
          Ifconfig.instance.has_interface?( ip ) or raise ConfigurationError, "This host does not have the IP address: #{ip}"
          @data[ nic ] = ip
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
      f = '../../config/etc/peer.conf-sample-en.conf'
      Configurations.file = f

      x = Configurations.instance
      p x.gateway_comm_ipaddr_nic
      p x.type_id_rangesHash

      x.load()
      p x.gateway_comm_ipaddr_nic
      x.load( f )
      p x.gateway_comm_ipaddr_nic
      x.reload
      p x.gateway_comm_ipaddr_nic
    end
  end
end

__END__

time ruby -I ..  -e "require 'configurations'; 1000000.times{ x=Castoro::Peer::Configurations.instance.gateway_comm_ipaddr_nic }"
time ruby -I ..  -e "require 'configurations'; c=Castoro::Peer::Configurations.instance; 1000000.times{ x=c.gateway_comm_ipaddr_nic }"
