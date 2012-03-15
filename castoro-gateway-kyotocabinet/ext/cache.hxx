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

#ifndef _INCLUDE_CACHE_H_
#define _INCLUDE_CACHE_H_

#include "stdinc.hxx"
#include "key.hxx"
#include "val.hxx"
#include "peers.hxx"
#include "status.hxx"
#include "traverse.hxx"

class Cache
{
  public:
    Cache();
    virtual ~Cache();

    void  init(VALUE size, VALUE options);
    void  mark();
    VALUE find(VALUE _c, VALUE _t, VALUE _r);
    VALUE findPeers();
    VALUE findPeers(VALUE requireSpaces);
    void  insertElement(VALUE _p, VALUE _c, VALUE _t, VALUE _r);
    void  eraseElement(VALUE _p, VALUE _c, VALUE _t, VALUE _r);
    VALUE getPeerStatus(VALUE _p);
    void  setPeerStatus(VALUE _p, VALUE _s);
    void  dump(VALUE _f);
    void  dump(VALUE _f, VALUE _p);
    VALUE stat(VALUE _k);

    void raiseOnError() const;

  private:
    kc::PolyDB* _db;
    Peers _peers;
    time_t _expire;
    uint8_t _peerSize;
    size_t _valsiz;
    VALUE _logger;
    VALUE _locker;

    uint64_t _requests;
    uint64_t _hits;

    bool get(const Key& k, Val* v, bool lock) const;
};

#endif // _INCLUDE_CACHE_H_

