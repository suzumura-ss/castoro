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

#ifndef _INCLUDE_PEERS_H_
#define _INCLUDE_PEERS_H_

#include "stdinc.hxx"
#include "status.hxx"

class Peers
{
  public:
    Peers();

    void init();
    void mark();

    void set(ID peer, uint64_t available);
    void set(ID peer, uint32_t status);
    void set(ID peer, uint64_t available, uint32_t status);

    Status getStatus(ID peer);

    uint64_t getCount() const;
    uint64_t getWritableCount(time_t expire) const;
    uint64_t getReadableCount(time_t expire) const;

    std::vector<ID> find() const;
    std::vector<ID> find(time_t expire, uint64_t space) const;

  private:
    std::map<ID, Status> _map;
    VALUE _locker;
};

#endif // _INCLUDE_PEERS_H_

