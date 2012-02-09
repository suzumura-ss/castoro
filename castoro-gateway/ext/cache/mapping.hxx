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

#ifndef __INCLUDE_GATEWAY_MAPPING_H__
#define __INCLUDE_GATEWAY_MAPPING_H__

#include "basetypes.hxx"


namespace Castoro {
namespace Gateway {

  // { peer } <=> { peer code } mapping.
  typedef uint16_t  PEERH;
  class PeerHash {
    typedef std::vector<ID>     ID_VECTOR;
    typedef std::map<ID, PEERH> PEERH_MAP; 

  public:
    PeerHash();
    inline virtual ~PeerHash() {};
    PEERH fromID(ID id);
    ID toID(PEERH h) const;

    attr_reader(PEERH, m_next);
    attr_reader_ref(ID_VECTOR, m_hash2id);
    attr_reader_ref(PEERH_MAP, m_id2hash);

  private:
    PEERH m_next;
    ID_VECTOR m_hash2id;
    PEERH_MAP m_id2hash; 
  };


}
}


#endif //__INCLUDE_GATEWAY_MAPPING_H__
