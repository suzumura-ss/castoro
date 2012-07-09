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

#include <stdio.h>
#include <security/pam_appl.h>

#if HAVE_CONFIG_H
#include "config.h"
#endif

#if HAVE_SECURITY_PAM_MISC_H
#include <security/pam_misc.h>

/* CentOS has misc_conv() */
#define conversation misc_conv

#else

#include <stdlib.h>
#include <unistd.h>
#include <string.h>

/* OpenSolaris does not have misc_conv() */
int conversation(int num_msg, struct pam_message **msg, struct pam_response **resp, void *appdata_ptr)
{
  const struct pam_message *m = *msg;
  struct pam_response *r;
  char *password;

  if (num_msg <= 0 || PAM_MAX_NUM_MSG <= num_msg) {
    fprintf(stderr, "Invalid number of messages\n");
    *resp = NULL;
    return PAM_CONV_ERR;
  }

  if ((*resp = r = calloc(num_msg, sizeof(struct pam_response))) == NULL)
    return PAM_BUF_ERR;

  while (num_msg-- > 0) {
    switch (m->msg_style) {

    case PAM_PROMPT_ECHO_OFF:
      password = getpassphrase("Password: ");
      r->resp = strdup(password);  /* this will be freed by the PAM library */
      m++;
      r++;
      break;

    case PAM_PROMPT_ECHO_ON:
      if (m->msg)
	fputs(m->msg, stdout);
      r->resp = NULL;
      m++;
      r++;
      break;

    case PAM_ERROR_MSG:
      if (m->msg)
	fprintf(stderr, "%s\n", m->msg);
      m++;
      r++;
      break;

    case PAM_TEXT_INFO:
      if (m->msg)
	printf("%s\n", m->msg);
      m++;
      r++;
      break;
    }
  }

  return PAM_SUCCESS;
}
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
    fprintf(stderr, "%s: %s\n", program, pam_strerror(ph, result));
    return 1;
  }

  return 0;
}
