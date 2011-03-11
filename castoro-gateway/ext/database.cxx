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

#include "database.hxx"


namespace Castoro {
namespace Gateway {


//
// class Database
//
Database::Database(size_t pages)
{
  m_expire = 15;
  m_requests = 0;
  m_hits = 0;
  m_pool = new CachePagePool(pages);
}

Database::~Database()
{
  try {
    delete m_pool;
  }
  catch(...) {}
}


// insert
void Database::insert(uint64_t content_id, uint32_t type, uint32_t revision, ID peer, ID base)
{
  ContentIdWithType ct(content_id, type);

  CachePageMap::iterator it = m_table.find(ct);
  if(it==m_table.end()) {
    // alloc and insert new page.
    CachePage* p = m_pool->alloc();
    p->init(content_id, type);
    std::pair<CachePageMap::iterator, bool> r = m_table.insert(std::make_pair(ct, p));
    if(!r.second) {
      // insert failed.
      m_pool->drop(p);
      return;
    }
    it = r.first;
  }

  // insert {content_id, type, revision, peer}.
  CachePage* p = (*it).second;
  if(!(p->insert(content_id, type, revision, fromID(peer)))) {
    // drop page because of page is full.
    m_pool->drop(p);
    m_table.erase(it);
    return;
  }

  // update peer/type/base pair.
  m_paths.insert(peer, type, base);

  // update peer status.
  update_peer(peer);
}


void Database::find(uint64_t content_id, uint32_t type, uint32_t revision, ArrayOfPeerWithBase& result, bool& removed)
{
  m_requests++;

  ContentIdWithType ct(content_id, type);
  
  CachePageMap::iterator it = m_table.find(ct);
  if(it==m_table.end()) return; // nothing to do.

  CachePage* p = (*it).second;
  ArrayOfId peers;
  if(!(p->find(content_id, type, revision, peers, removed))) {
    // drop page because of page is brocken.
    m_pool->drop(p);
    m_table.erase(it);
    return;
  }
  for(unsigned int idx=0; idx<peers.size(); idx++) {
    ID peer = toID(peers.at(idx));
    PeerStatusMap::iterator pi = m_status.find(peer);
    if((pi!=m_status.end()) && (*pi).second.is_readable()) {
      ID base = m_paths.find(peer, type);
      if(base) {
        PeerWithBase pb = { peer, base };
        result.push_back(pb);
      }
    }
  }
  if(result.size()>0) m_hits++;
}


void Database::remove(uint64_t content_id, uint32_t type, uint32_t revision, ID peer)
{
  ContentIdWithType ct(content_id, type);

  CachePageMap::iterator it = m_table.find(ct);
  if(it==m_table.end()) return; // nothing to do.

  CachePage* p = (*it).second;
  if(!(p->remove(content_id, type, revision, fromID(peer)))) {
    // drop page because of page is empty.
    m_pool->drop(p);
    m_table.erase(it);
  }

  // update peer status.
  update_peer(peer);
}


void Database::set_status(ID peer, const PeerStatus& status)
{
  struct timeval tv = { 0, 0 };
  gettimeofday(&tv, NULL);

  PeerStatus s = status;
  s.expire = m_expire + tv.tv_sec;

  PeerStatusMap::iterator it = m_status.find(peer);
  if(it==m_status.end()) {
    m_status.insert(std::make_pair(peer, s));
  } else {
    (*it).second = s;
  }
}


bool Database::get_status(ID peer, PeerStatus& status)
{
  PeerStatusMap::iterator it = m_status.find(peer);
  if(m_status.end()==it) return false;

  status = (*it).second;
  return true;
}


void Database::find(ArrayOfId& result)
{
  for(PeerStatusMap::iterator it = m_status.begin(); it != m_status.end(); it++) {
    result.push_back((*it).first);
  }
}


void Database::find(uint64_t require_space, ArrayOfId& result)
{
  PeerStatusMap::iterator it = m_status.begin();
  for(; it!=m_status.end(); it++) {
    PeerStatus s = (*it).second;
    if(s.is_enough_spaces(require_space)) result.push_back((*it).first);
  }
}


void Database::remove(ID peer)
{
  m_status.erase(peer);
}


void Database::update_peer(ID peer)
{
  PeerStatusMap::iterator it = m_status.find(peer);
  if(m_status.end()==it) return;

  struct timeval tv = { 0, 0 };
  gettimeofday(&tv, NULL);
  (*it).second.expire = tv.tv_sec + m_expire;
}


uint64_t Database::stat(DatabaseStat key)
{
  uint64_t result = 0;

  switch(key) {
  // Global
  case DSTAT_CACHE_EXPIRE:
    return m_expire;

  case DSTAT_CACHE_REQUESTS:
    return m_requests;

  case DSTAT_CACHE_HITS:
    return m_hits;

  case DSTAT_CACHE_COUNT_CLEAR:
    result = (m_requests>0) ? ((m_hits * 1000)/m_requests): 0;
    m_requests = m_hits = 0;
    return result;

  // CachePagePool
  case DSTAT_ALLOCATE_PAGES:
    return m_pool->m_pages_r();

  case DSTAT_FREE_PAGES:
    return m_pool->m_free_pages_r()->size();

  case DSTAT_ACTIVE_PAGES:
    return m_pool->m_alloc_pages_r()->size();

  // Peers
  case DSTAT_HAVE_STATUS_PEERS:
    return m_status.size();

  case DSTAT_ACTIVE_PEERS:
    for(PeerStatusMap::iterator it=m_status.begin(); it!=m_status.end(); it++) {
      if((*it).second.is_writable()) result++;
    }
    return result;

  case DSTAT_READABLE_PEERS:
    for(PeerStatusMap::iterator it=m_status.begin(); it!=m_status.end(); it++) {
      if((*it).second.is_readable()) result++;
    }
    return result;

  default:
    break;
  }

  return 0;
}


bool Database::dump(CacheDumperAbstract& dumper)
{
  std::list<CachePage*>* acvive_pages = m_pool->m_alloc_pages_r();
  std::list<CachePage*>::iterator it = acvive_pages->begin();

  for(; it!=acvive_pages->end(); it++) {
    CachePage* cp = *it;
    uint8_t*  revisions = cp->m_revision_hash_r();
    ID3*      peers = cp->m_peers_r();
    ContentIdWithType magic = cp->m_magic_r();
    for(size_t ofs = 0; ofs<CACHEPAGE_SIZE; ofs++) {
      ArrayOfId ids;  peers[ofs].pushall(ids);
      uint64_t  cid = magic.content_id;
      uint32_t  typ = magic.type;
      uint32_t  rev = revisions[ofs];
      for(size_t pi=0; pi<ids.size(); pi++) {
        ID peer = toID(ids.at(pi));
        ID base = m_paths.find(peer, typ);
        if(!dumper(cid+ofs, typ, rev, peer, base)) return false;
      }
    }
  }
  return true;
}


}
}
