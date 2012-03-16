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
#include "allocator.hxx"

class Peers
{
  private:
    typedef std::map<PeerId, Status, std::less<PeerId>, Allocator<std::pair<const PeerId, Status> > > PeerStatus;

  public:
    Peers();

    void init();
    void mark();

    void set(PeerId peer, uint64_t available);
    void set(PeerId peer, uint32_t status);
    void set(PeerId peer, uint64_t available, uint32_t status);

    Status getStatus(PeerId peer);

    uint64_t getCount() const;
    uint64_t getWritableCount(time_t expire) const;
    uint64_t getReadableCount(time_t expire) const;

    void find(PeerId* peers, uint64_t* count) const;
    void find(PeerId* peers, uint64_t* count, time_t expire, uint64_t space) const;

  private:
    PeerStatus _map;
    VALUE _locker;
};

#endif // _INCLUDE_PEERS_H_

