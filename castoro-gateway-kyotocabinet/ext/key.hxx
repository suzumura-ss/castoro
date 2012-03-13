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

#ifndef _INCLUDE_KEY_H_
#define _INCLUDE_KEY_H_

#include "stdinc.hxx"

class Key
{
  public:
    Key();
    Key(uint64_t c, uint32_t t);
    Key(const Key& other);

    bool operator==(const Key& other) const;
    bool operator<(const Key& other) const;
    Key& operator=(const Key& other);

    uint64_t getContent() const;
    uint32_t getType() const;

  private:
    uint64_t _c;
    uint32_t _t;
};

#endif // _INCLUDE_KEY_H

