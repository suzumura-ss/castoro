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

#include <stdio.h>
#include <assert.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>

#include "../database.hxx"
#include "../mapping.hxx"
#include "../page.hxx"
#include "../database.hxx"

using namespace Castoro;
using namespace Gateway;

int g_testcount = 0;
char g_description[4096] = "";

void DESCRIPTION(const char* fmt, ...)
{
  va_list va;
  va_start(va, fmt);
  vsnprintf(g_description, sizeof(g_description), fmt, va);
  va_end(va);
}

#define X_ASSERT(expr)
#define ASSERT(expr)  assert_with(__LINE__, #expr, (int64_t)(expr))
void assert_with(int line, const char* text, int64_t expr)
{
  if(expr) {
    printf(".");
    fflush(stdout);
  } else {
    printf("\n[Line:%d] Test %s\n\t'%s' failed. expect !0, but %lld\n",
            line, g_description, text, expr);
    exit(1);
  }
  g_testcount++;
}


#define X_ASSERT_EQ(expr, expect)
#define ASSERT_EQ(expr, expect)  assert_with(__LINE__, #expr, (int64_t)(expr), (int64_t)(expect))
void assert_with(int line, const char* text, int64_t expr, int64_t expect)
{
  if(expr==expect) {
    printf(".");
    fflush(stdout);
  } else {
    printf("\n[Line:%d] Test %s\n\t'%s' failed. expect %lld(0x%llx), but %lld(0x%llx)\n",
            line, g_description, text, expect, expect, expr, expr);
    exit(1);
  }
  g_testcount++;
}


void test_PeerHash()
{
  Castoro::Gateway::PeerHash ph;

  DESCRIPTION("PeerHash initialize");
  ASSERT_EQ(ph.toID(0), (ID)-1);
  ASSERT_EQ(ph.toID(1), (ID)-1);

  DESCRIPTION("PeerHash from_ID/to_ID");
  for(uint32_t it=1; it<=10; it++) {
    ASSERT_EQ(ph.fromID(it*0x100000), it);
  }
  for(uint32_t it=1; it<=10; it++) {
    ASSERT_EQ(ph.fromID(it*0x100000), it);
  }
  for(uint32_t it=1; it<=10; it++) {
    ASSERT_EQ(ph.toID(it), it*0x100000);
  }
}


void test_ID3()
{
  Castoro::Gateway::ID3 id3;

  DESCRIPTION("ID3 initialize");
  ASSERT(id3.empty());


  DESCRIPTION("ID3 insert");
  id3.append(1);
  ASSERT_EQ(id3.at(0), 1);
  id3.append(1);
  ASSERT_EQ(id3.at(0), 1);
  ASSERT_EQ(id3.at(1), 0);
  ASSERT_EQ(id3.at(2), 0);

  id3.append(2);
  ASSERT_EQ(id3.at(0), 1);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 0);
  id3.append(2);
  ASSERT_EQ(id3.at(0), 1);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 0);

  id3.append(3);
  ASSERT_EQ(id3.at(0), 1);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 3);
  id3.append(3);
  ASSERT_EQ(id3.at(0), 1);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 3);

  id3.append(4);
  ASSERT_EQ(id3.at(0), 4);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 3);


  DESCRIPTION("CachePagePool remove");
  id3.remove(1);
  ASSERT_EQ(id3.at(0), 4);
  ASSERT_EQ(id3.at(1), 2);
  ASSERT_EQ(id3.at(2), 3);
  ASSERT_EQ(id3.removed(), false);

  id3.remove(2);
  ASSERT_EQ(id3.at(0), 4);
  ASSERT_EQ(id3.at(1), 3);
  ASSERT_EQ(id3.at(2), 0);
  ASSERT_EQ(id3.removed(), false);

  id3.remove(4);
  ASSERT_EQ(id3.at(0), 3);
  ASSERT_EQ(id3.at(1), 0);
  ASSERT_EQ(id3.at(2), 0);
  ASSERT_EQ(id3.removed(), false);

  id3.remove(3);
  ASSERT_EQ(id3.at(0), 0);
  ASSERT_EQ(id3.at(1), 0);
  ASSERT_EQ(id3.at(2), 0);
  ASSERT(id3.empty());
  ASSERT_EQ(id3.removed(), true);


  DESCRIPTION("ID3 pushall");
  Castoro::Gateway::ArrayOfId ids;
  id3.append(1);
  id3.append(2);
  id3.append(3);
  id3.pushall(ids);
  ASSERT_EQ(ids.size(), 3);
  ASSERT_EQ(ids[0], 1);
  ASSERT_EQ(ids[1], 2);
  ASSERT_EQ(ids[2], 3);
}


void test_CachePagePool()
{
  Castoro::Gateway::CachePagePool pool(4);
  Castoro::Gateway::CachePage* page, *p[4];

  DESCRIPTION("CachePagePool initialize");
  ASSERT_EQ( pool.m_pages_r(), 4 );
  ASSERT( pool.m_alloc_pages_r()->empty() );
  ASSERT_EQ( pool.m_free_pages_r()->size(), 4 );


  DESCRIPTION("CachePagePool allocate");
  ASSERT( page = pool.alloc() );
  ASSERT_EQ( pool.m_free_pages_r()->size(), 3 );
  ASSERT_EQ( pool.m_alloc_pages_r()->size(), 1 );


  DESCRIPTION("CachePagePool drop");
  pool.drop(page);
  ASSERT_EQ( pool.m_free_pages_r()->size(), 4 );
  ASSERT_EQ( pool.m_alloc_pages_r()->size(), 0 );


  DESCRIPTION("CachePagePool allocate many pages");
  ASSERT( p[0] = pool.alloc() );
  p[0]->init(BasketId(0x100010aaull), 0);
  ASSERT_EQ( p[0]->m_magic_r().basket_id.lower(), 0x10001000ull );
  ASSERT_EQ( p[0]->m_magic_r().type, 0 );

  ASSERT( p[1] = pool.alloc() );
  p[1]->init(BasketId(0x100020aaull), 1);
  ASSERT_EQ( p[1]->m_magic_r().basket_id.lower(), 0x10002000ull );
  ASSERT_EQ( p[1]->m_magic_r().type, 1 );

  ASSERT( p[2] = pool.alloc() );
  p[2]->init(BasketId(0x100030aaull), 2);
  ASSERT_EQ( p[2]->m_magic_r().basket_id.lower(), 0x10003000ull );
  ASSERT_EQ( p[2]->m_magic_r().type, 2 );

  ASSERT( p[3] = pool.alloc() );
  p[3]->init(BasketId(0x100040aaull), 3);
  ASSERT_EQ( p[3]->m_magic_r().basket_id.lower(), 0x10004000ull );
  ASSERT_EQ( p[3]->m_magic_r().type, 3 );

  ASSERT( page = pool.alloc() );
  ASSERT_EQ( page->m_magic_r().basket_id.lower(), 0x10001000ull );
  ASSERT_EQ( page->m_magic_r().type, 0 );

  ASSERT( page = pool.alloc() );
  ASSERT_EQ( page->m_magic_r().basket_id.lower(), 0x10002000ull );
  ASSERT_EQ( page->m_magic_r().type, 1 );

  ASSERT( page = pool.alloc() );
  ASSERT_EQ( page->m_magic_r().basket_id.lower(), 0x10003000ull );
  ASSERT_EQ( page->m_magic_r().type, 2 );

  ASSERT( page = pool.alloc() );
  ASSERT_EQ( page->m_magic_r().basket_id.lower(), 0x10004000ull );
  ASSERT_EQ( page->m_magic_r().type, 3 );
}


void test_CachePage()
{
  Castoro::Gateway::CachePage page;
  bool removed = false;

  DESCRIPTION("CachePage init");
  page.init(BasketId(0ull), 0);
  ASSERT_EQ( page.m_magic_r().basket_id.lower(), 0ull );
  ASSERT_EQ( page.m_magic_r().type, 0 );

  DESCRIPTION("CachePage#insert");
  ASSERT( !page.insert(BasketId(0x00000ull), 1, 0, 1) );
  ASSERT( !page.insert(BasketId(0x10000ull), 0, 0, 1) );
  for (BasketId i = BasketId(0ull); i.lower() < 4095; i = i + 1ull) {
    DESCRIPTION("CachePage#insert(id=%d)", i.lower());
    ASSERT( page.insert(i, 0, 0, 1) );
    ASSERT( page.insert(i, 0, 0, 2) );
    ASSERT( page.insert(i, 0, 0, 3) );
  }

  
  DESCRIPTION("CachePage#find");
  Castoro::Gateway::ArrayOfId ids;

  page.init(BasketId(0ull), 0);
  for (BasketId i = BasketId(0ull); i.lower() < 4095; i = i + 1ull) {
    page.insert(i, 0, i.lower(), 1);
  }
  ASSERT(!page.find(BasketId(0ull), 1, 1, ids, removed) );

  page.init(BasketId(0ull), 0);
  for(int p=1; p<=3; p++) {
    for (BasketId i = BasketId(0ull); i.lower() < 4096; i = i + 1ull) {
      DESCRIPTION("CachePage#find(id=%d, peer<<%d)", i.lower(), p);
      page.insert(i, 0, i.lower(), p);
      ids.clear();
      ASSERT( page.find(i, 0, i.lower(), ids, removed) );
      ASSERT_EQ( ids.size(), p );
      for(unsigned int q=1; q<ids.size(); q++) {
        ASSERT_EQ( ids[q-1], q);
      }
    }
  }


  DESCRIPTION("CachePage#remove");
  for (BasketId i = BasketId(0ull); i.lower() < 4096; i = i + 1ull) {
    ASSERT_EQ( page.m_contains_r(), 4096-i.lower() );
    for(unsigned int p=1; p<=3; p++) {
      DESCRIPTION("CachePage#remove(%d, %d)", i.lower(), p);
      ids.clear();
      ASSERT( page.find(i, 0, i.lower(), ids, removed) );
      ASSERT_EQ( ids.size(), 3-p+1 );

      if((i.lower()==4095) && (p==3)) {
        ASSERT( !page.remove(i, 0, i.lower(), p) );
      } else {
        ASSERT( page.remove(i, 0, i.lower(), p) );
      }
      ids.clear();
      ASSERT( page.find(i, 0, i.lower(), ids, removed) );
      ASSERT_EQ( ids.size(), 3-p );

      for(unsigned int s=1; s<=p; s++) {
        DESCRIPTION("CachePage#remove(%d)=>%d not found", p, s);
        for(unsigned int q=0; q<ids.size(); q++) {
          ASSERT( ids[q]!=s );
        }
      }
      for(unsigned int s=p+1; s<=3; s++) {
        DESCRIPTION("CachePage#remove(%d)=>%d included?", p, s);
        for(unsigned int q=0; q<ids.size(); q++) {
          if(ids[q]==s) break;
          if(!(q<ids.size())) ASSERT( false );
        }
      }
    }
    ids.clear();
    ASSERT( page.find(i, 0, i.lower(), ids, removed) );
    ASSERT( ids.empty() );
    ASSERT_EQ( removed, true );
  }
}


void test_PeerStatus()
{
  struct timeval tv = { 0, 0 };
  gettimeofday(&tv, NULL);
  tv.tv_sec += 1;

  Castoro::Gateway::PeerStatus  status(1000, tv.tv_sec, Castoro::Gateway::DS_ACTIVE);

  DESCRIPTION("Status init");
  ASSERT_EQ(status.available, 1000);
  ASSERT_EQ(status.expire, tv.tv_sec);
  ASSERT_EQ(status.status, Castoro::Gateway::DS_ACTIVE);

  DESCRIPTION("Status checks");
  ASSERT(status.is_valid());
  ASSERT(status.is_readable());
  ASSERT(status.is_writable());
  ASSERT(status.is_enough_spaces(500));
  ASSERT(status.is_enough_spaces(1000));
  ASSERT(!status.is_enough_spaces(1001));

  sleep(2);
  ASSERT(!status.is_valid());
}


void test_Database_status()
{
  Castoro::Gateway::Database db(2);

  DESCRIPTION("Database init");
  ASSERT_EQ(db.m_pool_r()->m_pages_r(), 2);
  db.set_expire(10);
  ASSERT_EQ(db.m_expire_r(), 10);

  DESCRIPTION("Database set/get status");
  Castoro::Gateway::PeerStatus s1(1000, 0, Castoro::Gateway::DS_ACTIVE);
  db.set_status(1, s1);
  ASSERT_EQ(db.m_status_r()->size(), 1);
  Castoro::Gateway::PeerStatus s2(2000, 0, Castoro::Gateway::DS_READONLY);
  db.set_status(2, s2);
  ASSERT_EQ(db.m_status_r()->size(), 2);

  Castoro::Gateway::PeerStatus r;
  ASSERT(db.get_status(1, r));
  ASSERT(r.is_enough_spaces(1000));

  ASSERT(db.get_status(2, r));
  ASSERT(!r.is_enough_spaces(1000));

  DESCRIPTION("Database status expires");
  db.set_expire(1);
  db.set_status(1, s1);
  db.get_status(1, r);
  ASSERT(r.is_readable());
  sleep(2);
  db.get_status(1, r);
  ASSERT(!r.is_readable());

  DESCRIPTION("Database status remove");
  db.remove(2);
  ASSERT(db.get_status(1, r));
  ASSERT(!db.get_status(2, r));
  db.remove(1);
  ASSERT(!db.get_status(1, r));

  DESCRIPTION("Database diskspaces");
  db.set_status(1, s1);
  db.set_status(2, s1);
  db.set_status(3, s2);
  db.set_status(4, s2);
  Castoro::Gateway::ArrayOfId peers;
  db.find(500, peers);
  ASSERT_EQ(peers.size(), 2);
  ASSERT_EQ(peers[0], 1);
  ASSERT_EQ(peers[1], 2);
  peers.clear();
  db.find(2000, peers);
  ASSERT_EQ(peers.size(), 0);
}


void test_Database()
{
  const ID PEER1 = 0x12345678, PEER2 = 0x87654321;
  Castoro::Gateway::Database db(2);
  db.set_expire(100);
  Castoro::Gateway::PeerStatus s(1000, 0, Castoro::Gateway::DS_ACTIVE);
  Castoro::Gateway::ArrayOfPeerWithBase result;
  bool removed = false;

  DESCRIPTION("Database insert/find when no peers activated");
  result.clear();
  db.insert(BasketId(0x10001ull), 2, 3, PEER1, 0xff00);
  db.find(BasketId(0x10001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, false);

  result.clear();
  db.insert(BasketId(0x20001ull), 2, 3, PEER2, 0xff0f);
  db.find(BasketId(0x20001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, false);

  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_REQUESTS), 2);
  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_HITS), 0);
  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_COUNT_CLEAR), 0);


  DESCRIPTION("Database insert/find when some peers are activated");
  db.set_status(PEER1, s);

  result.clear();
  db.find(BasketId(0x10001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 1);
  ASSERT_EQ(result[0].peer, PEER1);
  ASSERT_EQ(removed, false);

  result.clear();
  db.find(BasketId(0x20001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, false);

  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_REQUESTS), 2);
  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_HITS), 1);
  ASSERT_EQ(db.stat(Castoro::Gateway::Database::DSTAT_CACHE_COUNT_CLEAR), 500);

 
  DESCRIPTION("Database insert/find when all peers are activated");
  db.set_status(PEER2, s);

  result.clear();
  db.find(BasketId(0x10001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 1);
  ASSERT_EQ(result[0].peer, PEER1);
  ASSERT_EQ(result[0].base, 0xff00);
  ASSERT_EQ(removed, false);

  result.clear();
  db.find(BasketId(0x20001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 1);
  ASSERT_EQ(result[0].peer, PEER2);
  ASSERT_EQ(result[0].base, 0xff0f);
  ASSERT_EQ(removed, false);
 

  DESCRIPTION("Database delete/find.");
  db.insert(BasketId(0x10001ull), 2, 3, PEER1, 0xff00);
  db.insert(BasketId(0x10002ull), 2, 3, PEER1, 0xff00);
  result.clear();
  db.remove(BasketId(0x10001ull), 2, 3, PEER1);
  db.find(BasketId(0x10001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, true);


  DESCRIPTION("Database insert/find when table overflow");
  db.insert(BasketId(0x30001ull), 2, 3, PEER1, 0xff00);
  db.insert(BasketId(0x40001ull), 2, 3, PEER1, 0xff00);

  result.clear();
  db.find(BasketId(0x30001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 1);
  ASSERT_EQ(result[0].peer, PEER1);
  ASSERT_EQ(removed, false);

  result.clear();
  db.find(BasketId(0x40001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 1);
  ASSERT_EQ(result[0].peer, PEER1);
  ASSERT_EQ(removed, false);

  result.clear();
  db.find(BasketId(0x10001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, false);

  result.clear();
  db.find(BasketId(0x20001ull), 2, 3, result, removed);
  ASSERT_EQ(result.size(), 0);
  ASSERT_EQ(removed, false);
}


void test_Database_random()
{
  Castoro::Gateway::Database db(1000);
  Castoro::Gateway::PeerStatus s(1000, 0, Castoro::Gateway::DS_ACTIVE);
  Castoro::Gateway::ArrayOfPeerWithBase result;
  ID bases[100];
  bool removed;

  for(ID p=0; p<100; p++) {
    db.set_status(p*0x1000000 + 1, s);
    bases[p] = ((rand() >> 8) & 0xFFFFFF) + 1;
  }

  DESCRIPTION("Database random access");
  printf("\n");
  uint64_t  found = 0, not_found = 0;
  struct timeval tv0 = { 0, 0 };
  gettimeofday(&tv0, NULL);

  for(int count=0; count<0xF00000; count++) {
    ID p = (rand() >> 8) % 100;
    ID peer = p*0x1000000 + 1;
    ID base = bases[p];

    uint64_t cid = rand();
    db.insert(cid, 2, 3, peer, base);
    result.clear();
    db.find(cid, 2, 3, result, removed);
    if(result.size()==0) {
      // printf("[%d] result.size()=0: cid=%llu, peer=%llx, base=%llx\n", count, cid, peer, base);
      // ASSERT(result.size()>0);
      not_found++;
    } else {
      for(unsigned int i=0; i<result.size(); i++) {
        if((result.at(i).peer==peer) && (result.at(i).base==base)) break;
        if(i==result.size()-1) {
          printf("[%d] cid=%llu, peer=%s, base=%s\n", count, cid, RSTRING_PTR(ID2SYM(peer)), RSTRING_PTR(ID2SYM(base)));
          for(unsigned int j=0; j<result.size(); j++) {
            const char* p = RSTRING_PTR(ID2SYM(result.at(j).peer));
            const char* b = RSTRING_PTR(ID2SYM(result.at(j).base));
            printf("          (%2d) peer=%s, base=%s\n", j, p, b);
          }
          ASSERT(!"Not found");
        }
      }
      found++;
    }
    if((count & 0xFFFF)==0) {
      printf("  m_table :%4u", db.m_table_r()->size());
      printf("  m_status :%4u", db.m_status_r()->size());
      printf("  m_peerh.v :%4u", db.m_peerh_r()->m_hash2id_r()->size());
      printf("  m_peerh.m :%4u", db.m_peerh_r()->m_id2hash_r()->size());
      printf("  m_paths :%4u\n", db.m_paths_r()->size());
      fflush(stdout);
    }
  }
  struct timeval tv1 = { 0, 0 };
  gettimeofday(&tv1, NULL);

  printf("Result: %llu : %llu\n", found, not_found);
  uint64_t t0 = tv0.tv_sec; //*1000000 + tv0.tv_usec;
  uint64_t t1 = tv1.tv_sec; //*1000000 + tv1.tv_usec;
  printf("  Total %llu [sec], %f[us/1]\n", (uint64_t)(t1-t0), (double)((t1-t0)*1000.0*1000.0/(found+not_found)));
}


int main(int argc, char* argv[])
{
  ruby_init();

  test_PeerHash();
  test_ID3();
  test_CachePagePool();
  test_CachePage();
  if((argc>1) && (strcmp(argv[1], "all")==0)) {
    test_PeerStatus();
    test_Database_status();
  }
  test_Database();

  test_Database_random();

  printf("\n%d test(s) passed.\n", g_testcount);

  Castoro::Gateway::CachePage cp;
  printf("sizeof(CachePage) = %d\n", sizeof(cp));
  uint64_t  page = 1024*1024*1024;  // 1GB
  page /= sizeof(cp);
  page *= 4096;
  page /= 1024*1024;
  printf("%lld Mega contents per GiB.\n", page);
 
  ruby_cleanup(0);

  return 0;
}
