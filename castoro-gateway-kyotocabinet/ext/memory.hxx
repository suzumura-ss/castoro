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

template<class T = void>
class Memory
{
  public:
    Memory(size_t size) { _pointer = (T*)ruby_xmalloc(size * sizeof(T)); }
    virtual ~Memory() { ruby_xfree(_pointer); }
    T* pointer() const { return _pointer; }
  private:
    T* _pointer;
};

template<>
class Memory<void>
{
  public:
    Memory(size_t size) { _pointer = ruby_xmalloc(size); }
    virtual ~Memory() { ruby_xfree(_pointer); }
    void* pointer() const { return _pointer; }
  private:
    void* _pointer;
};

#endif // _INCLUDE_MEMORY_H_

