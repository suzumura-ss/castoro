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

require "json"

require "castoro-common/exception"
require "castoro-common/basket_key"
require "castoro-common/protocol"
require "castoro-common/receiver"
require "castoro-common/sender"
require "castoro-common/server"
require "castoro-common/workers"
require "castoro-common/workers_helper"

# When 1.9.x, It is possible to set it individually.
# by BasicSocket#do_not_reverse_lookup= method.
#
# However, If you need to work in both environments,
# BasicSocket.do_not_reverse_lookup= must be set globally using the
#
BasicSocket.do_not_reverse_lookup = true

