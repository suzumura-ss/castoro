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

#ifndef __INCLUDE_GATEWAY_CACHE_HXX__
#define __INCLUDE_GATEWAY_CACHE_HXX__

#include "ruby.h"
#include "database.hxx"

// C++/Ruby Wrapper template.
template<class T> class RubyWrapper
{
public:
  static void gc_mark(void* self) {};
  static VALUE rb_alloc(VALUE self) { return Data_Wrap_Struct(self, T::gc_mark, T::free, new T); };
  static void free(void* obj) { delete (T*)obj; };
  static T* get_self(VALUE self) {
    T* t;
    Data_Get_Struct(self, T, t);
    return t;
  };
};


 
//
// Castoro::Gateway::Database wrapper
//
namespace Castoro {
namespace Gateway {


// Ruby Castoro::Gateway::Cache
class Cache :public RubyWrapper<Cache>
{
public:
  inline Cache() { m_db = NULL; };
  inline virtual ~Cache() { try{ if(m_db) delete m_db; } catch(...){} };

  // content handlings.
  inline void insert(uint64_t c, uint32_t t, uint32_t r, ID p) { m_db->insert(c, t, r, p); };
  inline void find(uint64_t c, uint32_t t, uint32_t r, ArrayOfPeerWithBase& a, bool& k) {
    m_db->find(c, t, r, a, k);
  };
  inline void remove(uint64_t c, uint32_t t, uint32_t r, ID p) { m_db->remove(c, t, r, p); };

  // peer handlings.
  inline void set_status(ID p, const PeerStatus& s) { m_db->set_status(p, s); };
  inline bool get_status(ID p, PeerStatus& s) { return m_db->get_status(p, s); };
  inline void find(ArrayOfId& a) { m_db->find(a); };
  inline void find(uint64_t r, ArrayOfId& a) { m_db->find(r, a); };
  inline void remove(ID p) { m_db->remove(p); };

  // global stats.
  inline void set_expire(uint32_t e) { m_db->set_expire(e); };
  inline uint32_t get_expire() const { return m_db->get_expire(); };
  inline uint64_t stat(Database::DatabaseStat s) { return m_db->stat(s); };

  // Ruby bindings.
  static VALUE define_class(VALUE _p);

private:
  Database* m_db;

  // Ruby bindings.
  static VALUE rb_init(int argc, VALUE* argv, VALUE self);
  static VALUE rb_find(VALUE self, VALUE _c, VALUE _t, VALUE _r);
  static VALUE rb_get_expire(VALUE self);
  static VALUE rb_stat(VALUE self, VALUE _k);
  static VALUE rb_alloc_peers(VALUE self);
  static VALUE rb_dump(VALUE self, VALUE _f);
  static VALUE rb_find_peers(int argc, VALUE* argv, VALUE self);
  static VALUE rb_insert_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r);
  static VALUE rb_erase_element(VALUE self, VALUE _p, VALUE _c, VALUE _t, VALUE _r);
  static VALUE rb_get_peer_status(VALUE self, VALUE _p);
  static VALUE rb_set_peer_status(VALUE self, VALUE _p, VALUE _s);
  static VALUE rb_make_nfs_path(VALUE self, VALUE _p, VALUE _b, VALUE _c, VALUE _t, VALUE _r);

  static VALUE synchronize(VALUE self);
  static VALUE find_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE get_expire_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE stat_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE alloc_peers_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE dump_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE find_peers_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE insert_element_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE erase_element_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE get_peer_status_internal(VALUE block_arg, VALUE data, VALUE self);
  static VALUE set_peer_status_internal(VALUE block_arg, VALUE data, VALUE self);
};



// Ruby Castoro::Gateway::Peers
class Peers :public RubyWrapper<Peers>
{
public:
  inline Peers() { m_cache = NULL; };
  inline Peers(Cache& c) { m_cache = &c; };
  inline virtual ~Peers() {};

private:
  Cache* m_cache;

public:
  // Ruby bindings
  static VALUE define_class(VALUE _p);
  static VALUE rb_find(int argc, VALUE* argv, VALUE self);
  static VALUE rb_alloc_peer(VALUE self, VALUE _p);
};



// Ruby Castoro::Gateway::Peer
class Peer :public RubyWrapper<Peer>
{
public:
  inline Peer() { m_cache = NULL; m_peer = 0; };
  inline Peer(Cache& cache, ID peer) { m_cache = &cache; m_peer = peer; };
  virtual ~Peer() {};

private:
  Cache* m_cache;
  ID  m_peer;

public:
  // Ruby bindings
  static VALUE define_class(VALUE _p);
  static VALUE rb_insert(VALUE self, VALUE _c, VALUE _t, VALUE _r);
  static VALUE rb_remove(VALUE self, VALUE _c, VALUE _t, VALUE _r);
  static VALUE rb_set_status(VALUE self, VALUE _s);
  static VALUE rb_get_status(VALUE self);
  static VALUE rb_unlink(VALUE self);
};


}
}

#endif //__INCLUDE_GATEWAY_CACHE_HXX__
