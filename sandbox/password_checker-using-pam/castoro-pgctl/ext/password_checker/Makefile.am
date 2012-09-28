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

bin_PROGRAMS = password_checker
password_checker_SOURCES = main.c conversation.c
password_checker_LDADD = -lpam $(LIB_PAM_MISC)

install-exec-hook:
	/bin/chown root:root $(bindir)/$(bin_PROGRAMS)
	/bin/chmod u+s $(bindir)/$(bin_PROGRAMS)
