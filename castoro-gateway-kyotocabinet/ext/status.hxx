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

#ifndef _INCLUDE_STATUS_H_
#define _INCLUDE_STATUS_H_

#include "stdinc.hxx"

class Status
{
  public:
    Status();

    void set(uint64_t available);
    void set(uint32_t status);
    void set(uint64_t available, uint32_t status);

    bool isReadable(time_t expire) const;
    bool isWritable(time_t expire) const;
    bool isEnoughSpaces(time_t expire, uint64_t require) const;

    uint64_t getAvailable() const;
    uint32_t getStatus() const;

  private:
    uint64_t _available;
    uint32_t _status;
    time_t _activatedAt;

    bool isValid(time_t expire) const;
    time_t getTime() const;
};

#endif // _INCLUDE_STATUS_H_

