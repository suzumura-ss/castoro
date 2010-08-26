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

BINDIR = File.dirname(`which ruby`)

File.open("Makefile", "w") {|f|
  f.puts <<__MAKEFILE__

TARGET   = csm
OBJS     = csm.o

CXX	= /opt/sunstudio12.1/bin/CC
GETCONF	= /bin/getconf
CP	= /bin/cp
CHMOD	= /bin/chmod

# Ensure to use commands in the only directory /usr/bin
PATH    = /usr/bin

# See 'man lfcompile64' - transitional compilation environment
CFLAGS  = -D_LARGEFILE64_SOURCE `$(GETCONF) LFS64_CFLAGS`
LDFLAGS = `$(GETCONF) LFS64_LDFLAGS`
LIBS    = `$(GETCONF) LFS64_LIBS`

all: 
	PATH=$(PATH) $(MAKE) $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) -o $@ $(CFLAGS) $(OBJS) $(LDFLAGS) $(LIBS)

.cxx.o:
	$(CXX) -o $@ $(CFLAGS) -c $<

install: $(TARGET)
	$(CP) $(TARGET) ../$(TARGET)
	$(CHMOD) 4775 ../$(TARGET)

clean:
	/bin/rm -f $(TARGET) $(OBJS) Makefile

.SUFFIXES: .cxx .o

.PHONY: all install clean

__MAKEFILE__
}
