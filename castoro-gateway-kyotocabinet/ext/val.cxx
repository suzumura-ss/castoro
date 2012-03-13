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

#include "val.hxx"

Val::Val()
{
  clear();
}

Val::Val(const Val& other)
{
  _rev = other._rev;
  _peers[0] = other._peers[0];
  _peers[1] = other._peers[1];
  _peers[2] = other._peers[2];
}

Val::Val(Val* other)
{
  if (other) {
    _rev = other->_rev;
    _peers[0] = other->_peers[0];
    _peers[1] = other->_peers[1];
    _peers[2] = other->_peers[2];
  } else {
    clear();
  }
}

void
Val::clear()
{
  _rev = 0;
  _peers[0] = 0;
  _peers[1] = 0;
  _peers[2] = 0;
}

uint8_t
Val::getRev() const
{
  return _rev;
}

void
Val::setRev(uint8_t rev)
{
  if (_rev != rev) clear();
  _rev = rev;
}

bool
Val::isInclude(ID peer) const
{
  return (_peers[0] == peer || _peers[1] == peer || _peers[2] == peer);
}

bool
Val::isEmpty() const
{
  return (_peers[0] == 0 && _peers[1] == 0 && _peers[2] == 0);
}

void
Val::setPeer(ID peer)
{
  if (isInclude(peer)) return;

  if      (_peers[0] == 0) _peers[0] = peer;
  else if (_peers[1] == 0) _peers[1] = peer;
  else                     _peers[2] = peer;
}

void
Val::resetPeer(ID peer)
{
  if      (_peers[0] == peer) _peers[0] = 0;
  else if (_peers[1] == peer) _peers[1] = 0;
  else if (_peers[2] == peer) _peers[2] = 0;
}

const ID*
Val::getPeers() const
{
  return _peers;
}

