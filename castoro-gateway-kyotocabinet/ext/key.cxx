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

#include "key.hxx"

Key::Key()
{
  _c = 0;
  _t = 0;
}

Key::Key(uint64_t c, uint32_t t)
{
  _c = c;
  _t = t;
}

Key::Key(const Key& other)
{
  _c = other._c;
  _t = other._t;
}

bool Key::operator==(const Key& other) const
{
  return _c == other._c && _t == other._t;
}

bool Key::operator<(const Key& other) const
{
  if (_c == other._c)
    return _t < other._t;
  else
    return _c < other._c;
}

Key& Key::operator=(const Key& other)
{
  _t = other._t;
  _c = other._c;

  return *this;
}

uint64_t
Key::getContent() const
{
  return _c;
}

uint32_t
Key::getType() const
{
  return _t;
}

