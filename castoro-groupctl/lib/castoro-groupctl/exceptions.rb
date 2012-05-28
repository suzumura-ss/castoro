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

module Castoro
  module Peer

    class Exceptions
      include Singleton

      def initialize
        @exceptions = []
      end

      def push e
        d = @exceptions.select do |x|  # duplication
          x.class == e.class && x.message == e.message && x.backtrace == e.backtrace
        end
        if d.size == 0
          @exceptions.push e
        end
      end

    end

    class ConfigurationError < StandardError ; end

    class BadRequestError < StandardError ; end
    class BadResponseError < StandardError ; end
    class ServerStatusError < StandardError ; end

    class CommandExecutionError < StandardError ; end
    class AlreadyExistsError < StandardError ; end
    class NotFoundError < StandardError ; end
    class PreconditionFailedError < StandardError ; end

    class InternalServerError < StandardError ; end
    class BasketConflictInternalServerError < InternalServerError ; end
    class UnknownBasketStatusInternalServerError < InternalServerError ; end


    # For replication
    class RetryableError < StandardError ; end
    class PermanentError < StandardError ; end
    class AlreadyExistsPermanentError < PermanentError ; end
    class InvalidArgumentPermanentError < PermanentError ; end

  end
end
