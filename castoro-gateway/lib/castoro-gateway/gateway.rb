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
      "user" => "castoro",
      "workers" => 5,
      "loglevel" => Logger::INFO,
      "multicast_addr" => "239.192.1.1",
      "multicast_device_addr" => IPSocket::getaddress(Socket::gethostname),
      "cache" => {
        "watchdog_limit" => 15,
        "return_peer_number" => 5,
        "cache_size" => 500000,
      },
      "gateway" => {
        "console_port" => 30110,
        "unicast_port" => 30111,
        "multicast_port" => 30109,
        "watchdog_port" => 30113,
        "watchdog_logging" => false,
      },
      "peer" => {
        "multicast_port" => 30112
      }
    }
    SETTING_TEMPLATE = "" <<
      "<% require 'logger' %>\n" <<
      {
        "default" => DEFAULT_SETTINGS.merge(
          "loglevel" => "<%= Logger::INFO %>",
          "multicast_device_addr" => "<%= `/sbin/ip -o addr| sed -ne '/ eth0 *inet /p;'`.split[3].to_s.split('/')[0] %>"
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
      @@console_server_class  = Server::TCP
      @@console_workers_class = ConsoleWorkers
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
        @repository = @@repository_class.new @logger, @config["cache"]

        # start facade.
        @facade = @@facade_class.new @logger, @config
        @facade.start

        mc_addr   = @config["multicast_addr"].to_s
        mc_device = @config["multicast_device_addr"].to_s
        mc_port   = @config["peer"]["multicast_port"].to_i

        # start workers.
        @workers = @@workers_class.new @logger, @config["workers"], @facade, @repository, mc_addr, mc_device, mc_port
        @workers.start

        # start console server.
        @console = @@console_server_class.new @logger, @config["gateway"]["console_port"].to_i, :host => "0.0.0.0"
        @console.start

        # start console workers.
        @console_workers = @@console_workers_class.new @logger, @console, self
        @console_workers.start
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
        
        @console_workers.stop force
        @console_workers = nil

        @console.stop
        @console = nil

        @workers.stop force
        @workers = nil

        @facade.stop
        @facade = nil

        @repository = nil

        @logger.info { "*** castoro-gateway stopped." }
      }
    end

    ##
    # return the state of alive or not alive.
    #
    def alive?
      @locker.synchronize {
        @facade and @facade.alive? and
          @workers and @workers.alive? and @repository and
          @console and @console.alive? and
          @console_workers and @console_workers.alive?
      }
    end

    ##
    # The status of hash representation is returned.
    #
    def status
      @locker.synchronize {
        raise GatewayError, "gateway is stopped." unless alive?

        @repository.status
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
