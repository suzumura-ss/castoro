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
#include <string.h>
#include <security/pam_appl.h>

#ifdef HAVE_SECURITY_PAM_MISC_H
#include <security/pam_misc.h>
#endif

#ifdef HAVE_LIBPAM_MISC  /* -lpam_misc is available in CentOS, not in OpenSolaris */
#define conversation misc_conv  /* CentOS has misc_conv() */
#else
extern int conversation(int num_msg, struct pam_message **msg, struct pam_response **resp, void *appdata_ptr);
#endif

static int opt_quiet = 0;  /* -q command line option */

char *parse(int argc, char *argv[])
{
  char *program = *argv;

  if (--argc >= 1 && *++argv) {
    if (strcmp(*argv, "-q") == 0) {
      opt_quiet = 1;
      --argc;
      *++argv;
    }
  }

  if (argc != 1) {
    fprintf(stderr, "usage: %s [-q] username\n", program);
    exit(2);
  }

  return *argv;
}

int main(int argc, char *argv[])
{
  char *username = parse(argc, argv);
  struct pam_conv conv = {conversation, NULL};
  pam_handle_t *ph;
  int result;

  if ((result = pam_start("passwd", username, &conv, &ph)) == PAM_SUCCESS) {
    result = pam_authenticate(ph, 0);
    pam_end(ph, 0);
  }

  if (result == PAM_SUCCESS) {
    if (! opt_quiet)
      printf("Authentication success\n");
    return 0;
  }
  else {
    if (! opt_quiet)
      printf("%s\n", pam_strerror(ph, result));
    return 1;
  }
}
