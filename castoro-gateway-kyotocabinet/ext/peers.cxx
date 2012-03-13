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

#include "peers.hxx"

Peers::Peers()
{
  _locker = NULL;
}

void
Peers::init()
{
  _locker = rb_class_new_instance(0, NULL, cls_mutex);
}

void
Peers::mark()
{
  if (_locker) rb_gc_mark(_locker);
}

void
Peers::set(ID peer, uint64_t available)
{
  rb_mutex_lock(_locker);
  _map[peer].set(available);
  rb_mutex_unlock(_locker);
}

void
Peers::set(ID peer, uint32_t status)
{
  rb_mutex_lock(_locker);
  _map[peer].set(status);
  rb_mutex_unlock(_locker);
}

void
Peers::set(ID peer, uint64_t available, uint32_t status)
{
  rb_mutex_lock(_locker);
  _map[peer].set(available, status);
  rb_mutex_unlock(_locker);
}

Status
Peers::getStatus(ID peer)
{
  Status ret;

  rb_mutex_lock(_locker);
  ret = _map[peer];
  rb_mutex_unlock(_locker);

  return ret;
}

uint64_t
Peers::getCount() const
{
  uint64_t ret;

  rb_mutex_lock(_locker);
  ret = _map.size();
  rb_mutex_unlock(_locker);

  return ret;
}

uint64_t
Peers::getWritableCount(time_t expire) const
{
  uint64_t ret = 0;

  rb_mutex_lock(_locker);
  for (std::map<ID, Status>::const_iterator it = _map.begin(); it != _map.end(); it++) {
    if ((*it).second.isWritable(expire)) ret++;
  }
  rb_mutex_unlock(_locker);

  return ret;
}

uint64_t
Peers::getReadableCount(time_t expire) const
{
  uint64_t ret = 0;

  rb_mutex_lock(_locker);
  for (std::map<ID, Status>::const_iterator it = _map.begin(); it != _map.end(); it++) {
    if ((*it).second.isReadable(expire)) ret++;
  }
  rb_mutex_unlock(_locker);

  return ret;
}

std::vector<ID>
Peers::find() const
{
  std::vector<ID> ret;

  rb_mutex_lock(_locker);
  for (std::map<ID, Status>::const_iterator it = _map.begin(); it != _map.end(); it++) {
    ret.push_back((*it).first);
  }
  rb_mutex_unlock(_locker);

  return ret;
}

std::vector<ID>
Peers::find(time_t expire, uint64_t space) const
{
  std::vector<ID> ret;

  rb_mutex_lock(_locker);
  for (std::map<ID, Status>::const_iterator it = _map.begin(); it != _map.end(); it++) {
    if ((*it).second.isEnoughSpaces(expire, space)) ret.push_back((*it).first);
  }
  rb_mutex_unlock(_locker);

  return ret;
}

