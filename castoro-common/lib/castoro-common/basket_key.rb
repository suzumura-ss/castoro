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
  class BasketKeyError < CastoroError; end

  class BasketKey
    REGULAR_EXPRESSION = /[0-9]+\.[0-9]+\.[0-9]+/

    BASKET_TYPES = {
      :original => 0,
      :bitmap   => 1
    }

    def self.parse string
      s = string.to_s
      values = string.to_s.split "."
      raise BasketKeyError, "basket key parse error." unless values.length == 3

      args = values.map { |v|
        raise BasketKeyError, "basket key parse error." unless v =~ /^(0x)?[0-9A-Fa-f]+$/
        v.to_i($1 ? 16 : 10)
      }

      BasketKey.new *args
    end

    attr_reader :content, :type, :revision

    def initialize content, type, revision = 1
      raise BasketKeyError, "Nil cannot be set to content."  if content.nil?
      raise BasketKeyError, "Nil cannot be set to type."     if type.nil?
      raise BasketKeyError, "Nil cannot be set to revision." if revision.nil?

      if type.kind_of?(Symbol)
        raise BasketKeyError, "Unknown type." unless BASKET_TYPES.include?(type)
        type = BASKET_TYPES[type] if type.kind_of?(Symbol)
      end

      content  = content.to_i
      type     = type.to_i
      revision = revision.to_i

      raise BasketKeyError, "The negative number cannot be set to content"               if content < 0
      raise BasketKeyError, "The negative number cannot be set to type"                  if type < 0
      raise BasketKeyError, "The numerical value of 0 or less cannot be set to revision" if revision <= 0

      @content, @type, @revision = content, type, revision
    end

    def ==(other)
      self.content == other.content and
        self.type == other.type and
        self.revision == other.revision
    end

    def eql?(other)
      self == other
    end

    def hash
      prime = 31
      result = 1
      result = prime * result + self.content.hash
      result = prime * result + self.type.hash
      result = prime * result + self.revision.hash
      result
    end

    def to_s; "#{@content}.#{@type}.#{@revision}"; end

    def to_basket; self; end

    def type_name
      class_number = self.type
      BASKET_TYPES.select { |k, v|
        v == class_number
      }.first.to_a.first.to_s
    end

    def previous_revision
      revision = @revision - 1
      return nil if revision <= 0
      BasketKey.new @content, @type, revision
    end

    def next_revision
      revision = @revision + 1
      BasketKey.new @content, @type, revision
    end
  end
end

##
# helpers.
#
class String
  def to_basket
    Castoro::BasketKey.parse self
  end
end
class Object
  def to_basket
    self.to_s.to_basket
  end
end
