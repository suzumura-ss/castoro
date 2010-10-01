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

require "castoro-common"

require "logger"
require "thread"

module Castoro

  class WorkersError < CastoroError; end

  class Workers

    DEFAULT_SETTINGS = {
      :name => "workers",
    }

    ##
    # initialize.
    #
    # === Args
    #
    # +logger+::
    #   the logger.
    # +count+::
    #   count of worker threads.
    # +optios+::
    #   workers options.
    #
    # Valid options for +options+ are:
    #
    #   [:name]             default is "workers". symbol of component.
    #                       It is used for exception message and log message.
    #
    def initialize logger, count, options = {}
      raise WorkersError, "zero and negative number cannot be set to count" unless count.to_i > 0

      @logger = logger || Logger.new(nil)
      @count  = count.to_i

      options.reject! { |k, v| !(DEFAULT_SETTINGS.keys.include? k.to_sym)}
      DEFAULT_SETTINGS.merge(options).each { |k, v|
        instance_variable_set "@#{k}", v
      }

      @locker = Mutex.new
    end

    ##
    # start workers.
    #
    def start
      @locker.synchronize {
        raise WorkersError, "#{@name} already started." if alive?
        @threads = (1..@count).map {
          Thread.fork {
            ThreadGroup::Default.add Thread.current
            worker_loop
          }
        }
      }
    end

    ##
    # stop workers.
    #
    # === Args
    #
    # +force+::
    #   force shudown.
    #
    def stop force = false
      @locker.synchronize {
        raise WorkersError, "#{@name} already stopped." unless alive?

        if force
          @threads.each { |t| t.kill }
        else
          @threads.each { |t| t[:dying] = true }
          @threads.each { |t| t.wakeup rescue nil }
          @threads.each { |t| t.join } unless force
        end
        @threads = nil
      }
    end

    ##
    # return the state of alive or not alive.
    #
    def alive?; !! @threads; end

    private

    ##
    # Worker loop.
    #
    def worker_loop
      @logger.info { "starting #{@name}... #{Thread.current}" }

      until Thread.current[:dying]
        work
      end

      @logger.info { "stopping #{@name}... #{Thread.current}" }
    end

    ##
    # work action.
    #
    # In the inherited class, #work is done in override,
    # and behavior is decided.
    #
    def work
      sleep 3
    end

  end
end

