#include <string.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <stdio.h>
#include <net/if.h>
#include <sys/ioctl.h>

#include "ruby.h"


extern in_addr_t getBcasAddr(in_addr_t ipAddrp); 
static VALUE rb_mCastoro, rb_mUtils;

VALUE rb_castoro_utils_get_bcast(VALUE self, VALUE ipValue)
{
  char* ipStr;
  struct in_addr ip;
  char bcastStr[256];
  in_addr_t bcast;  

  ipStr = StringValuePtr(ipValue); 
 
  memset(bcastStr, 0, sizeof(bcastStr)); 
  inet_pton(AF_INET, ipStr, &ip);
  bcast = getBcasAddr(ip.s_addr);
  inet_ntop(AF_INET, &bcast, &bcastStr, sizeof(bcastStr));
  /*printf("result:IP=%d bcast=%d bcastStr=%s\n", ip.s_addr, bcast, bcastStr); */

  return rb_str_new2(bcastStr);
}
 
#define INT_TO_ADDR(_addr) \
(_addr & 0xFF), \
(_addr >> 8 & 0xFF), \
(_addr >> 16 & 0xFF), \
(_addr >> 24 & 0xFF)

in_addr_t getBcasAddr(in_addr_t ipAddrp)
{
  struct ifconf ifc;
  struct ifreq ifr[10];
  int sd, ifc_num, i;

  in_addr_t devAddrp; 
  in_addr_t bcast = 0;

  sd = socket(PF_INET, SOCK_DGRAM, 0);
  if (sd > 0)
  {
    ifc.ifc_len = sizeof(ifr);
    ifc.ifc_ifcu.ifcu_buf = (caddr_t)ifr;
  
    /* get interface list */
    if (ioctl(sd, SIOCGIFCONF, &ifc) == 0)
    {
     ifc_num = ifc.ifc_len / sizeof(struct ifreq);
     for (i = 0; i < ifc_num; ++i)
      {
       if (ifr[i].ifr_addr.sa_family != AF_INET)
        {
          continue;
        }
     
       /* Retrieve the IP address, broadcast address, and subnet mask. */
       if (ioctl(sd, SIOCGIFADDR, &ifr[i]) == 0)
        {
         /* s_addr is uint32_t */
         devAddrp = ((struct sockaddr_in *)(&ifr[i].ifr_addr))->sin_addr.s_addr;
         /* printf("check IP:dev=%d, ip=%d\n", devAddrp, ipAddrp); */
         if (ipAddrp == devAddrp)
          {  
           if (ioctl(sd, SIOCGIFBRDADDR, &ifr[i]) == 0)
             {
             bcast = ((struct sockaddr_in *)(&ifr[i].ifr_broadaddr))->sin_addr.s_addr;
             /* printf("FIX:bcast=%d\n", bcast); */
             break;
             }
          } 
        }
      } /* end of for*/ 
    } 
  }
  close(sd);
  return bcast;
}


void Init_utils(void)
{
  rb_mCastoro = rb_define_module("Castoro"); 
  rb_mUtils = rb_define_module_under(rb_mCastoro, "Utils");
  rb_define_singleton_method(rb_mUtils, "get_bcast", rb_castoro_utils_get_bcast, 1);
}

