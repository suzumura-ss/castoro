#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <strings.h>
#include <time.h>

#include "ruby.h"

static char *read_letters(int fd, char *prompt, char *buffer, size_t length)
{
  char *p = buffer;
  int n;

  for (;;) {
    if ((n = read(fd, p, 1)) == -1) {
      perror("An attempt of reading a character from /dev/tty in read_password() failed.");
      return NULL;
    }
    else if (n == 0) {
      struct timespec spec = { 0, 100 * 1000 };  /* 0 second and 100 * 1000 nanoseconds */
      nanosleep(&spec, NULL);
    }
    if (*p == '\n') {
      break;
    }
    if (1 < length) {  /* keeps room for \0 */
      length--;  /* length is size_t, unsighed, so it cannot be less than zero */
      p++;
    }
  }

  *p = '\0';  /* Replaces the last letter with \0 */
  return buffer;
}


static char *write_prompt(int fd, char *prompt, char *buffer, size_t length)
{
  char *ret;
  int n;

  /* Wrtites the prompt message */
  n = write(fd, prompt, strlen(prompt));

  ret = read_letters(fd, prompt, buffer, length);

  n = write(fd, "\n", 1);
  return ret;
}


static char *suppress_echoing(int fd, char *prompt, char *buffer, size_t length)
{
  struct termios old, new;
  char *ret;

  /* Suppresses echoing letters */
  if ( tcgetattr(fd, &old) != 0 ) {  /* Gets the current settings of the terminal */
    perror("tcgetattr() in suppress_echoing");
    return NULL;
  }
  bcopy(&old, &new, sizeof(new));
  new.c_lflag &= ~( ECHO | ECHOE | ECHOK | ECHONL );
  (void) tcsetattr(fd, TCSAFLUSH, &new);  /* Suppresses echoing letters */

  ret = write_prompt(fd, prompt, buffer, length);

  /* Restores the previous settings of the terminal */
  (void) tcsetattr(fd, TCSADRAIN, &old);

  return ret;
}


static char *ignore_signals(int fd, char *prompt, char *buffer, size_t length)
{
  struct sigaction ignore, sigint, sigtstp;
  char *ret;

  /* Ignores signals: Ctrl-C and Ctrl-Z */
  ignore.sa_handler = SIG_IGN;
  sigemptyset(&ignore.sa_mask);
  ignore.sa_flags = 0;
  sigaction(SIGINT,  &ignore, &sigint);
  sigaction(SIGTSTP, &ignore, &sigtstp);

  ret = suppress_echoing(fd, prompt, buffer, length);

  /* Restores the previous settings of the signals */
  sigaction(SIGINT, &sigint, NULL);
  sigaction(SIGTSTP, &sigtstp, NULL);

  return ret;
}


static char *read_password(char *prompt, char *buffer, size_t length)
{
  int fd;
  char *ret;

  if ((fd = open("/dev/tty", O_RDWR)) == -1) {
    perror("An attempt of opening /dev/tty in read_password() failed.");
    return NULL;
  }
  
  ret = ignore_signals(fd, prompt, buffer, length);

  close(fd);
  return ret;
}


VALUE rb_cPasswordReader;

#if defined(RSTRING_PTR)           /* Ruby 1.9.x */
#define rstring_ptr RSTRING_PTR
#elif defined(StringValuePtr)      /* Ruby 1.8.x */
#define rstring_ptr StringValuePtr
#endif

static VALUE rb_read_password(VALUE klass, VALUE prompt)
{
  char buffer[256];
  char *str;
  VALUE ret;
  
  if ((str = read_password(rstring_ptr(prompt), buffer, sizeof(buffer))) == NULL) {
    rb_raise(rb_eRuntimeError, "Something goes wrong in PasswordReader.read_password");
  }
  ret = rb_str_new(str, strlen(str));
  bzero(buffer, sizeof(buffer));  /* make it secure by erasing data in the buffer */
  return ret;
}

static VALUE rb_erase_string(VALUE klass, VALUE string)
{
  char *s;

  switch (TYPE(string)) {

  case T_STRING:
    s = rstring_ptr(string);
    bzero(s, strlen(s));
    break;

  default:
    rb_raise(rb_eArgError, "the parameter must be a String");
  }

  return string;
}

void Init_password_reader(void)
{
  rb_cPasswordReader = rb_define_class("PasswordReader", rb_cObject);
  rb_define_singleton_method(rb_cPasswordReader, "read_password", rb_read_password, 1);
  rb_define_singleton_method(rb_cPasswordReader, "erase_string", rb_erase_string, 1);
}

