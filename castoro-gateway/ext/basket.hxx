
#ifndef _INCLUDE_BASKETID_H_
#define _INCLUDE_BASKETID_H_

#include "ruby.h"

namespace Castoro {
namespace Gateway {

class BasketId
{
private:
  uint64_t _higher;
  uint64_t _lower;

public:
  /**
   * constructors.
   */
  inline BasketId(): _higher(0), _lower(0) {}
  inline BasketId(uint64_t lower): _higher(0), _lower(lower) {}
  inline BasketId(uint64_t higher, uint64_t lower): _higher(higher), _lower(lower) {}
  inline BasketId(VALUE num) {
    num = rb_funcall(num, rb_intern("to_i"), 0);
    this->_higher = NUM2ULL(rb_funcall(num, rb_intern(">>"), 1, INT2NUM(64)));
    this->_lower = NUM2ULL(rb_funcall(num, rb_intern("&"), 1, ULL2NUM(0xFFFFFFFFFFFFFFFFll)));
  }
  inline ~BasketId() {}
  inline BasketId(const BasketId& other) {
    this->_higher = other._higher;
    this->_lower = other._lower;
  }
  inline BasketId& operator=(const BasketId& other) {
    this->_higher = other._higher;
    this->_lower = other._lower;
    return (*this);
  }

  /**
   * operators.
   */
  inline bool operator<(const BasketId& other) const {
    return (this->_higher == other._higher) ? (this->_lower < other._lower)
                                            : (this->_higher < other._higher);
  }
  inline bool operator==(const BasketId& other) const {
    return (this->_higher == other._higher) && (this->_lower == other._lower);
  }
  inline BasketId operator&(const BasketId& other) const {
    return BasketId(this->_higher & other._higher, this->_lower & other._lower);
  }
  inline BasketId operator|(const BasketId& other) const {
    return BasketId(this->_higher | other._higher, this->_lower | other._lower);
  }
  inline BasketId operator~() const {
    return BasketId(~(this->_higher), ~(this->_lower));
  }
  inline BasketId operator+(const uint64_t& other) const {
    uint64_t higher;
    uint64_t lower;
    lower = this->_lower + other;
    if (lower < this->_lower) {
      higher = this->_higher + 1ull;
    } else {
      higher = this->_higher;
    }
    return BasketId(higher, lower);
  }
  inline BasketId operator-(const uint64_t& other) const {
    uint64_t higher;
    uint64_t lower;
    lower = this->_lower - other;
    if (lower > this->_lower) {
      higher = this->_higher - 1ull;
    } else {
      higher = this->_higher;
    }
    return BasketId(higher, lower);
  }

  inline uint64_t higher() const { return this->_higher; }
  inline uint64_t lower() const { return this->_lower; }

  inline VALUE to_num() const {
    VALUE num = ULL2NUM(this->_higher);
    num = rb_funcall(num, rb_intern("<<"), 1, INT2NUM(64));
    num = rb_funcall(num, rb_intern("+"), 1, ULL2NUM(this->_lower));
    return num;
  }
};

}
}

#endif // _INCLUDE_BASKETID_H_

