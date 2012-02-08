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
      "watchdog_limit" => 15,
      "return_peer_number" => 5,
      "cache_size" => 500000,
      "options" => {},
    }.freeze

    DEFAULT_SETTINGS = {
      "original" => {
        "type" => "original",
        "gateway_console_port" => 30110,
        "gateway_unicast_port" => 30111,
        "gateway_multicast_port" => 30109,
        "gateway_watchdog_port" => 30113,
        "gateway_watchdog_logging" => false,
        "peer_multicast_addr" => "239.192.1.1",
        "peer_multicast_device" => "eth0",
        "peer_multicast_port" => 30112,
      },
      "master" => {
        "type" => "master",
        "gateway_unicast_port" => 30111,
        "gateway_multicast_port" => 30109,
        "master_multicast_addr" => "239.192.254.254",
        "island_broadcast_port" => 30108,
        "island_multicast_device" => "eth0",
      },
      "island" => {
        "type" => "island",
        "gateway_console_port" => 30111,
        "gateway_multicast_port" => 30109,
        "gateway_watchdog_port" => 30113,
        "gateway_watchdog_logging" => false,
        "peer_multicast_addr" => "239.192.1.1",
        "peer_multicast_device" => "eth0",
        "peer_multicast_port" => 30112,
        "master_multicast_addr" => "239.192.254.254",
        "island_broadcast_port" => 30108,
        "island_multicast_addr" => nil,
        "island_multicast_device" => "eth0",
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
      })
      "<% require 'logger' %>\n" << ({ "default" => conf }.to_yaml)
    end

    def initialize options = {}
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

    def set_default_options options = {}
      {}.tap { |result|
        COMMON_SETTINGS.each { |k,v| result[k] = options[k] || v }
        DEFAULT_SETTINGS[result["type"]].each { |k,v| result[k] = options[k] || v }

        result["cache"] = {}; options["cache"] ||= {}
        CACHE_SETTINGS.each { |k,v| result["cache"][k] = options["cache"][k] || v }
      }
    end

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
      check_port_number       options, "gateway_console_port"
      check_port_number       options, "gateway_unicast_port"
      check_port_number       options, "gateway_multicast_port"
      check_port_number       options, "gateway_watchdog_port"
      boolean_normalize       options, "gateway_watchdog_logging"
      check_multicast_address options, "peer_multicast_addr"
      check_network_interface options, "peer_multicast_device"
      check_port_number       options, "peer_multicast_port"
    end

    def validate_master options
      check_port_number       options, "gateway_unicast_port"
      check_port_number       options, "gateway_multicast_port"
      check_multicast_address options, "master_multicast_addr"
      check_port_number       options, "island_broadcast_port"
      check_network_interface options, "island_multicast_device"
    end

    def validate_island options
      check_port_number       options, "gateway_console_port"
      check_port_number       options, "gateway_multicast_port"
      check_port_number       options, "gateway_watchdog_port"
      boolean_normalize       options, "gateway_watchdog_logging"
      check_multicast_address options, "peer_multicast_addr"
      check_network_interface options, "peer_multicast_device"
      check_port_number       options, "peer_multicast_port"
      check_multicast_address options, "master_multicast_addr"
      check_port_number       options, "island_broadcast_port"
      check_multicast_address options, "island_multicast_addr"
      check_network_interface options, "island_multicast_device"
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

    def check_network_interface options, key
      unless Castoro::Utils.network_interfaces[options[key].to_s]
        raise ArgumentError, "#{key} invalid network interface name: #{options[key]}"
      end
    end

  end
end; end

