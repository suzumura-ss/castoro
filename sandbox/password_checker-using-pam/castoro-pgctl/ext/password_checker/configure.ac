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

AC_INIT(main.c)
AM_CONFIG_HEADER(config.h)
AM_INIT_AUTOMAKE(password_checker, 1.0)
AC_PROG_CC
AC_CHECK_LIB(pam_misc, misc_conv)
AC_CHECK_LIB(pam_misc, misc_conv, [LIB_PAM_MISC=-lpam_misc])
AC_SUBST([LIB_PAM_MISC])
AC_CHECK_HEADERS(security/pam_appl.h)
AC_CHECK_HEADERS(security/pam_misc.h)
AC_OUTPUT(Makefile)
