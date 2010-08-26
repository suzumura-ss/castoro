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

require "rubygems"

require "castoro-manipulator"

require "logger"
require "yaml"
require "thread"

module Castoro
  class ManipulatorError < CastoroError; end

  class Manipulator
    DEFAULT_SETTINGS = {
      "user" => "root",
      "workers" => 3,
      "loglevel" => Logger::INFO,
      "socket" => "/var/castoro/manipulator.sock",
      "base_directory" => "/expdsk",
    }
    SETTING_TEMPLATE = "" <<
      "<% require 'logger' %>\n" <<
      {
        "default" => DEFAULT_SETTINGS.merge(
          "loglevel" => "<%= Logger::INFO %>"
        )
      }.to_yaml

    ##
    # initialize.
    #
    def initialize config = {}, logger = nil
      @config = merge_r DEFAULT_SETTINGS, (config || {})
      @logger = logger || Logger.new(STDOUT)
      @logger.level = @config["loglevel"].to_i

      @locker = Mutex.new
    end

    ##
    # start manipulator daemon.
    #
    def start
      @locker.synchronize {
        raise ManipulatorError, "manipulator already started." if alive?
        @logger.info { "*** castoro-manipulator starting. with config\n" + @config.to_yaml }

        # start facade.
        @facade = Server::UNIX.new @logger, @config["socket"], :sock_file_mode => 0666
        @facade.start

        # start workers.
        @workers = Manipulator::Workers.new @logger, @config["workers"], @facade, @config["base_directory"]
        @workers.start
      }
    end

    ##
    # stop manipulator daemon.
    #
    # === Args
    #
    # +force+::
    #   force shudown.
    #
    def stop force = false
      @locker.synchronize {
        raise ManipulatorError, "manipulator already stopped." unless alive?

        # stop workers.
        @workers.stop force
        @workers = nil

        # stop facade.
        @facade.stop
        @facade = nil

        @logger.info { "*** castoro-manipulator stopped." }
      }
    end

    ##
    # return the state of alive or not alive.
    #
    def alive?
      @facade and @facade.alive? and @workers and @workers.alive?
    end

    private

    ##
    # recursive hash merge.
    #
    def merge_r old_hash, new_hash
      old_hash.merge(new_hash) { |key, old_val, new_val|
        old_val.kind_of?(Hash) ? merge_r(old_val, new_val) : new_val
      }
    end
  end
end
