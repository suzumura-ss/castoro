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

#ifndef __INCLUDE_ALLOCATOR_H__
#define __INCLUDE_ALLOCATOR_H__

#include "stdinc.hxx"

template <class T>
class Allocator
{
  public:
    typedef size_t size_type;
    typedef ptrdiff_t difference_type;
    typedef T* pointer;
    typedef const T* const_pointer;
    typedef T& reference;
    typedef const T& const_reference;
    typedef T value_type;

    template <class U>
    struct rebind
    {
      typedef Allocator<U> other;
    };

    // constructor
    Allocator() throw() {}
    Allocator(const Allocator&) throw() {}
    template <class U> Allocator(const Allocator<U>&) throw() {}

    // destructor
    ~Allocator() throw() {}
    
    // allocate
    pointer allocate(size_type num, Allocator<T>::const_pointer hint = 0)
    {
      return (pointer)ruby_xmalloc(num * sizeof(T));
    }
    void construct(pointer p, const_reference value)
    {
      new( (void*)p ) T(value);
    }

    // deallocate
    void deallocate(pointer p, size_type num)
    {
      ruby_xfree((void*)p);
    }
    void destroy(pointer p)
    {
      p->~T();
    }

    pointer address(reference value) const { return &value; }
    const_pointer address(const_reference value) const { return &value; }

    size_type max_size() const throw()
    {
      return std::numeric_limits<size_t>::max() / sizeof(T);
    }
};

template <class T1, class T2>
bool operator==(const Allocator<T1>&, const Allocator<T2>&) throw() { return true; }
template <class T1, class T2>
bool operator!=(const Allocator<T1>&, const Allocator<T2>&) throw() { return false; }

#endif // __INCLUDE_ALLOCATOR_H__

