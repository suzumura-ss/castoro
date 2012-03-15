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

size_t Val::getSize(uint8_t peerSize)
{
  return sizeof(uint8_t) + sizeof(ID)*peerSize;
}

Val::Val(uint8_t peerSize)
{
  _peerSize = peerSize;
  _peers = (ID*)ruby_xmalloc(sizeof(ID)*_peerSize);
  clear();
}

void
Val::clear()
{
  _rev = 0;
  for (uint8_t i = 0; i < _peerSize; i++) *(_peers+i) = 0;
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
  for (uint8_t i = 0; i < _peerSize; i++) {
    if (*(_peers+i) == peer) return true;
  }
  return false;
}

bool
Val::isFull() const
{
  for (uint8_t i = 0; i < _peerSize; i++) {
    if (*(_peers+i) == 0) return false;
  }
  return true;
}

bool
Val::isEmpty() const
{
  for (uint8_t i = 0; i < _peerSize; i++) {
    if (*(_peers+i) != 0) return false;
  }
  return true;
}

void
Val::setPeer(ID peer)
{
  if (isInclude(peer)) return;

  for (uint8_t i = 0; i < _peerSize; i++) {
    if (*(_peers+i) == 0) {
      *(_peers+i) = peer;
      return;
    }
  }
  *(_peers + (_peerSize-1)) = peer;
}

void
Val::removePeer(ID peer)
{
  for (uint8_t i = 0; i < _peerSize; i++) {
    if (*(_peers+i) == peer) {
      *(_peers+i) = 0;
      return;
    }
  }
}

ID*
Val::getPeers() const
{
  return _peers;
}

uint8_t
Val::getPeerSize() const
{
  return _peerSize;
}

void
Val::serialize(void* stream) const
{
  memcpy(stream, &_rev, sizeof(_rev));
  stream = ((uint8_t*)stream) + 1;
  memcpy(stream, _peers, sizeof(ID) * _peerSize);
}

void
Val::deserialize(const void* stream)
{
  const void* p = stream;

  clear();
  _rev = *((uint8_t*)p); p = ((uint8_t*)p) + 1;
  memcpy(_peers, p, sizeof(ID) * _peerSize);
}

