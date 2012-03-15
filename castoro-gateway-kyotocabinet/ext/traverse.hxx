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

#ifndef _INCLUDE_TRAVERSE_H_
#define _INCLUDE_TRAVERSE_H_

#include "stdinc.hxx"
#include "key.hxx"
#include "val.hxx"

class TraverseLogic
{
  public:
    virtual void operator()(const Key& key, const Val& val) const = 0;
};

class Dumper : public TraverseLogic
{
  public:
    Dumper(VALUE io);
    void operator()(const Key& key, const Val& val) const;

  private:
    VALUE _io;
};

class FilteredDumper : public TraverseLogic
{
  public:
    FilteredDumper(VALUE io, VALUE peers);
    ~FilteredDumper();
    void operator()(const Key& key, const Val& val) const;

  private:
    VALUE _io;
    ID* _ids;
    uint32_t _size;

    bool isInclude(ID id) const;
};

class Traverser
{
  public:
    Traverser(kc::PolyDB* db, VALUE locker, uint8_t peerSize, size_t valsiz);
    virtual ~Traverser();

    void traverse(const TraverseLogic& logic);

  private:
    kc::PolyDB* _db;
    kc::DB::Cursor* _cur;
    VALUE _locker;
    uint8_t _peerSize;
    size_t _valsiz;
};

#endif // _INCLUDE_TRAVERSE_H_

