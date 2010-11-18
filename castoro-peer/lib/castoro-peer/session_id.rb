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

require "monitor"

module Castoro # :nodoc:
  module Peer # :nodoc:

    class SequenceGenerator

      DEFAULT_OPTIONS = {
        :increment => 1,
        :decorate_proc => Proc.new { |seq| seq },
      }

      ##
      # initialize.
      #
      def initialize numeric_scale, options = {}
        @options  = DEFAULT_OPTIONS.merge options
        @max_seed = 10 ** numeric_scale - 1

        @seed = 0
        @m = Monitor.new
      end

      ##
      # generate sequence number
      #
      def generate
        ret = @m.synchronize {
          @seed = 0 if @max_seed <= @seed
          @seed += @options[:increment]
        }
        @options[:decorate_proc].call ret
      end

    end

    class SessionIdGenerator < SequenceGenerator

      ##
      # initialize.
      #
      def initialize
        scale = 8
        cardinal = 10 ** scale
        super scale, decorate_proc: Proc.new { |seq|
                                      (Time.now.to_i % cardinal) * cardinal + seq
                                    }
      end

    end

  end
end

