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

#include "stdinc.hxx"

// exceptions
VALUE cls_err_success;
VALUE cls_err_noimpl;
VALUE cls_err_invalid;
VALUE cls_err_norepos;
VALUE cls_err_noperm;
VALUE cls_err_broken;
VALUE cls_err_duprec;
VALUE cls_err_norec;
VALUE cls_err_logic;
VALUE cls_err_system;
VALUE cls_err_misc;

// id
ID id_equal;
ID id_puts;
ID id_to_s;
ID id_format;
ID id_to_ary;
ID id_to_a;
ID id_size;
ID id_less_eql;

// symvol
VALUE sym_watchdog_limit;
VALUE sym_peer_size;
VALUE sym_logger;
VALUE sym_available;
VALUE sym_status;

// for stat keys.
VALUE stat_cache_expire;
VALUE stat_cache_requests;
VALUE stat_cache_hits;
VALUE stat_cache_count_clear;
VALUE stat_allocate_pages;
VALUE stat_free_pages;
VALUE stat_active_pages;
VALUE stat_have_status_peers;
VALUE stat_active_peers;
VALUE stat_readable_peers;

// other classes.
VALUE cls_mutex;

