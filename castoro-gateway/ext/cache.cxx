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

#include "cache.hxx"

static VALUE rb_cCastoro, rb_cCache, rb_cPeers, rb_cPeer;
static ID operator_bracket = 0;
static ID operator_bracket_let = 0;
static ID operator_push = 0;
static ID operator_make_nfs_path = 0;
static ID operator_member_puts = 0;
static VALUE rb_cSym_status = Qundef;
static VALUE rb_cSym_available = Qundef;
static VALUE rb_cSym_empty = Qundef;
static VALUE stub = Qnil;
static const char make_nfs_path[] =
  "module Castoro; class Cache; def make_nfs_path(p, b, c, t, r);" \
  "   k = c / 1000;" \
  "   m, k = k.divmod 1000;" \
  "   g, m = m.divmod 1000;" \
  "   '%s:%s/%d/%03d/%03d/%d.%d.%d'%[p, b, g, m, k, c, t, r];" \
  "end; end; end;";
static const char member_puts[] =
  "module Castoro; class Cache; private; def member_puts(f, p, b, c, t, r);" \
  "   f.puts %[  #{p}: #{b}/#{c}.#{t}.#{r}]" \
  "end; end; end;";
static void check_ruby_version()
{
  static const char MKMF_RUBY_VERSION[] = RUBY_VERSION;
  static const char VERSION_CONFRICTED[]= "Ruby version confricted. Expected " RUBY_VERSION;

  VALUE rb_cStr_version = rb_eval_string("RUBY_VERSION");
  const char* version = StringValuePtr(rb_cStr_version);
  if(strncmp(MKMF_RUBY_VERSION, version, sizeof(MKMF_RUBY_VERSION)-1)!=0) {
    rb_throw(VERSION_CONFRICTED, rb_eFatal);
  }
}


namespace Castoro {
namespace Gateway {


//
// Castoro::Gateway::Cache
//
VALUE Cache::define_class(VALUE _p)
{
  VALUE c = rb_define_class_under(_p, "Cache", rb_cObject);

  rb_define_alloc_func(c, (rb_alloc_func_t)rb_alloc);
  rb_define_method(c, "initialize", RUBY_METHOD_FUNC(rb_init), 1);
  rb_define_method(c, "find",   RUBY_METHOD_FUNC(rb_find), 3);
  rb_define_method(c, "watchdog_limit=", RUBY_METHOD_FUNC(rb_set_expire), 1);
  rb_define_method(c, "watchdog_limit", RUBY_METHOD_FUNC(rb_get_expire), 0);
  rb_define_method(c, "stat",   RUBY_METHOD_FUNC(rb_stat), 1);
  rb_define_method(c, "peers",  RUBY_METHOD_FUNC(rb_alloc_peers), 0);
  rb_define_method(c, "dump",  RUBY_METHOD_FUNC(rb_dump), 1);
  rb_eval_string(make_nfs_path);
  rb_eval_string(member_puts);

  rb_define_const(c, "PAGE_SIZE", INT2NUM((sizeof(CachePage)+4096)&(~4095)));
  #define DEFINE_CONST(k, value)  rb_define_const(k, #value, INT2NUM(Database::value))
  DEFINE_CONST(c, DSTAT_CACHE_EXPIRE);
  DEFINE_CONST(c, DSTAT_CACHE_REQUESTS);
  DEFINE_CONST(c, DSTAT_CACHE_HITS);
  DEFINE_CONST(c, DSTAT_CACHE_COUNT_CLEAR);
  DEFINE_CONST(c, DSTAT_ALLOCATE_PAGES);
  DEFINE_CONST(c, DSTAT_FREE_PAGES);
  DEFINE_CONST(c, DSTAT_ACTIVE_PAGES);
  DEFINE_CONST(c, DSTAT_HAVE_STATUS_PEERS);
  DEFINE_CONST(c, DSTAT_ACTIVE_PEERS);
  DEFINE_CONST(c, DSTAT_READABLE_PEERS);
  #undef DEFINE_CONST

  return c;
}


VALUE Cache::rb_init(VALUE self, VALUE _p)
{
  static const char INVALID_PAGE_SIZE[]= "Page size must be > 0.";
  Cache* c = get_self(self);
  ssize_t pages = NUM2LL(_p);
  if(pages<=0) {
    rb_throw(INVALID_PAGE_SIZE, rb_eArgError);
  }
  c->m_db = new Database(pages);

  operator_bracket = rb_intern("[]");
  operator_bracket_let = rb_intern("[]=");
  operator_push = rb_intern("push");
  operator_make_nfs_path = rb_intern("make_nfs_path");
  operator_member_puts = rb_intern("member_puts");
  rb_cSym_status = ID2SYM(rb_intern("status"));
  rb_cSym_available = ID2SYM(rb_intern("available"));
  rb_cSym_empty = ID2SYM(rb_intern(""));

  return self;
}


VALUE Cache::rb_find(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  ArrayOfPeerWithBase a;
  bool removed = false;

  get_self(self)->find(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), a, removed);
  if(removed) return Qnil;

  VALUE result = rb_class_new_instance(0, &stub, rb_cArray);
  for(unsigned int i=0; i<a.size(); i++) {
    ID peer = a.at(i).peer;
    ID base = a.at(i).base;
    VALUE nfs = rb_funcall(self/*rb_cCache*/, operator_make_nfs_path, 5,
        ID2SYM(peer), ID2SYM(base), _c, _t, _r);
    rb_funcall(result, operator_push, 1, nfs);
  }
  return result;
}


VALUE Cache::rb_set_expire(VALUE self, VALUE _t)
{
  get_self(self)->set_expire(NUM2UINT(_t));
  return Qnil;
}


VALUE Cache::rb_get_expire(VALUE self)
{
  return UINT2NUM(get_self(self)->get_expire());
}


VALUE Cache::rb_stat(VALUE self, VALUE _k)
{
  return ULL2NUM(get_self(self)->stat((Database::DatabaseStat)NUM2INT(_k)));
}


VALUE Cache::rb_alloc_peers(VALUE self)
{
  Cache* c = get_self(self);
  return Data_Wrap_Struct(rb_cPeers, Peers::gc_mark, Peers::free, new Peers(*c));
}


// Dumper
class Dumper: public CacheDumperAbstract
{
public:
  inline Dumper(VALUE _s, VALUE _f) {

    rb_eval_string(member_puts);
    self = _s;
    f = _f;
    operator_member_puts = rb_intern("member_puts");
  };
  virtual inline ~Dumper() {};

  virtual bool operator()(uint64_t cid, uint32_t typ, uint32_t rev, ID peer, ID base) {
    rb_funcall(self, operator_member_puts, 6,
              f, ID2SYM(peer), ID2SYM(base), ULL2NUM(cid), LONG2FIX(typ), LONG2FIX(rev));
    return true;
  };

private:
  VALUE self, f;
  ID  operator_member_puts;
};

VALUE Cache::rb_dump(VALUE self, VALUE _f)
{
  Cache* c = get_self(self);
  Dumper dumper(self, _f);

  return (c->m_db->dump(dumper))? Qtrue: Qfalse;
}



//
// Castoro::Gateway::Peers
//
VALUE Peers::define_class(VALUE _p)
{
  VALUE c = rb_define_class_under(_p, "Peers", rb_cObject);

  rb_define_method(c, "find", RUBY_METHOD_FUNC(rb_find), -1);
  rb_define_method(c, "[]", RUBY_METHOD_FUNC(rb_alloc_peer), 1);

  return c;
}


VALUE Peers::rb_find(int argc, VALUE* argv, VALUE self)
{
  ArrayOfId a;
  VALUE _r;

  int num = rb_scan_args(argc, argv, "01", &_r);
  if (num == 0) {
    get_self(self)->m_cache->find(a);
  } else {
    get_self(self)->m_cache->find(NUM2ULL(_r), a);
  }

  VALUE result = rb_class_new_instance(0, &stub, rb_cArray);
  for(ArrayOfId::iterator it = a.begin(); it != a.end(); it++) {
    rb_funcall(result, operator_push, 1, rb_id2str(*it));
  }
  return result;
}


VALUE Peers::rb_alloc_peer(VALUE self, VALUE _p)
{
  Peers* p = get_self(self);
  return Data_Wrap_Struct(rb_cPeer, Peer::gc_mark, Peer::free, new Peer(*(p->m_cache), rb_to_id(_p)));
}


//
// Castoro::Gateway::Peer
//
VALUE Peer::define_class(VALUE _p)
{
  VALUE c = rb_define_class_under(_p, "Peer", rb_cObject);

  rb_define_method(c, "insert",  RUBY_METHOD_FUNC(rb_insert), 4);
  rb_define_method(c, "erase",  RUBY_METHOD_FUNC(rb_remove), 3);
  rb_define_method(c, "status=", RUBY_METHOD_FUNC(rb_set_status), 1);
  rb_define_method(c, "status",  RUBY_METHOD_FUNC(rb_get_status), 0);
  rb_define_method(c, "unlink",   RUBY_METHOD_FUNC(rb_unlink), 0);

  rb_define_const(c, "MAINTENANCE",  INT2NUM(DS_MAINTENANCE));
  rb_define_const(c, "ACTIVE",       INT2NUM(DS_ACTIVE));
  rb_define_const(c, "READONLY",     INT2NUM(DS_READONLY));

  return c;
}


VALUE Peer::rb_insert(VALUE self, VALUE _c, VALUE _t, VALUE _r, VALUE _b)
{
  Peer* p = get_self(self);
  p->m_cache->insert(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), p->m_peer, rb_to_id(_b));
  return Qnil;
}


VALUE Peer::rb_remove(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  Peer* p = get_self(self);
  p->m_cache->remove(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), p->m_peer);
  return Qnil;
}


VALUE Peer::rb_set_status(VALUE self, VALUE _s)
{
  Peer* p = get_self(self);
  PeerStatus s;

  p->m_cache->get_status(p->m_peer, s);
  VALUE d = rb_funcall(_s, operator_bracket, 1, rb_cSym_status);
  VALUE a = rb_funcall(_s, operator_bracket, 1, rb_cSym_available);
  if(rb_type(d)!=T_NIL) s.status = (DetailStatus)NUM2INT(d);
  if(rb_type(a)!=T_NIL) s.available = NUM2ULL(a);
  p->m_cache->set_status(p->m_peer, s);

  return rb_get_status(self);
}


VALUE Peer::rb_get_status(VALUE self)
{
  Peer* p = get_self(self);
  PeerStatus s;

  if(p->m_cache->get_status(p->m_peer, s)) {
    VALUE result = rb_class_new_instance(0, &stub, rb_cHash);
    rb_funcall(result, operator_bracket_let, 2, rb_cSym_status, INT2NUM(s.status));
    rb_funcall(result, operator_bracket_let, 2, rb_cSym_available, ULL2NUM(s.available));
    return result;
  }
  return Qnil;
}


VALUE Peer::rb_unlink(VALUE self)
{
  Peer* p = get_self(self);
  p->m_cache->remove(p->m_peer);
  return Qnil;
}



// CRuby-Extension init.
extern "C" void Init_cache(void)
{
  check_ruby_version();

  rb_cCastoro = rb_define_module("Castoro");
  rb_cCache = Cache::define_class(rb_cCastoro);
  rb_cPeers = Peers::define_class(rb_cCache);
  rb_cPeer = Peer::define_class(rb_cCache);
}

}
}
