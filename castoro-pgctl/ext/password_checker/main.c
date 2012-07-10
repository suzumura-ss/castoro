/*
   Copyright 2010 Ricoh Company, Ltd.

   This file is part of Castoro.

   Castoro is free software: you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Castoro is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
*/

#if HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <security/pam_appl.h>

#ifdef HAVE_SECURITY_PAM_MISC_H
#include <security/pam_misc.h>
#endif

#ifdef HAVE_LIBPAM_MISC  /* -lpam_misc is available in CentOS, not in OpenSolaris */
#define conversation misc_conv  /* CentOS has misc_conv() */
#else
extern int conversation(int num_msg, struct pam_message **msg, struct pam_response **resp, void *appdata_ptr);
#endif


int main(int argc, char **argv)
{
  char *program = *argv;
  struct pam_conv conv = {conversation, NULL};
  pam_handle_t *ph;
  int result;

  if (--argc != 1) {
    fprintf(stderr, "usage: %s username\n", program);
    return 2;
  }

  if ((result = pam_start("passwd", *++argv, &conv, &ph)) == PAM_SUCCESS) {
    result = pam_authenticate(ph, 0);
    pam_end(ph, 0);
  }

  if (result != PAM_SUCCESS) {
    printf("%s: %s\n", program, pam_strerror(ph, result));
    return 1;
  }

  printf("%s: Authentication success\n", program);
  return 0;
}
