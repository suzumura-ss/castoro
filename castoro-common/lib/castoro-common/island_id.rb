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

module Castoro
  class IslandIdError < CastoroError; end
  class IslandId
    def initialize string
      if string =~ /^((25[0-5]|2[0-4]\d|1\d\d||[1-9]\d|\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d||[1-9]\d|\d)$/
        string = string.split('.', 4).map { |o| '%02x' % o.to_i }.join
      end
      raise IslandIdError, "island id parse error." unless string =~ /^[0123456789abcdef]{8}$/
      @string = string.dup.freeze
      freeze
    end

    def to_s; @string; end
    def to_str; to_s; end

    def to_ip
      [ 0..1, 2..3, 4..5, 6..7 ].map { |r| @string[r].to_i(16) }.join('.')
    end

    def == other
      return true if self.equal? other
      return false unless other.kind_of? Castoro::IslandId
      return false if other.nil?
      to_s == other.to_s
    end

    def to_island; self; end
  end
end

# helpers
class String
  def to_island
    Castoro::IslandId.new self   
  end
end
class Object
  def to_island
    self.to_s.to_island
  end
end

