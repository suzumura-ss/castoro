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

#include "traverse.hxx"
#include "memory.hxx"

Dumper::Dumper(VALUE io)
{
  _io = io;
}

void
Dumper::operator()(const Key& key, const Val& val) const
{
  VALUE format = rb_str_new2("  %s: %d.%d.%d");

  PeerId* p = val.getPeers();
  for (uint8_t i = 0; i < val.getPeerSize(); i++) {
    if (*(p+i) != 0) {
      VALUE peer = ID2SYM(*(p+i));
      VALUE c    = ULL2NUM(key.getContent());
      VALUE t    = UINT2NUM(key.getType());
      VALUE r    = UINT2NUM(val.getRev());
      VALUE args = rb_ary_new3(4, peer, c, t, r);
      VALUE line = rb_funcall(format, id_format, 1, args);

      rb_funcall(_io, id_puts, 1, line);
    }
  }
}

FilteredDumper::FilteredDumper(VALUE io, VALUE peers)
{
  _io = io;
  _ids = NULL;
  _size = 0;

  VALUE a;
  switch (TYPE(peers)) {
    case T_ARRAY:
      a = peers;
      break;

    default:
      if (rb_respond_to(peers, id_to_ary)) {
        a = rb_funcall(peers, id_to_ary, 0);
      } else if (rb_respond_to(peers, id_to_a)) {
        a = rb_funcall(peers, id_to_a, 0);
      } else {
        a = rb_ary_new3(1, peers);
      }
      break;
  }
  _size = NUM2UINT(rb_funcall(a, id_size, 0));

  if (_size) {
    _ids = (PeerId*)ruby_xmalloc(sizeof(PeerId) * _size);
    for (uint32_t i = 0; i < _size; i++) {
      *(_ids+i) = rb_to_id(rb_ary_entry(a, i));
    }
  }
}

FilteredDumper::~FilteredDumper()
{
  if (_ids) ruby_xfree(_ids);
}

void
FilteredDumper::operator()(const Key& key, const Val& val) const
{
  VALUE format = rb_str_new2("  %s: %d.%d.%d");

  PeerId* p = val.getPeers();
  for (uint8_t i = 0; i < val.getPeerSize(); i++) {
    if (*(p+i) != 0 && isInclude(*(p+i))) {
      VALUE peer = ID2SYM(*(p+i));
      VALUE c    = ULL2NUM(key.getContent());
      VALUE t    = UINT2NUM(key.getType());
      VALUE r    = UINT2NUM(val.getRev());
      VALUE args = rb_ary_new3(4, peer, c, t, r);
      VALUE line = rb_funcall(format, id_format, 1, args);

      rb_funcall(_io, id_puts, 1, line);
    }
  }
}

bool
FilteredDumper::isInclude(PeerId id) const
{
  for (uint32_t i = 0; i < _size; i++) {
    if (*(_ids+i) == id) return true;
  }
  return false;
}

Traverser::Traverser(kc::PolyDB* db, VALUE locker, uint8_t peerSize, size_t valsiz)
{
  _db = db;
  _cur = _db->cursor();
  _locker = locker;
  _peerSize = peerSize;
  _valsiz = valsiz;
}

Traverser::~Traverser()
{
  if (_cur) delete _cur;
  if (RTEST(rb_mutex_locked_p(_locker))) rb_mutex_unlock(_locker);
}

void
Traverser::traverse(const TraverseLogic& logic)
{
  Key* k;
  Val v(_peerSize);
  Memory<char> m(_valsiz);
  char* p = m.pointer();
  size_t ksiz, vsiz;

  rb_mutex_lock(_locker);
  if (_cur->jump()) {
    while(k = (Key*)_cur->get(&ksiz, (const char**)&p, &vsiz, true)) {
      v.deserialize(p);
      logic(*k, v);
    }
  }
  rb_mutex_unlock(_locker);
}

