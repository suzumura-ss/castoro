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

#ifndef _STDINC_H_
#define _STDINC_H_

#include <sys/time.h>
#include <cstdio>
#include <string>
#include <map>
#include <vector>
#include <kcpolydb.h>
#include <ruby.h>

namespace kc = kyotocabinet;

// exceptions
extern VALUE cls_err_success;
extern VALUE cls_err_noimpl;
extern VALUE cls_err_invalid;
extern VALUE cls_err_norepos;
extern VALUE cls_err_noperm;
extern VALUE cls_err_broken;
extern VALUE cls_err_duprec;
extern VALUE cls_err_norec;
extern VALUE cls_err_logic;
extern VALUE cls_err_system;
extern VALUE cls_err_misc;

// id
extern ID id_equal;
extern ID id_puts;
extern ID id_to_s;
extern ID id_format;
extern ID id_to_ary;
extern ID id_to_a;
extern ID id_size;
extern ID id_less_eql;

// symvol
extern VALUE sym_watchdog_limit;
extern VALUE sym_logger;
extern VALUE sym_available;
extern VALUE sym_status;

// for stat keys.
extern VALUE stat_cache_expire;
extern VALUE stat_cache_requests;
extern VALUE stat_cache_hits;
extern VALUE stat_cache_count_clear;
extern VALUE stat_allocate_pages;
extern VALUE stat_free_pages;
extern VALUE stat_active_pages;
extern VALUE stat_have_status_peers;
extern VALUE stat_active_peers;
extern VALUE stat_readable_peers;

// other classes.
extern VALUE cls_mutex;

#endif // _STDINC_H_

