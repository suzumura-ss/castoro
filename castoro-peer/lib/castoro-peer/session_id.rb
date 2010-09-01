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

require 'thread'
require 'singleton'

module Castoro

  class SequentialNGenerator
    include Singleton

    attr_accessor :maximum

    def initialize( maximum = 999 )
      @maximum = maximum
      @x = 0
      @m = Mutex.new
    end

    def generate
      @m.synchronize {
        @x = 0 if @maximum <= @x
        @x += 1
      }
    end
  end


  class SessionIdGenerator < SequentialNGenerator
    def initialize
      super( 100000000 - 1 )
    end

    def generate
      lower_digit = super
      upper_digit = Time.now.to_i % 100000000
      upper_digit * 100000000 + lower_digit
    end
  end

end


if $0 == __FILE__
  15.times { p Castoro::SessionIdGenerator.instance.generate; sleep 0.3 }
end

__END__

$ ruby number_generator.rb
6976964000000001
6976964000000002
6976964100000003
6976964100000004
6976964100000005
6976964100000006
6976964200000007
6976964200000008
6976964200000009
6976964300000010
6976964300000011
6976964300000012
6976964400000013
6976964400000014
6976964400000015
