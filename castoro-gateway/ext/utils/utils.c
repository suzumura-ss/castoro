#include <string.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>

#include "ruby.h"

static VALUE rb_mCastoro, rb_mUtils;

VALUE
rb_castoro_utils_network_interfaces(VALUE self)
{
  VALUE results = rb_hash_new();

  VALUE ip = ID2SYM(rb_intern("ip"));
  VALUE mask = ID2SYM(rb_intern("mask"));
  VALUE broadcast = ID2SYM(rb_intern("broadcast"));

  struct ifaddrs *ifa_list;
  struct ifaddrs *ifa;
  int n;
  char addrstr[256], netmaskstr[256];

  n = getifaddrs(&ifa_list);
  if (n != 0) return results;

  for (ifa = ifa_list; ifa != NULL; ifa = ifa->ifa_next) {
    memset(addrstr, 0, sizeof(addrstr));
    memset(netmaskstr, 0, sizeof(netmaskstr));

    if (ifa->ifa_addr->sa_family == AF_INET) {
      inet_ntop(AF_INET, &((struct sockaddr_in*)ifa->ifa_addr)->sin_addr, addrstr, sizeof(addrstr));
      inet_ntop(AF_INET, &((struct sockaddr_in*)ifa->ifa_netmask)->sin_addr, netmaskstr, sizeof(netmaskstr));

      VALUE nif = rb_hash_new();
      VALUE a = rb_str_new2(addrstr);
      VALUE m = rb_str_new2(netmaskstr);
      VALUE b = rb_funcall(rb_mUtils, rb_intern("broadcast"), 2, a, m);

      rb_hash_aset(nif, ip, a);
      rb_hash_aset(nif, mask, m);
      rb_hash_aset(nif, broadcast, b);

      rb_hash_aset(results, rb_str_new2(ifa->ifa_name), nif);
    }
  }

  freeifaddrs(ifa_list);

  return results;
}

void
Init_utils(void)
{
  rb_mCastoro = rb_define_module("Castoro"); 
  rb_mUtils = rb_define_module_under(rb_mCastoro, "Utils");

  rb_define_singleton_method(rb_mUtils, "network_interfaces", rb_castoro_utils_network_interfaces, 0);
  rb_eval_string(
    "module Castoro; module Utils; private;def self.broadcast ip, mask;"
    "ip.split('.').map(&:to_i).zip(mask.split('.').map { |o| ~(o.to_i) & 255 }).map { |i,m| i|m }.join('.');"
    "end; end; end"
  );
}

