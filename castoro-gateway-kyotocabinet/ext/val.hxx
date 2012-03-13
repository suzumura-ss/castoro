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

#ifndef _INCLUDE_RECORD_H_
#define _INCLUDE_RECORD_H_

#include "stdinc.hxx"

class Val
{
  public:
    static const uint32_t PEER_COUNT = 3;

    Val();
    Val(const Val& other);
    Val(Val* other);

    void clear();
    uint8_t getRev() const;
    void setRev(uint8_t rev);
    bool isInclude(ID peer) const;
    void setPeer(ID peer);
    void resetPeer(ID peer);
    const ID* getPeers() const;

  private:
    uint8_t _rev;
    ID _peers[PEER_COUNT];
};

#endif // _INCLUDE_RECORD_H_

