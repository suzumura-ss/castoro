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

#ifndef _INCLUDE_MEMORY_H_
#define _INCLUDE_MEMORY_H_

#include "stdinc.hxx"

template<class T>
class Memory
{
  public:
    Memory(size_t size) { _p = (T*)ruby_xmalloc(size * sizeof(T)); }
    ~Memory() { ruby_xfree(_p); }
    T* p() const { return _p; }
  private:
    T* _p;
};

template<>
class Memory<void>
{
  public:
    Memory(size_t size);
    virtual ~Memory();
    void* p() const;
  private:
    void* _p;
};

#endif // _INCLUDE_MEMORY_H_

