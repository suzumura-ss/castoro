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

require "logger"
require "yaml"
require "monitor"
require "socket"

module Castoro

  class GatewayError < CastoroError; end

  class Gateway

    DEFAULT_SETTINGS = {
      "require" => [],
      "logger" => " Proc.new { |logfile| Logger.new(logfile) } ",
      "user" => "castoro",
      "group" => nil,
      "workers" => 5,
      "loglevel" => Logger::INFO,
      "type" => "original",
      "gateway_console_port" => 30110,
      "gateway_unicast_port" => 30111,
      "gateway_multicast_port" => 30109,
      "gateway_watchdog_port" => 30113,
      "gateway_watchdog_logging" => false,
      "peer_multicast_addr" => "239.192.1.1",
      "peer_multicast_device_addr" => IPSocket::getaddress(Socket::gethostname),
      "peer_multicast_port" => 30112,
      "master_multicast_addr" => "239.192.254.254",
      "island_broadcast_addr" => nil,
      "island_broadcast_port" => 30108,
      "island_multicast_addr" => nil,
      "island_multicast_device_addr" => IPSocket::getaddress(Socket::gethostname),
      "cache" => {
        "watchdog_limit" => 15,
        "return_peer_number" => 5,
        "cache_size" => 500000,
      },
    }
    SETTING_TEMPLATE = "" <<
      "<% require 'logger' %>\n" <<
      {
        "default" => DEFAULT_SETTINGS.merge(
          "loglevel" => "<%= Logger::INFO %>",
          "peer_multicast_device_addr" => "<%= `/sbin/ip -o addr| sed -ne '/ eth0 *inet /p;'`.split[3].to_s.split('/')[0] %>"
        )
      }.to_yaml

    ##
    # for test.
    #
    # To replace the class for which Gateway depends with Mock.
    #
    # <pre>
    # # Facade is replaced with FacadeMock.
    # Gateway.class_variable_set :@@facade_class = FacadeMock
    # 
    # # test code that uses FacadeMock...
    # test_foo
    # test_bar
    # 
    # # re-init.
    # Gateway.dependency_classes_init
    # </pre>
    #
    def self.dependency_classes_init
      @@facade_class          = Facade
      @@workers_class         = Workers
      @@repository_class      = Repository
      @@console_server_class  = ConsoleServer
      @@watchdog_sender_class = WatchdogSender
      @@master_workers_class  = MasterWorkers
    end
    dependency_classes_init

    def initialize config = {}, logger = nil
      @config = merge_r DEFAULT_SETTINGS,(config || {})
      @logger = logger || Logger.new(STDOUT)
      @logger.level = @config["loglevel"].to_i
      @locker = Monitor.new
    end

    ##
    # start Castoro::Gateway daemon.
    #
    def start
      @locker.synchronize {
        raise GatewayError, "gateway already started." if alive?

        @logger.info { "*** castoro-gateway starting. with config\n" + @config.to_yaml }

        @unicast_count = 0

        # start repository.
        if ["original", "island"].include?(@config["type"])
          @repository = @@repository_class.new @logger, @config["cache"]
        end

        # start facade.
        @facade = @@facade_class.new @logger, @config
        @facade.start

        mc_addr   = @config["peer_multicast_addr"].to_s
        mc_device = @config["peer_multicast_device_addr"].to_s
        mc_port   = @config["peer_multicast_port"].to_i
        island    = @config["island_multicast_addr"] ? @config["island_multicast_addr"].to_island : nil

        # start workers.
        if ["master"].include?(@config["type"])
          @workers = @@master_workers_class.new @logger,
                                                @config["workers"],
                                                @facade,
                                                @config["island_broadcast_addr"],
                                                @config["island_multicast_device_addr"],
                                                @config["gateway_multicast_port"],
                                                @config["island_broadcast_port"]
        else
          @workers = @@workers_class.new @logger, @config["workers"], @facade, @repository, mc_addr, mc_device, mc_port, island
        end
        @workers.start

        # start console server.
        if ["original", "island"].include?(@config["type"])
          @console = @@console_server_class.new @logger, @repository, @config["gateway_console_port"].to_i, :host => "0.0.0.0"
          @console.start
        end

        # start watchdog sender.
        if ["island"].include?(@config["type"])
          if @config["master_multicast_addr"] and @config["island_multicast_device_addr"]
            @watchdog_sender = @@watchdog_sender_class.new @logger, @repository, @config["island_multicast_addr"],
                                  :dest_port => @config["gateway_multicast_port"],
                                  :dest_host => @config["master_multicast_addr"],
                                  :if_addr => @config["island_multicast_device_addr"]
            @watchdog_sender.start
          end
        end
      }
    end

    ##
    # stop Castoro::Gateway daemon.
    #
    # === Args
    #
    # +force+::
    #   force shutdown.
    #
    def stop force = false
      @locker.synchronize {
        raise GatewayError, "gateway already stopped." unless alive?
        
        @facade.stop if @facade
        @facade = nil

        @workers.stop force if @workers
        @workers = nil

        @console.stop if @console
        @console = nil

        @watchdog_sender.stop if @watchdog_sender
        @watchdog_sender = nil

        @repository = nil

        @logger.info { "*** castoro-gateway stopped." }
      }
    end

    ##
    # return the state of alive or not alive.
    #
    def alive?
      @locker.synchronize {
        @alive_proc ||= (
          case @config["type"]
          when "master"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive?
            }
          when "island"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive? and
              @repository and @console and @console.alive? and @watchdog_sender and @watchdog_sender.alive?
            }
          else # "original"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive? and
              @repository and @console and @console.alive?
            }
          end
        )
        @alive_proc.call
      }
    end

    private

    def merge_r old_hash, new_hash
      old_hash.merge(new_hash) do |key, old_val, new_val|
        old_val.kind_of?(Hash) ? merge_r(old_val, new_val) : new_val
      end
    end

  end
end
