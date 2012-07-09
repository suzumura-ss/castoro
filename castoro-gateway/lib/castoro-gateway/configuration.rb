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

require "castoro-gateway"

module Castoro; class Gateway
  class Configuration
    include Enumerable

    COMMON_SETTINGS = {
      "require" => [],
      "logger" => " Proc.new { |logfile| Logger.new(logfile) } ",
      "user" => "castoro",
      "group" => nil,
      "workers" => 5,
      "loglevel" => Logger::INFO,
      "type" => "original",
    }.freeze
    CACHE_SETTINGS = {
      "class" => nil,
      "replication_count" => 3,
      "watchdog_limit" => 15,
      "return_peer_number" => 5,
      "cache_size" => 500000,
      "filter" => nil,
      "basket_basedir" => "/expdsk",
      "options" => {},
    }.freeze
    CONVERTER_SETTINGS = {
      "Dec40Seq" => "0-65535",
      "Hex64Seq" => "",
    }

    DEFAULT_SETTINGS = {
      "original" => {
        "type" => "original",
        "gateway_console_tcpport" => 30110,
        "gateway_comm_udpport" => 30111,
        "gateway_learning_udpport_multicast" => 30109,
        "gateway_watchdog_udpport_multicast" => 30113,
        "gateway_watchdog_logging" => false,
        "gateway_comm_ipaddr_multicast" => "239.192.1.1",
#       "gateway_comm_device_multicast" => "eth0",
        "gateway_comm_device_addr" => nil,         # Specification is indispensable
        "peer_comm_udpport_multicast" => 30112,
        "peer_comm_ipaddr_multicast" => "239.192.1.1",
#       "peer_comm_device_multicast" => "eth0",
        "peer_comm_device_addr" => nil,              # Specification is indispensable 
      },
      "master" => {
        "type" => "master",
        "gateway_comm_udpport" => 30111,
        "gateway_learning_udpport_multicast" => 30109,
        "master_comm_ipaddr_multicast" => "239.192.254.254",
        "island_comm_udpport_broadcast" => 30108,
 #      "island_comm_device_multicast" => "eth0",
        "island_comm_device_addr" => nil,            # Specification is indispensable 
      },
      "island" => {
        "type" => "island",
        "gateway_console_tcpport" => 30110,
        "gateway_learning_udpport_multicast" => 30109,
        "gateway_watchdog_udpport_multicast" => 30113,
        "gateway_watchdog_logging" => false,
        "gateway_comm_ipaddr_multicast" => "239.192.1.1",
#       "gateway_comm_device_multicast" => "eth0",
        "gateway_comm_device_addr" => nil,          # Specification is indispensable 
        "peer_comm_udpport_multicast" => 30112,
        "peer_comm_ipaddr_multicast" => "239.192.1.1",
#       "peer_comm_device_multicast" => "eth0",
        "peer_comm_device_addr" => nil,            # Specification is indispensable 
        "master_comm_ipaddr_multicast" => "239.192.254.254",
        "island_comm_udpport_broadcast" => 30108,
        "island_comm_ipaddr_multicast" => nil,
#       "island_comm_device_multicast" => "eth0",  
        "island_comm_device_addr" => nil,          # Specification is indispensable 
      },
    }.freeze

    @@set_default_options = Proc.new { |options|
      options ||= {}
      {}.tap { |result|
        COMMON_SETTINGS.each { |k,v| result[k] = options[k] || v }
        DEFAULT_SETTINGS[result["type"]].each { |k,v| result[k] = options[k] || v }

        if ["original", "island"].include?(result["type"])
          result["cache"] = {}; options["cache"] ||= {}
          CACHE_SETTINGS.each { |k,v| result["cache"][k] = options["cache"][k] || v }

          result["cache"]["basket_keyconverter"] = {}; options["cache"]["basket_keyconverter"] ||= {}
          CONVERTER_SETTINGS.each { |k,v| result["cache"]["basket_keyconverter"][k] = options["cache"]["basket_keyconverter"][k] || v }
        end
      }
    }

    def self.setting_template type = "original"
      unless ["original", "master", "island"].include?(type)
        raise ArgumentError, "type needs to be original, master, or island."
      end

      conf = @@set_default_options.call({
        "type" => type,
        "loglevel" => "<%= Logger::INFO %>",
        "island_comm_ipaddr_multicast" => "TODO: please specify multicast address",
      })
      "<% require 'logger' %>\n" <<
      { "default" => conf }.to_yaml.split(/(\r|\n|\r\n)/).select { |l| !l.strip.empty? }.join("\n")
    end

    def initialize options
      opt = @@set_default_options.call((options || {}).dup)
      @options = validate(opt)
      @options.freeze
      freeze
    end
     
    def each &block
      if block_given?
        self.tap { |opt| @options.each(&block) }
      else
        @options.each(&block) 
      end
    end
    
    def [] key; @options[key]; end
    
    def to_yaml opts = {}; @options.to_yaml(opts); end
    
    def == other
      return true  if self.equal?(other)
      return false unless self.class == other.class
      return @options == other.instance_variable_get(:@options)
    end

    def original?; @options["type"] == "original"; end
    def master?  ; @options["type"] == "master"; end
    def island?  ; @options["type"] == "island"; end

    def is_original_when          ; yield if original?; end
    def is_original_or_master_when; yield if original? or master?; end
    def is_original_or_island_when; yield if original? or island?; end
    def is_master_when            ; yield if master?; end
    def is_master_or_original_when; yield if master? or original?; end
    def is_master_or_island_when  ; yield if master? or island?; end
    def is_island_when            ; yield if island?; end
    def is_island_or_original_when; yield if island? or original?; end
    def is_island_or_master_when  ; yield if island? or master?; end

    private

    def validate options
      options.tap { |opt|
        opt["type"] ||= "original"
        case opt["type"]
        when "original"; validate_original(opt)
        when "master"  ; validate_master(opt)
        when "island"  ; validate_island(opt)
        else           ; raise ArgumentError, "type needs to be original, master, or island."
        end
      }
    end

    def validate_original options
      if options["gateway_comm_device_addr"] == nil || options["peer_comm_device_addr"] == nil then
        raise ArgumentError, "gateway_comm_device_addr and peer_comm_device_addr have indispensable specification at the time of initialization."
      end 

      check_port_number       options, "gateway_console_tcpport"
      check_port_number       options, "gateway_comm_udpport"
      check_port_number       options, "gateway_learning_udpport_multicast"
      check_port_number       options, "gateway_watchdog_udpport_multicast"
      boolean_normalize       options, "gateway_watchdog_logging"
      check_multicast_address options, "gateway_comm_ipaddr_multicast"

#     check_network_interface options, "gateway_comm_device_multicast"
      check_ip_address        options, "gateway_comm_device_addr" 
      
      check_port_number       options, "peer_comm_udpport_multicast"
      check_multicast_address options, "peer_comm_ipaddr_multicast"

#     check_network_interface options, "peer_comm_device_multicast"
      check_ip_address        options, "peer_comm_device_addr"
    end

    def validate_master options
     if options["island_comm_device_addr"] == nil then
        raise ArgumentError, "island_comm_device_addr has indispensable specification at the time of initialization."
      end 

      check_port_number       options, "gateway_comm_udpport"
      check_port_number       options, "gateway_learning_udpport_multicast"
      check_multicast_address options, "master_comm_ipaddr_multicast"
      check_port_number       options, "island_comm_udpport_broadcast"

#     check_network_interface options, "island_comm_device_multicast"
      check_ip_address        options, "island_comm_device_addr" 
    end

    def validate_island options
      if options["gateway_comm_device_addr"] == nil ||
         options["peer_comm_device_addr"] == nil ||
         options["island_comm_device_addr"] == nil then
        raise ArgumentError, "gateway_comm_device_addr and island_comm_device_addr and peer_comm_device_addr \
                              have indispensable specification at the time of initialization."
      end 

      check_port_number       options, "gateway_console_tcpport"
      check_port_number       options, "gateway_learning_udpport_multicast"
      check_port_number       options, "gateway_watchdog_udpport_multicast"
      boolean_normalize       options, "gateway_watchdog_logging"
      check_multicast_address options, "gateway_comm_ipaddr_multicast"

#     check_network_interface options, "gateway_comm_device_multicast"
      check_ip_address        options, "gateway_comm_device_addr" 

      check_port_number       options, "peer_comm_udpport_multicast"
      check_multicast_address options, "peer_comm_ipaddr_multicast"

#     check_network_interface options, "peer_comm_device_multicast"
      check_ip_address        options, "peer_comm_device_addr" 

      check_multicast_address options, "master_comm_ipaddr_multicast"
      check_port_number       options, "island_comm_udpport_broadcast"
      check_multicast_address options, "island_comm_ipaddr_multicast"

#     check_network_interface options, "island_comm_device_multicast"
      check_ip_address        options, "island_comm_device_addr" 
    end

    def check_port_number options, key
      raise ArgumentError, "#{key} should be positive number: #{options[key]}" if options[key].to_i <= 0
    end

    def boolean_normalize options, key
      options[key] = !! options[key]
    end

    def check_multicast_address options, key
      octets = options[key].split('.').map(&:to_i)
      raise ArgumentError, "#{key} should be Class-D ip address: #{options[key]}" unless octets.size == 4
      raise ArgumentError, "#{key} should be Class-D ip address: #{options[key]}" unless octets.all? { |o| (0..255).include?(o) }
      raise ArgumentError, "#{key} should be Class-D ip address: #{options[key]}" unless ((octets[0] & 255) >> 4) == 14
    end

    def check_ip_address options, key
      octets = options[key].split('.').map(&:to_i)
      raise ArgumentError, "#{key} should be Class-D ip address: #{options[key]}" unless octets.size == 4
      raise ArgumentError, "#{key} should be Class-D ip address: #{options[key]}" unless octets.all? { |o| (0..255).include?(o) }
    end


#    def check_network_interface options, key
#      unless Castoro::Utils.network_l[options[key].to_s]
#        raise ArgumentError, "#{key} invalid network interface name: #{options[key]}"
#      end
#    end

  end
end; end

