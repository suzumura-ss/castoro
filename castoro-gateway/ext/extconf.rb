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

# This extention will require a C++ compiler and its linker, instead of C ones, 
# during compilation. The linker, however, seems to be assgined with ld by mkmf.
# That causes a problem in finding libstdc++.so because ld does not know about it.
# In contrast, the C++ compiler knows where it is because the libstdc++.so comes
# with the C++ compiler. 
# By replacing LDSHARED ( default to "ld -G" or so ) in the configuration of Ruby
# with a "c++-compiler -shared", LDSHAREDXX will be also "c++-compiler -shared"
require 'rbconfig'
CONFIG = RbConfig::MAKEFILE_CONFIG
cxx = CONFIG['CXX'].split(' ')[0]
CONFIG['LDSHARED'] = "#{cxx} -shared"

require 'mkmf'
$CFLAGS="-g -Wall -DRUBY_VERSION=\\\"#{RUBY_VERSION.split('.')[0,2].join('.')}\\\""
create_makefile('castoro-gateway/cache')
