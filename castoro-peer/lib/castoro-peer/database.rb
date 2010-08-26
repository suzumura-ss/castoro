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

require 'castoro-peer/basket'
require 'castoro-peer/errors'

module Castoro
  module Peer

    class DbRequestQueryBasketStatus
      def initialize( basket, path_x = nil )
        @basket = basket or raise BadRequestError, 'No basket seems to be specified'
        @path_x = path_x
      end

      def execute
        b = @basket
        s, p = [], []
        if ( @path_x )
          File.exist?( @path_x ) and begin s.push S_WORKING     ; p.push @path_x ; end
        end
#        File.exist?( b.path_w ) and begin s.push S_WORKING     ; p.push @basket.path_w ; end
#        File.exist?( b.path_r ) and begin s.push S_REPLICATING ; p.push @basket.path_r ; end
        File.exist?( b.path_a ) and begin s.push S_ARCHIVED    ; p.push @basket.path_a ; end
        File.exist?( b.path_d ) and begin s.push S_DELETED     ; p.push @basket.path_d ; end
        case s.size
        when 0 ; S_ABCENSE
        when 1 ; s.shift
        else
          # S_CONFLICT
          raise BasketConflictInternalServerError, "The status of basket is conflicted: #{p.join(' ')}"
        end
      end
    end
    
  end
end

if $0 == __FILE__
  module Castoro
    module Peer
    end
  end
end
