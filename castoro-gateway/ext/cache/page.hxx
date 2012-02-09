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

#ifndef __INCLUDE_GATEWAY_PAGE_H__
#define __INCLUDE_GATEWAY_PAGE_H__

#include "basetypes.hxx"
#include "mapping.hxx"


namespace Castoro {
namespace Gateway {

  // { peer code }[3] array.
  class ID3 {
  public:
    inline ID3() { clear(); };
    inline ~ID3() {}; // NOT virtual.
    void append(PEERH id);
    void remove(PEERH id);
    inline void clear() { memset(array, 0, sizeof(array)); };
    bool empty() const;
    inline bool removed() { return !!(array[0] & 0x8000); }
    void pushall(ArrayOfId& dest) const;
    inline PEERH at(int idx) const { return array[idx] & 0x7FFF; };
    inline void at(int idx, PEERH value) {
      array[idx] = (value & 0x7FFF);
      array[0] &= 0x7FFF;
    };

  private:
    PEERH array[3];
    inline void set_removed() { array[0] |= 0x8000; };
  };


  // { content_id, type, revision } <=> { peer code } cache page.
  class CachePage {
  public:
    inline CachePage() {};
    inline virtual ~CachePage() {};

    void init(uint64_t content_id, uint32_t type);
    bool insert(uint64_t content_id, uint32_t type, uint32_t revision, PEERH peer);
    bool find(uint64_t content_id, uint32_t type, uint32_t revision, ArrayOfId& result, bool& removed);
    bool remove(uint64_t content_id, uint32_t type, uint32_t revision, PEERH peer);

    attr_reader(ContentIdWithType, m_magic);
    attr_reader(uint16_t, m_contains);
    attr_reader(uint8_t*, m_revision_hash);
    attr_reader(ID3*, m_peers);

  private:
    ContentIdWithType m_magic;
    uint16_t  m_contains;
    uint8_t   m_revision_hash[CACHEPAGE_SIZE];
    ID3       m_peers[CACHEPAGE_SIZE];
    inline bool validate(uint64_t content_id, uint32_t type) const {
      uint64_t ch = content_id & (~(CACHEPAGE_SIZE-1));
      return ((ch==m_magic.content_id) && (type==m_magic.type));
    };
  };
  typedef std::map<ContentIdWithType, CachePage*> CachePageMap;


  // cache page pool.
  class CachePagePool {
  public:
    CachePagePool(size_t pages);
    virtual ~CachePagePool();

    CachePage* alloc();
    void drop(CachePage*& page);

    attr_reader(size_t, m_pages);
    attr_reader(CachePage*, m_array);
    attr_reader_ref(std::list<CachePage*>, m_alloc_pages);
    attr_reader_ref(std::vector<CachePage*>, m_free_pages);

  private:
    size_t      m_pages;
    CachePage*  m_array;
    std::list<CachePage*> m_alloc_pages;
    std::vector<CachePage*> m_free_pages;
  };


}
}


#endif //__INCLUDE_GATEWAY_PAGE_H__
