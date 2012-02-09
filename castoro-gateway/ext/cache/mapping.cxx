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

#include "mapping.hxx"


namespace Castoro {
namespace Gateway {


//
// class PeerHash
//
PeerHash::PeerHash()
{
  m_next = 1;
  m_hash2id.push_back((ID)-1);
}

PEERH PeerHash::fromID(ID id)
{
  std::map<ID, PEERH>::iterator h = m_id2hash.find(id);
  if(h==m_id2hash.end()) {
    m_id2hash.insert(std::make_pair(id, m_next));
    m_hash2id.push_back(id);
    return m_next++;
  }
  return (*h).second;
}

ID PeerHash::toID(PEERH h) const
{
  if(m_hash2id.size()<=h) return ((ID)-1);
  return m_hash2id.at(h);
}


}
}
