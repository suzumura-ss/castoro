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

#include "page.hxx"


namespace Castoro {
namespace Gateway {

//
// class ID3
//
void ID3::append(PEERH id)
{
  if((at(0)==0) || (at(0)==id)) {
    at(0, id);
    return;
  }
  if((at(1)==0) || (at(1)==id)) {
    at(1, id);
    return;
  }
  if((at(2)==0) || (at(2)==id)) {
    at(2, id);
    return;
  }
  at(0, id);
}

void ID3::remove(PEERH id)
{
  if(at(0)==id) {       at(0, at(1)); goto at_1; }
  if(at(1)==id) { at_1: at(1, at(2)); goto at_2; }
  if(at(2)==id) { at_2: at(2, 0);
    if(empty()) set_removed();
  }
}

bool ID3::empty() const
{
  return ((at(0)==0) && (at(1)==0) && (at(2)==0));
}

void ID3::pushall(ArrayOfId& dest) const
{
  for(int idx=0; idx<3 && at(idx)!=0; idx++) {
    dest.push_back(at(idx));
  }
}


//
// class CachePage
//
void CachePage::init(uint64_t content_id, uint32_t type)
{
  memset(m_revision_hash, 0, sizeof(m_revision_hash));
  memset(m_peers, 0, sizeof(m_peers));
  m_contains = 0;
  m_magic.content_id = content_id & (~(CACHEPAGE_SIZE-1));
  m_magic.type = type;
}


// insert revision into page.
bool CachePage::insert(uint64_t content_id, uint32_t type, uint32_t revision, PEERH peer)
{
  if(!validate(content_id, type)) return false; // invalid page.

  content_id &= (CACHEPAGE_SIZE-1);
  uint8_t rev = (uint8_t)revision;

  // check revision.
  if((m_revision_hash[content_id]!=rev) && !m_peers[content_id].empty()) {
    m_contains--;
    m_peers[content_id].clear();
  }

  // mark.
  if(m_peers[content_id].empty()) m_contains++;
  m_peers[content_id].append(peer);
  m_revision_hash[content_id] = rev;

  return true;
}


// find revision from page.
bool CachePage::find(uint64_t content_id, uint32_t type, uint32_t revision, ArrayOfId& result, bool& removed)
{
  removed = false;
  if(!validate(content_id, type)) return false; // invalid page.

  content_id &= (CACHEPAGE_SIZE-1);
  uint8_t rev = (uint8_t)revision;

  // check 'removed'.
  if(m_peers[content_id].removed()) {
    removed = true;
    return true;
  }

  // check revision.
  if(m_revision_hash[content_id]!=rev) return true;

  // build result.
  m_peers[content_id].pushall(result);
  return true;
}


// remove revision from page.
bool CachePage::remove(uint64_t content_id, uint32_t type, uint32_t revision, PEERH peer)
{
  if(!validate(content_id, type)) return false; // invalid page.

  content_id &= (CACHEPAGE_SIZE-1);
  uint8_t rev = (uint8_t)revision;

  // check revision.
  if(m_revision_hash[content_id]!=rev) return true;

  // remove.
  m_peers[content_id].remove(peer);
  if(m_peers[content_id].empty()) {
    m_contains--;
    if(m_contains==0) return false; // empty page.
  }
  return true;  // succeeded;
}



//
// class CachePagePool
//
CachePagePool::CachePagePool(size_t pages)
{
  m_pages = pages;
  m_array = new CachePage[pages];

  // init free list
  m_free_pages.reserve(pages);
  for(size_t idx=0; idx<pages; idx++) {
    m_free_pages.push_back(&m_array[idx]);
  }
}

CachePagePool::~CachePagePool()
{
  try {
    delete[] m_array;
  }
  catch(...) {}
}


// alloc page.
CachePage* CachePagePool::alloc()
{
  if(m_free_pages.empty()) {
    // drop page, forcely.
    m_free_pages.push_back(m_alloc_pages.back());
    m_alloc_pages.pop_back();
  }

  // get page from free-list.
  CachePage* result = m_free_pages.back();
  m_free_pages.pop_back();
  m_alloc_pages.push_front(result);

  return result;
}


// drop page.
void CachePagePool::drop(CachePage*& page)
{
  m_alloc_pages.remove(page);
  m_free_pages.push_back(page);
}


}
}
