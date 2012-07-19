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

#ifndef __INCLUDE_GATEWAY_DATABASE_H__
#define __INCLUDE_GATEWAY_DATABASE_H__

#include "basetypes.hxx"
#include "mapping.hxx"
#include "page.hxx"
#include "basket.hxx"

namespace Castoro {
namespace Gateway {


  class PeerStatus {
  public:
    inline PeerStatus(uint64_t a=0, time_t t=0, DetailStatus s=DS_UNKNOWN) {
      available = a;
      expire = t;
      status = s;
    };
    inline ~PeerStatus() {}; // NOT virtual.
    inline bool is_valid() const {
      struct timeval tv = { 0, 0 };
      gettimeofday(&tv, NULL);
      return (expire >= tv.tv_sec);
    };
    inline bool is_readable() const { return is_valid() && ((status/10)>=2); };
    inline bool is_writable() const { return is_valid() && ((status/10)>=3); };
    inline bool is_enough_spaces(uint64_t require) const {
      return is_writable() && (available>=require);
    };

  public:
    uint64_t  available;      // Disk availables by byte.
    time_t    expire;         // Expire time of this record.
    DetailStatus  status;     // Peer status;
  };
  typedef std::map<ID, PeerStatus> PeerStatusMap;


  class CacheDumperAbstract {
  public:
    inline CacheDumperAbstract() {};
    virtual inline ~CacheDumperAbstract() {};
    virtual bool operator()(const BasketId& bid, uint32_t typ, uint32_t rev, ID peer, ID base) = 0;
  };


  class Database {
  public:
    Database(size_t pages);
    virtual ~Database();

    // content handlings.
    void insert(const BasketId& id, uint32_t type, uint32_t revision, ID peer, ID base);
    void find(const BasketId& id, uint32_t type, uint32_t revision, ArrayOfPeerWithBase& result, bool& removed);
    void remove(const BasketId& id, uint32_t type, uint32_t revision, ID peer);

    // peer handlings.
    void set_status(ID peer, const PeerStatus& status);
    bool get_status(ID peer, PeerStatus& status);
    void find(ArrayOfId& result);
    void find(uint64_t require_space, ArrayOfId& result);
    void remove(ID peer);

    // global settings.
    inline void set_expire(uint32_t expires) { m_expire = expires; };
    inline uint32_t get_expire() const { return m_expire; };

    // dump cache.
    bool dump(CacheDumperAbstract& dumper);

    // statistics
    typedef enum {
      DSTAT_CACHE_EXPIRE = 1,
      DSTAT_CACHE_REQUESTS,
      DSTAT_CACHE_HITS,
      DSTAT_CACHE_COUNT_CLEAR,

      // CachePagePool
      DSTAT_ALLOCATE_PAGES = 10,
      DSTAT_FREE_PAGES,
      DSTAT_ACTIVE_PAGES,

      // Peers
      DSTAT_HAVE_STATUS_PEERS = 20,
      DSTAT_ACTIVE_PEERS,
      DSTAT_READABLE_PEERS
    } DatabaseStat;
    uint64_t stat(DatabaseStat s);

    attr_reader(uint32_t, m_expire);
    attr_reader(CachePagePool*, m_pool);
    attr_reader_ref(CachePageMap, m_table);
    attr_reader_ref(PeerStatusMap, m_status);
    attr_reader_ref(PeerHash, m_peerh);
    attr_reader_ref(BasePathMap, m_paths);

  private:
    uint32_t        m_expire;   // Cache expires by sec.
    CachePagePool*  m_pool;     // Page pool.
    CachePageMap    m_table;    // Active cache pages.
    PeerStatusMap   m_status;   // peer ID => PeerStatus
    PeerHash        m_peerh;    // peer ID => PeerH
    BasePathMap     m_paths;    // {peer ID,type} => base path ID
    uint64_t        m_requests; // #find request count.
    uint64_t        m_hits;     // #find request hit count.

    inline PEERH fromID(ID id) { return m_peerh.fromID(id); };
    inline ID toID(PEERH h) const { return m_peerh.toID(h); };
    void update_peer(ID peer);
  };
    
}
}


#endif //__INCLUDE_GATEWAY_DATABASE_H__
