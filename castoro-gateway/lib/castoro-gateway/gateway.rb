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
      # configurations.
      @config = Castoro::Gateway::Configuration.new config

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
        @repository = @config.is_original_or_island_when {
          @@repository_class.new @logger, @config["cache"]
        }

        # start facade.
        @facade = @@facade_class.new @logger, @config
        @facade.start

        # start workers.
        @workers = case @config["type"]
                   when "original"
                     @@workers_class.new(
                         @logger,
                         @config["workers"],
                         @facade,
                         @repository,
                         @config["peer_multicast_addr"].to_s,
                         Castoro::Utils.network_interfaces[@config["peer_multicast_device"]][:ip],
                         @config["peer_multicast_port"].to_i,
                         nil
                     )
                   when "master"
                     @@master_workers_class.new(
                         @logger,
                         @config["workers"],
                         @facade,
                         Castoro::Utils.network_interfaces[@config["island_multicast_device"]][:broadcast],
                         Castoro::Utils.network_interfaces[@config["island_multicast_device"]][:ip],
                         @config["gateway_multicast_port"],
                         @config["island_broadcast_port"]
                     )
                   when "island"
                     @@workers_class.new(
                         @logger, @config["workers"],
                         @facade,
                         @repository,
                         @config["peer_multicast_addr"].to_s,
                         Castoro::Utils.network_interfaces[@config["peer_multicast_device"]][:ip],
                         @config["peer_multicast_port"].to_i,
                         @config["island_multicast_addr"].to_island
                     )
                   else
                     raise CastoroError, "type needs to be original, master, or island."
                   end
        @workers.start

        # start console server.
        @config.is_original_or_island_when {
          @console = @@console_server_class.new @logger, @repository, @config["gateway_console_port"].to_i
          @console.start
        }

        # start watchdog sender.
        @config.is_island_when {
          @watchdog_sender = @@watchdog_sender_class.new @logger, @repository, @config["island_multicast_addr"],
                                :dest_port => @config["gateway_multicast_port"],
                                :dest_host => @config["master_multicast_addr"],
                                :if_addr => Castoro::Utils.network_interfaces[@config["island_multicast_device"]][:ip]
          @watchdog_sender.start
        }
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
          when "original"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive? and
              @repository and @console and @console.alive?
            }
          when "master"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive?
            }
          when "island"
            Proc.new {
              @facade and @facade.alive? and @workers and @workers.alive? and
              @repository and @console and @console.alive? and
              @watchdog_sender and @watchdog_sender.alive?
            }
          else
            raise CastoroError, "type needs to be original, master, or island."
          end
        )
        !! (@alive_proc.call)
      }
    end
  end
end

