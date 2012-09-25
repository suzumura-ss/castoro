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

static ID operator_locker = 0;
static ID operator_synchronize = 0;
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
  "module Castoro; class Cache; def self.make_nfs_path(p, b, c, t, r);" \
  "   k = c / 1000;" \
  "   m, k = k.divmod 1000;" \
  "   g, m = m.divmod 1000;" \
  "   '%s:%s/%d/%03d/%03d/%d.%d.%d'%[p, b, g, m, k, c, t, r];" \
  "end; end; end;";
static const char member_puts[] =
  "module Castoro; class Cache; def self.member_puts(f, p, c, t, r);" \
  "   f.puts %[  #{p}: #{c}.#{t}.#{r}]" \
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

////////////////////////////////////////////////
//
// Implement of Dumper
//
////////////////////////////////////////////////
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

  virtual bool operator()(uint64_t cid, uint32_t typ, uint32_t rev, ID peer) {
    rb_funcall(rb_funcall(self, rb_intern("class"), 0), operator_member_puts, 5,
              f, ID2SYM(peer), ULL2NUM(cid), LONG2FIX(typ), LONG2FIX(rev));
    return true;
  };

private:
  VALUE self, f;
  ID  operator_member_puts;
};

class FilteredDumper: public CacheDumperAbstract
{
public:
  inline FilteredDumper(VALUE _s, VALUE _f, VALUE _p) {

    // round to array.
    switch(TYPE(_p)) {
      case T_ARRAY: break;
      default:
        if (rb_respond_to(_p, rb_intern("to_ary"))) {
          _p = rb_funcall(_p, rb_intern("to_ary"), 0);
        } else if (rb_respond_to(_p, rb_intern("to_a"))) {
          _p = rb_funcall(_p, rb_intern("to_a"), 0);
        } else {
          _p = rb_ary_new3(1, _p);
        }
        break;
    }
    size = NUM2UINT(rb_funcall(_p, rb_intern("size"), 0));
    peers = (ID*)ruby_xmalloc(sizeof(ID) * size);
    for (uint32_t i = 0; i < size; i++) {
      VALUE p = rb_ary_entry(_p, i);
      *(peers+i) = rb_to_id(p);
    }

    rb_eval_string(member_puts);
    self = _s;
    f = _f;
    operator_member_puts = rb_intern("member_puts");
  };
  virtual inline ~FilteredDumper() {
    if (peers) ruby_xfree(peers);
  };

  bool included(ID peer) {
    for (uint32_t i = 0; i < size; i++) {
      if (*(peers+i) == peer) return true;
    }
    return false;
  }

  virtual bool operator()(uint64_t cid, uint32_t typ, uint32_t rev, ID peer) {
    if (included(peer)) {
      rb_funcall(rb_funcall(self, rb_intern("class"), 0), operator_member_puts, 5,
                f, ID2SYM(peer), ULL2NUM(cid), LONG2FIX(typ), LONG2FIX(rev));
    }
    return true;
  };

private:
  VALUE self, f;
  ID* peers;
  uint32_t size;
  ID  operator_member_puts;
};


/////////////////////////////////////////////////////////////
//
// Implements of Castoro::Gateway::Cache
//
////////////////////////////////////////////////////////////

//
// define I/F method
//
VALUE Cache::define_class(VALUE _p)
{
  VALUE c = rb_define_class_under(_p, "Cache", rb_cObject);

  rb_define_alloc_func(c, (rb_alloc_func_t)rb_alloc);
  rb_define_method(c, "initialize", RUBY_METHOD_FUNC(rb_init), -1);
  rb_define_method(c, "find",   RUBY_METHOD_FUNC(rb_find), 3);
  rb_define_method(c, "watchdog_limit", RUBY_METHOD_FUNC(rb_get_expire), 0);
  rb_define_method(c, "stat",   RUBY_METHOD_FUNC(rb_stat), 1);
  rb_define_method(c, "peers",  RUBY_METHOD_FUNC(rb_alloc_peers), 0);
  rb_define_method(c, "dump",  RUBY_METHOD_FUNC(rb_dump), -1);
  rb_define_method(c, "find_peers", RUBY_METHOD_FUNC(rb_find_peers), -1);
  rb_define_method(c, "insert_element", RUBY_METHOD_FUNC(rb_insert_element), 4);
  rb_define_method(c, "erase_element", RUBY_METHOD_FUNC(rb_erase_element), 4);
  rb_define_method(c, "get_peer_status", RUBY_METHOD_FUNC(rb_get_peer_status), 1);
  rb_define_method(c, "set_peer_status", RUBY_METHOD_FUNC(rb_set_peer_status), 2);
  rb_define_method(c, "get_peers_info",  RUBY_METHOD_FUNC(rb_get_peers_info), 0);

  rb_define_private_method(c, "make_nfs_path", RUBY_METHOD_FUNC(rb_make_nfs_path), 5);
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

//////////////////////////////////////
// ruby Binding methods
//////////////////////////////////////
//
// public  initialize()
//
VALUE Cache::rb_init(int argc, VALUE* argv, VALUE self)
{
  VALUE size, opt;
  if (rb_scan_args(argc, argv, "11", &size, &opt) == 1) {
    opt = rb_hash_new();
  }

  VALUE klass     = rb_funcall(self, rb_intern("class"), 0);
  VALUE page_size = rb_funcall(klass, rb_intern("const_get"), 1, rb_str_new2("PAGE_SIZE"));
  VALUE page_num  = rb_funcall(size, rb_intern("/"), 1, page_size);

  ssize_t pages = NUM2LL(page_num);
  if (pages <= 0) {
    rb_throw("Page size must be > 0.", rb_eArgError);
  }

  Cache* c = get_self(self);
  Database* pdb = (Database*)ruby_xmalloc(sizeof(Database));
  new( (void*)pdb ) Database(pages);
  c->m_db = pdb;

  operator_locker = rb_intern("locker");
  operator_synchronize = rb_intern("synchronize");
  operator_bracket = rb_intern("[]");
  operator_bracket_let = rb_intern("[]=");
  operator_push = rb_intern("push");
  operator_make_nfs_path = rb_intern("make_nfs_path");
  operator_member_puts = rb_intern("member_puts");
  rb_cSym_status = ID2SYM(rb_intern("status"));
  rb_cSym_available = ID2SYM(rb_intern("available"));
  rb_cSym_empty = ID2SYM(rb_intern(""));

  // locker object.
  rb_require("monitor");
  VALUE monitor_class = rb_const_get(rb_mKernel, rb_intern("Monitor"));
  VALUE monitor = rb_funcall(monitor_class, rb_intern("new"), 0);
  rb_ivar_set(self, operator_locker, monitor);

  // watchdog limit.
  VALUE watchdog_limit = rb_hash_aref(opt, ID2SYM(rb_intern("watchdog_limit")));
  if (!RTEST(watchdog_limit)) watchdog_limit = INT2NUM(15);
  c->set_expire(NUM2UINT(watchdog_limit));

  return self;
}


//
//  public Cache.find()
//
VALUE Cache::rb_find(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(find_internal), rb_ary_new3(4, self, _c, _t, _r));
}

VALUE Cache::find_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _c    = rb_ary_entry(data, 1);
  VALUE _t    = rb_ary_entry(data, 2);
  VALUE _r    = rb_ary_entry(data, 3);

  ArrayOfId a;
  bool removed = false;

  get_self(_self)->find(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), a, removed);
  if(removed) return Qnil;

  VALUE result = rb_class_new_instance(0, &stub, rb_cArray);
  for(unsigned int i=0; i<a.size(); i++) {
    ID peer = a.at(i);
    rb_funcall(result, operator_push, 1, rb_funcall(ID2SYM(peer), rb_intern("to_s"), 0));
  }
  return result;
}


//
//  public Cache.watchdog_limit()
//
VALUE Cache::rb_get_expire(VALUE self)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(get_expire_internal), rb_ary_new3(1, self));
}

VALUE Cache::get_expire_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  return UINT2NUM(get_self(_self)->get_expire());
}


//
//  public Cache.stat()
//
VALUE Cache::rb_stat(VALUE self, VALUE _k)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(stat_internal), rb_ary_new3(2, self, _k));
}


VALUE Cache::stat_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _k    = rb_ary_entry(data, 1);
  return ULL2NUM(get_self(_self)->stat((Database::DatabaseStat)NUM2INT(_k)));
}


//
//  public Cache.peers()
//
VALUE Cache::rb_alloc_peers(VALUE self)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(alloc_peers_internal), rb_ary_new3(1, self));
}

VALUE Cache::alloc_peers_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  Cache* c = get_self(_self);
  Peers* pp = (Peers*)ruby_xmalloc(sizeof(Peers));
  new( (void*)pp ) Peers(*c);
  return Data_Wrap_Struct(rb_cPeers, Peers::gc_mark, Peers::free, pp);
}

//
//  public Cache.dump()
//
VALUE Cache::rb_dump(int argc, VALUE* argv, VALUE self)
{
  VALUE _f, _p;
  int num = rb_scan_args(argc, argv, "11", &_f, &_p);
  VALUE args = rb_ary_new3(2, self, _f);
  if (num == 2) rb_ary_push(args, _p);

  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(dump_internal), args);
}

VALUE Cache::dump_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _f    = rb_ary_entry(data, 1);
  VALUE _p    = rb_ary_entry(data, 2);

  Cache* c = get_self(_self);
  bool result;
  if (RTEST(_p)) {
    FilteredDumper dumper(_self, _f, _p);
    result = (c->m_db->dump(dumper));
  } else {
    Dumper dumper(_self, _f);
    result = (c->m_db->dump(dumper));
  }
  rb_funcall(_f, rb_intern("puts"), 0);
  return result ? Qtrue : Qfalse;
}


//
//  public Cache.find_peers()
//
VALUE Cache::rb_find_peers(int argc, VALUE* argv, VALUE self)    
{
  VALUE require_spaces;
  int num = rb_scan_args(argc, argv, "01", &require_spaces);
  VALUE args = rb_ary_new3(1, self);
  if (num == 1) rb_ary_push(args, require_spaces);

  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(find_peers_internal), args);
}

VALUE Cache::find_peers_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _s    = rb_ary_entry(data, 1);

  VALUE peers = rb_funcall(_self, rb_intern("peers"), 0);
  if (RTEST(_s))
    return rb_funcall(peers, rb_intern("find"), 1, _s);
  else
    return rb_funcall(peers, rb_intern("find"), 0);
}


//
// public Cache.insert_element()
//
VALUE Cache::rb_insert_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(insert_element_internal), rb_ary_new3(5, self, _p, _c, _t, _r));
}

VALUE Cache::insert_element_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _p    = rb_ary_entry(data, 1);
  VALUE _c    = rb_ary_entry(data, 2);
  VALUE _t    = rb_ary_entry(data, 3);
  VALUE _r    = rb_ary_entry(data, 4);

  VALUE peers = rb_funcall(_self, rb_intern("peers"), 0);
  VALUE peer  = rb_funcall(peers, rb_intern("[]"), 1, _p);
  return rb_funcall(peer, rb_intern("insert"), 3, _c, _t, _r);
}


//
//  public Cache.erase_element()
//
VALUE Cache::rb_erase_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(erase_element_internal), rb_ary_new3(5, self, _p, _c, _t, _r));
}

VALUE Cache::erase_element_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _p    = rb_ary_entry(data, 1);
  VALUE _c    = rb_ary_entry(data, 2);
  VALUE _t    = rb_ary_entry(data, 3);
  VALUE _r    = rb_ary_entry(data, 4);

  VALUE peers = rb_funcall(_self, rb_intern("peers"), 0);
  VALUE peer  = rb_funcall(peers, rb_intern("[]"), 1, _p);
  return rb_funcall(peer, rb_intern("erase"), 3, _c, _t, _r);
}


//
//  public Cache.get_peer_status()
//
VALUE Cache::rb_get_peer_status(VALUE self, VALUE _p)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(get_peer_status_internal), rb_ary_new3(2, self, _p));
}


VALUE Cache::get_peer_status_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _p    = rb_ary_entry(data, 1);

  VALUE peers = rb_funcall(_self, rb_intern("peers"), 0);
  VALUE peer  = rb_funcall(peers, rb_intern("[]"), 1, _p);
  return rb_funcall(peer, rb_intern("status"), 0);
}


//
//  public Cache.set_peer_status()
//
VALUE Cache::rb_set_peer_status(VALUE self, VALUE _p, VALUE _s)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(set_peer_status_internal), rb_ary_new3(3, self, _p, _s));
}

VALUE Cache::set_peer_status_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self = rb_ary_entry(data, 0);
  VALUE _p    = rb_ary_entry(data, 1);
  VALUE _s    = rb_ary_entry(data, 2);

  VALUE peers = rb_funcall(_self, rb_intern("peers"), 0);
  VALUE peer  = rb_funcall(peers, rb_intern("[]"), 1, _p);
  return rb_funcall(peer, rb_intern("status="), 1, _s);
}


//
// public Cache.get_peers_info()
//
VALUE Cache::rb_get_peers_info(VALUE self)
{
  return rb_iterate(synchronize, self, RUBY_METHOD_FUNC(get_peers_info_internal), rb_ary_new3(1, self));
}

VALUE Cache::get_peers_info_internal(VALUE block_arg, VALUE data, VALUE self)
{
  VALUE _self  = rb_ary_entry(data, 0);
  PeerStatusMap map = get_self(_self)->m_db->get_peer_status_map();

  VALUE result = rb_class_new_instance(0, &stub, rb_cArray);
  for(PeerStatusMap::iterator it = map.begin(); it != map.end(); it++) 
  {
    PeerStatus s = (*it).second;
    if (s.is_valid() == true)
    {
      rb_funcall(result, operator_push, 1, rb_funcall(ID2SYM((*it).first), rb_intern("to_s"), 0));
      rb_funcall(result, operator_push, 1, INT2NUM(s.status));
      rb_funcall(result, operator_push, 1, ULL2NUM(s.available));
    }
  }

  return result;
}


//
// private Cache.make_nfs_path()
//
VALUE Cache::rb_make_nfs_path(VALUE self, VALUE _p, VALUE _b, VALUE _c, VALUE _t, VALUE _r)
{
  return rb_funcall(rb_cCache, operator_make_nfs_path, 5, _p, _b, _c, _t, _r);
}


//
// This method is Cache's utility. 
//
VALUE Cache::synchronize(VALUE self)
{
  VALUE monitor = rb_ivar_get(self, operator_locker);
  return rb_funcall(monitor, operator_synchronize, 0);
}


///////////////////////////////////////////////////////////////
//
// implement of peers
//
//////////////////////////////////////////////////////////////

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


//
// Peers.find()
//
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


//
// public Peers =[]
//
VALUE Peers::rb_alloc_peer(VALUE self, VALUE _p)
{
  Peers* p = get_self(self);
  Peer* pp = (Peer*)ruby_xmalloc(sizeof(Peer));
  new( (void*)pp ) Peer(*(p->m_cache), rb_to_id(_p));
  return Data_Wrap_Struct(rb_cPeer, Peer::gc_mark, Peer::free, pp);
}




///////////////////////////////////////////////////////////////
//
// implement of peer
//
//////////////////////////////////////////////////////////////
//
// Castoro::Gateway::Peer
//
VALUE Peer::define_class(VALUE _p)
{
  VALUE c = rb_define_class_under(_p, "Peer", rb_cObject);

  rb_define_method(c, "insert",  RUBY_METHOD_FUNC(rb_insert), 3);
  rb_define_method(c, "erase",  RUBY_METHOD_FUNC(rb_remove), 3);
  rb_define_method(c, "status=", RUBY_METHOD_FUNC(rb_set_status), 1);
  rb_define_method(c, "status",  RUBY_METHOD_FUNC(rb_get_status), 0);
  rb_define_method(c, "unlink",   RUBY_METHOD_FUNC(rb_unlink), 0);

  rb_define_const(c, "MAINTENANCE",  INT2NUM(DS_MAINTENANCE));
  rb_define_const(c, "ACTIVE",       INT2NUM(DS_ACTIVE));
  rb_define_const(c, "READONLY",     INT2NUM(DS_READONLY));

  return c;
}


//
// public Peer.insert
//
VALUE Peer::rb_insert(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  Peer* p = get_self(self);
  p->m_cache->insert(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), p->m_peer);
  return Qnil;
}


//
// public Peer.erase
//
VALUE Peer::rb_remove(VALUE self, VALUE _c, VALUE _t, VALUE _r)
{
  Peer* p = get_self(self);
  p->m_cache->remove(NUM2ULL(_c), NUM2INT(_t), NUM2INT(_r), p->m_peer);
  return Qnil;
}


//
// public Peer.insert
//
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


//
// public Peer.status();
//
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


//
// public Peer.unlink()
//
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
