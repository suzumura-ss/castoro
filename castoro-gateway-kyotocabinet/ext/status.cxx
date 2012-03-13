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

#include "status.hxx"

Status::Status()
{
  _available = 0;
  _status = 0;
  _activatedAt = 0;
}

void
Status::set(uint64_t available)
{
  _available = available;
  _activatedAt = getTime();
}

void
Status::set(uint32_t status)
{
  _status = status;
  _activatedAt = getTime();
}

void
Status::set(uint64_t available, uint32_t status)
{
  _available = available;
  _status = status;
  _activatedAt = getTime();
}

bool
Status::isReadable(time_t expire) const
{
  return isValid(expire) && ((_status / 10) >= 2);
}

bool
Status::isWritable(time_t expire) const
{
  return isValid(expire) && ((_status / 10) >= 3);
}

bool
Status::isEnoughSpaces(time_t expire, uint64_t require) const
{
  return isWritable(expire) && (_available >= require);
}

uint64_t
Status::getAvailable() const
{
  return _available;
}

uint32_t
Status::getStatus() const
{
  return _status;
}

bool
Status::isValid(time_t expire) const
{
  return (getTime() - _activatedAt) < expire;
}

time_t
Status::getTime() const
{
  timeval tv = { 0, 0 };
  gettimeofday(&tv, NULL);
  return tv.tv_sec;
}

