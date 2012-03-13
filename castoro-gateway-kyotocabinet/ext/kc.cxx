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
#include "cache.hxx"

static Cache*
cache_get(VALUE self)
{
  Cache* p;
  Data_Get_Struct(self, Cache, p);
  return p;
}

static void
cache_free(Cache* p)
{
  p->~Cache();
  ruby_xfree(p);
}

static void
cache_mark(Cache* p)
{
  p->mark();
}

static VALUE
cache_alloc(VALUE klass)
{
  Cache* p = (Cache*)ruby_xmalloc(sizeof(Cache));
  new( (void*)p ) Cache;
  return Data_Wrap_Struct(klass, cache_mark, cache_free, p);
}

/**
 * Castoro::Cache::KyotoCabinet#initialize(size, options = {}) -> self
 *
 * options: :logger :watchdog_limit
 */
static VALUE
rb_kc_init(int argc, VALUE* argv, VALUE self)
{
  Cache* p = cache_get(self);

  VALUE size, opt;
  if (rb_scan_args(argc, argv, "11", &size, &opt) == 1) {
    opt = rb_hash_new();
  }
  Check_Type(opt, T_HASH);

  p->init(size, opt);

  return Qnil;
}

/**
 * Castoro::Cache::KyotoCabinet#find(content, type, rev) -> array of peer(s).
 */
static VALUE
rb_kc_find(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  Cache* p = cache_get(self);
  return p->find(_c, _t, _r);
}

/**
 * Castoro::Cache::KyotoCabinet#find_peers(require_spaces = nil) -> array of peer(s).
 */
static VALUE
rb_kc_find_peers(int argc, VALUE* argv, VALUE self)
{
  Cache* p = cache_get(self);
  VALUE require_spaces;
  if (rb_scan_args(argc, argv, "01", &require_spaces) == 0) {
    return p->findPeers();
  } else {
    return p->findPeers(require_spaces);
  }
}

/**
 * Castoro::Cache::KyotoCabinet#insert_element(peer, content, type, rev) -> self
 */
static VALUE
rb_kc_insert_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r)
{
  Cache* p = cache_get(self);
  Check_Type(_p, T_STRING);
  p->insertElement(_p, _c, _t, _r);
  return self;
}

/**
 * Castoro::Cache::KyotoCabinet#erase_element(peer, content, type, rev) -> self
 */
static VALUE
rb_kc_erase_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r)
{
  Cache* p = cache_get(self);
  Check_Type(_p, T_STRING);
  p->eraseElement(_p, _c, _t, _r);
  return self;
}

/**
 * Castoro::Cache::KyotoCabinet#get_peer_status(peer) -> array of status
 */
static VALUE
rb_kc_get_peer_status(VALUE self, VALUE _p)
{
  Cache* p = cache_get(self);
  Check_Type(_p, T_STRING);
  return p->getPeerStatus(_p);
}

/**
 * Castoro::Cache::KyotoCabinet#set_peer_status(peer, status) -> array of status
 */
static VALUE
rb_kc_set_peer_status(VALUE self, VALUE _p, VALUE _h)
{
  Cache* p = cache_get(self);
  Check_Type(_p, T_STRING);
  Check_Type(_h, T_HASH);
  p->setPeerStatus(_p, _h);
  return _h;
}

/**
 * Castoro::Cache::KyotoCabinet#dump(io, peers = nil) -> self
 */
static VALUE
rb_kc_dump(int argc, VALUE* argv, VALUE self)
{
  Cache* p = cache_get(self);
  VALUE file, peer;
  if (rb_scan_args(argc, argv, "11", &file, &peer) == 1) {
    peer = Qnil;
  }

  if (RTEST(peer)) {
    p->dump(file, peer);
  } else {
    p->dump(file);
  }
  return self;
}

/**
 * Castoro::Cache::Kyotocabinet#stat(key) -> num of status
 */
static VALUE
rb_kc_stat(VALUE self, VALUE _k)
{
  Cache* p = cache_get(self);
  Check_Type(_k, T_FIXNUM);
  return p->stat(_k);
}

extern "C" void
Init_kyotocabinet()
{
  rb_require("rubygems");
  rb_eval_string("require 'castoro-gateway'"); // TODO: require gems-lib by c extension.

  VALUE castoro = rb_const_get(rb_mKernel, rb_intern("Castoro"));
  VALUE cache   = rb_const_get_at(castoro, rb_intern("Cache"));
  VALUE cerror  = rb_const_get_at(castoro, rb_intern("CastoroError"));

  // cache constants
  stat_cache_expire      = rb_const_get_at(cache, rb_intern("DSTAT_CACHE_EXPIRE"));
  stat_cache_requests    = rb_const_get_at(cache, rb_intern("DSTAT_CACHE_REQUESTS"));
  stat_cache_hits        = rb_const_get_at(cache, rb_intern("DSTAT_CACHE_HITS"));
  stat_cache_count_clear = rb_const_get_at(cache, rb_intern("DSTAT_CACHE_COUNT_CLEAR"));
  stat_allocate_pages    = rb_const_get_at(cache, rb_intern("DSTAT_ALLOCATE_PAGES"));
  stat_free_pages        = rb_const_get_at(cache, rb_intern("DSTAT_FREE_PAGES"));
  stat_active_pages      = rb_const_get_at(cache, rb_intern("DSTAT_ACTIVE_PAGES"));
  stat_have_status_peers = rb_const_get_at(cache, rb_intern("DSTAT_HAVE_STATUS_PEERS"));
  stat_active_peers      = rb_const_get_at(cache, rb_intern("DSTAT_ACTIVE_PEERS"));
  stat_readable_peers    = rb_const_get_at(cache, rb_intern("DSTAT_READABLE_PEERS"));

  // kc
  VALUE kc = rb_define_class_under(cache, "KyotoCabinet", rb_cObject);
  rb_define_alloc_func(kc, cache_alloc);
  rb_define_private_method(kc, "initialize", RUBY_METHOD_FUNC(rb_kc_init), -1);
  rb_define_method(kc, "find", RUBY_METHOD_FUNC(rb_kc_find), 3);
  rb_define_method(kc, "find_peers", RUBY_METHOD_FUNC(rb_kc_find_peers), -1);
  rb_define_method(kc, "insert_element", RUBY_METHOD_FUNC(rb_kc_insert_element), 4);
  rb_define_method(kc, "erase_element", RUBY_METHOD_FUNC(rb_kc_erase_element), 4);
  rb_define_method(kc, "get_peer_status", RUBY_METHOD_FUNC(rb_kc_get_peer_status), 1);
  rb_define_method(kc, "set_peer_status", RUBY_METHOD_FUNC(rb_kc_set_peer_status), 2);
  rb_define_method(kc, "dump", RUBY_METHOD_FUNC(rb_kc_dump), -1);
  rb_define_method(kc, "stat", RUBY_METHOD_FUNC(rb_kc_stat), 1);

  // exceptions
  VALUE err = rb_define_class_under(kc, "Error", cerror);
  cls_err_success = rb_define_class_under(err, "SUCCESS", err);
  cls_err_noimpl  = rb_define_class_under(err, "NOIMPL", err);
  cls_err_invalid = rb_define_class_under(err, "INVALID", err);
  cls_err_norepos = rb_define_class_under(err, "NOREPOS", err);
  cls_err_noperm  = rb_define_class_under(err, "NOPERM", err);
  cls_err_broken  = rb_define_class_under(err, "BROKEN", err);
  cls_err_duprec  = rb_define_class_under(err, "DUPREC", err);
  cls_err_norec   = rb_define_class_under(err, "NOREC", err);
  cls_err_logic   = rb_define_class_under(err, "LOGIC", err);
  cls_err_system  = rb_define_class_under(err, "SYSTEM", err);
  cls_err_misc    = rb_define_class_under(err, "MISC", err);

  // id
  id_equal    = rb_intern("==");
  id_puts     = rb_intern("puts");
  id_to_s     = rb_intern("to_s");
  id_format   = rb_intern("%");
  id_to_ary   = rb_intern("to_ary");
  id_to_a     = rb_intern("to_a");
  id_size     = rb_intern("size");
  id_less_eql = rb_intern("<=");

  // symvol
  sym_watchdog_limit = ID2SYM(rb_intern("watchdog_limit"));
  sym_logger         = ID2SYM(rb_intern("logger"));
  sym_available      = ID2SYM(rb_intern("available"));
  sym_status         = ID2SYM(rb_intern("status"));

  // other classes
  cls_mutex = rb_const_get(rb_mKernel, rb_intern("Mutex"));
}

