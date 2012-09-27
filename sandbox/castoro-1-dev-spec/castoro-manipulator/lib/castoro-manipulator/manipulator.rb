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

require "logger"
require "yaml"
require "sync"

module Castoro #:nodoc:
  module Manipulator #:nodoc:

    class ManipulatorError < CastoroError; end

    ##
    # manipulator main class.
    #
    class Manipulator
      DEFAULT_SETTINGS = {
        "logger" => " Proc.new { |logfile| Logger.new(logfile) } ",
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
      # === Args
      #
      # +config+::
      #   manipulator configurations.
      # +logger+::
      #   the logger.
      #
      def initialize config = {}, logger = nil
        @config = DEFAULT_SETTINGS.merge(config || {})
        @logger = logger || Logger.new(STDOUT)
        @logger.level = @config["loglevel"].to_i

        @locker = Sync.new
      end

      ##
      # start manipulator daemon.
      #
      def start
        @locker.synchronize(:EX) {
          raise ManipulatorError, "manipulator already started." if alive?

          @logger.info { "*** castoro-manipulator starting. with config\n" + @config.to_yaml }

          # start facade.
          @facade = Server::UNIX.new @logger, @config["socket"], :sock_file_mode => 0666
          @facade.start

          # start workers.
          @workers = Workers.new @logger, @config["workers"], @facade, @config["base_directory"]
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
        @locker.synchronize(:EX) {
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
        @locker.synchronize(:SH) {
          !! (@facade and @facade.alive? and @workers and @workers.alive?)
        }
      end

    end

  end
end

