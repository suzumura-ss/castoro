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

require "mkmf"

CONFIG["CC"]  = ENV["CC"]          if ENV["CC"]
CONFIG["CXX"] = ENV["CXX"]         if ENV["CXX"]
CONFIG["CPP"] = "#{ENV["CXX"]} -E" if ENV["CXX"]

dir_config('kyotocabinet')

home = ENV["HOME"]
ENV["PATH"] = ENV["PATH"] + ":/usr/local/bin:$home/bin:."
kccflags = `kcutilmgr conf -i 2>/dev/null`.chomp
kcldflags = `kcutilmgr conf -l 2>/dev/null`.chomp
kcldflags = kcldflags.gsub(/-l[\S]+/, "").strip
kclibs = `kcutilmgr conf -l 2>/dev/null`.chomp
kclibs = kclibs.gsub(/-L[\S]+/, "").strip

kccflags = "-I/usr/local/include" if(kccflags.length < 1)
kcldflags = "-L/usr/local/lib" if(kcldflags.length < 1)
kclibs = "-lkyotocabinet -lz -lstdc++ -lrt -lpthread -lm -lc" if(kclibs.length < 1)

Config::CONFIG["CPP"] = "g++ -E"

$CFLAGS = "-I. #{kccflags} -Wall #{$CFLAGS} -O2"
$LDFLAGS = "#{$LDFLAGS} -L. #{kcldflags}"
$libs = "#{$libs} #{kclibs}"

if have_header('kccommon.h')
  create_makefile('castoro-gateway-kyotocabinet/kyotocabinet')
end

