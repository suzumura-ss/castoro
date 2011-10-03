/*
 *   Copyright 2010 Ricoh Company, Ltd.
 *
 *   This file is part of Castoro.
 *
 *   Castoro is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Lesser General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   Castoro is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Lesser General Public License for more details.
 *
 *   You should have received a copy of the GNU Lesser General Public License
 *   along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "ruby/ruby.h"
#include "ruby/io.h"
#include "ruby/util.h"

#include <sys/types.h>
#include <sys/socket.h>

#define rb_sys_fail_path(path) rb_sys_fail(NIL_P(path) ? 0 : RSTRING_PTR(path))

static VALUE
bsock_setsockopt_SOL_SOCKET_SO_RCVTIMEO(VALUE sock, VALUE tv_sec, VALUE tv_usec)
{
    struct timeval tv;
    rb_io_t *fptr;

    tv.tv_sec  = NUM2INT(tv_sec);
    tv.tv_usec = NUM2INT(tv_usec);

    GetOpenFile(sock, fptr);
    if (setsockopt(fptr->fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0)
	rb_sys_fail_path(fptr->pathv);

    return INT2FIX(0);
}

static VALUE
bsock_getsockopt_SOL_SOCKET_SO_ERROR(VALUE sock)
{
    int error;
    socklen_t len = sizeof(error);
    rb_io_t *fptr;

    GetOpenFile(sock, fptr);
    if (getsockopt(fptr->fd, SOL_SOCKET, SO_ERROR, &error, &len) < 0)
	rb_sys_fail_path(fptr->pathv);

    return INT2FIX(error);
}

void
Init_peersocket()
{
    VALUE c = rb_define_class("BasicSocket", rb_cIO);
    rb_define_method(c, "setsockopt_SOL_SOCKET_SO_RCVTIMEO", bsock_setsockopt_SOL_SOCKET_SO_RCVTIMEO, 2);
    rb_define_method(c, "getsockopt_SOL_SOCKET_SO_ERROR", bsock_getsockopt_SOL_SOCKET_SO_ERROR, 0);
}
