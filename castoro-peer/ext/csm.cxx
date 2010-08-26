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

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <stdarg.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <dirent.h>

#include <iostream>
#include <string>
#include <stdexcept>

using namespace std;

#define BASE_DIR "/expdsk/"
#define VERSION_NUMBER "0.2.0"

class xia : public invalid_argument
{
public:
  int code;

  xia( int _code, const string& message ) :
    invalid_argument( message ), code( _code ) {}
};

class xre : public runtime_error
{
public:
  int code;

  xre( int _code, const string& message ) :
    runtime_error( message ), code( _code ) {}
};

char* xspf(const char* format, ...)  // x_sprintf
{
  static char buffer[ BUFSIZ ];

  va_list ap;
  va_start(ap, format);
  (void) vsnprintf(buffer, sizeof(buffer), format, ap);
  va_end(ap);
  return buffer;
}

char* validation( char* s )
{
  if ( strncmp( s, BASE_DIR, sizeof(BASE_DIR)-1 ) == 0 )
    return s;
  else
    throw xia( 10, xspf("Invalid direcory: %s\n", s) );
}

uid_t convert_to_uid( char *s )
{
  char c = s[0];
  if ( '0' <= c && c <= '9' ) {
    return atoi(s);
  }
  else {
    struct passwd *p = getpwnam(s);
    if (p)
      return p->pw_uid;
    else
      throw xia( 20, xspf("Invalid user id: %s\n", s) );
  }
}

gid_t convert_to_gid( char *s )
{
  char c = s[0];
  if ( '0' <= c && c <= '9' ) {
    return atoi(s);
  }
  else {
    struct group *p = getgrnam(s);
    if (p)
      return p->gr_gid;
    else
      throw xia( 22, xspf("Invalid group id: %s\n", s) );
  }
}

mode_t convert_to_mode( char *s )
{
  char c = s[0];
  if ( '0' <= c && c <= '9' ) {
    mode_t x = strtol( s, NULL, 8 );
    return x;
  }
  else
    throw xia( 24, xspf("Invalid mode: %s\n", s) );
}

class Command
{
  int argc;
  char **argv;
  char *command;
  uid_t uid;
  gid_t gid;
  mode_t mode;
  pid_t pid;
  bool uid_flag;
  bool gid_flag;
  bool mode_flag;
  bool verbose;

public:
  Command( int _argc, char** _argv ) : argc(_argc), argv(_argv) {
    uid = geteuid();
    gid = getegid();
    mode = 0755;
    pid = getpid();
    uid_flag = false;
    gid_flag = false;
    mode_flag = false;
    verbose = false;
    if (0 < --argc)
      command = *++argv;
    else
      throw xia( 30, "No subcommand is specified." );

    parse();

    if (verbose)
      printf("command=%s, uid=%d, gid=%d, mode=%04o, pid=%d\n", command, uid, gid, mode, pid);
  }

  void dispatch() {
    if ( strcmp( command, "mkdir" ) == 0 )
      x_mkdir();
    else if ( strcmp( command, "mv" ) == 0 )
      x_mv();
    else if ( strcmp( command, "rmdir" ) == 0 )
      x_rmdir();
    else
      throw xia( 32, xspf("Unknown subcommand: %s\n", command) );
  }

protected:
  void parse() {
    int c;
    extern char *optarg;
    extern int optind, opterr, optopt;

    while ((c = getopt(argc, argv, "vu:g:m:")) != -1) {
      switch(c) {
      case 'v':
	verbose = true;
	break;
      case 'u':
	uid = convert_to_uid( optarg );
	uid_flag = true;
	break;
      case 'g':
	gid = convert_to_gid( optarg );
	gid_flag = true;
	break;
      case 'm':
	mode = convert_to_mode( optarg );
	mode_flag = true;
	break;
      case ':':
	throw xia( 34, xspf("Option -%c requires an operand\n", optopt) );
      case '?':
	throw xia( 36, xspf("Unrecognized option: -%c\n", optopt) );
      }
    }

    argc -= optind;
    argv += optind;
  }

  void x_mkdir_sub2( char *path )
  {
    char s[ PATH_MAX + 1 ];
    strncpy(s, xspf("%s.%d", path, pid), sizeof(s));
    if ( access(path, F_OK) == 0 )
      throw xia( 62, xspf("Directory already exists: %s", path) );
    if ( access(s, F_OK) == 0 )      
      throw xia( 64, xspf("Directory already exists: %s", s) );
    if ( mkdir(s, 0777) == -1 )
      throw xre( 66, xspf("mkdir %s", s) );
    try {
      if ( uid_flag || gid_flag )
	if ( chown(s, uid, gid) == -1 )
	  throw xre( 68, xspf("chown %d:%d %s", uid, gid, s) );
      if ( mode_flag )
	if ( chmod(s, mode) == -1 )
	  throw xre( 70, xspf("chmod %04o %s", mode, s) );
      if ( rename(s, path) == -1 )
	throw xre( 72, xspf("mv %s %s", s, path) );
    }
    catch( xre e ) {
      if ( rmdir(s) == -1 )
	throw xre( 74, xspf("%s; rmdir %s", e.what(), s) );
      throw e;
    }
  }

  void x_mkdir_sub( char* path )
  {
    char* p = path;
    char* end = path + strlen( path );
    char* q = NULL;
    while (p && ++p < end) {
      p = strchr(p, '/');
      if (p && p < end) {
	*p = '\0';
	//printf("%s\n", path);
	if ( access(path, F_OK) == -1 )      
	  x_mkdir_sub2( path );
	*p = '/';
      }
    }
  }

  void x_mkdir()
  {
    if (argc != 1)
      throw xia( 60, "Invalid number of parameters\n" );

    // cout << "mkdir " << uid << " " << path << "\n";

    char* path = validation( *argv );
    x_mkdir_sub( path );
    x_mkdir_sub2( path );
  }

  void x_mv()
  {
    if (argc != 2)
      throw xia( 90, "Invalid number of parameters\n" );

    char* old_path = validation( *argv++ );
    char* new_path = validation( *argv );
    //cout << "mv " << old_path << " " << new_path << "\n";

    x_mkdir_sub( new_path );

    char s[ PATH_MAX ];
    struct stat64 buf;
    strncpy(s, xspf("%s.%d", old_path, pid), sizeof(s));
    if ( access(old_path, F_OK) == -1 )      
      throw xia( 92, xspf("Directory does not exists: %s", old_path) );
    if ( access(new_path, F_OK) == 0 )
      throw xia( 94, xspf("Directory already exists: %s", new_path) );
    if ( access(s, F_OK) == 0 )      
      throw xia( 96, xspf("Directory already exists: %s", s) );
    if ( stat64( old_path, &buf ) == -1 )
      throw xre( 98, xspf("stat64 %s", old_path) );
    if ( rename(old_path, s) == -1 )
      throw xre( 100, xspf("mv %s %s", old_path, s) );
    try {
      if ( uid_flag || gid_flag )
	if ( chown(s, uid, gid) == -1 )
	  throw xre( 102, xspf("chown %d:%d %s", uid, gid, s) );
      try {
	if ( mode_flag )
	  if ( chmod(s, mode) == -1 )
	    throw xre( 103, xspf("chmod %04o %s", mode, s) );
	if ( uid_flag || gid_flag || mode_flag ) {
	  try {
	    DIR *dirp = opendir(s);
	    if (!dirp)
	      throw xre( 104, xspf("opendir %s", s) );
	    struct dirent *dp;
	    if (chdir(s) == -1)
	      throw xre( 105, xspf("opendir %s", s) );
	    for (;;) {
	      struct stat64 buf2;
	      if ((dp = readdir(dirp)) == NULL)
		break;
	      if (strcmp(dp->d_name, ".") == 0)
		continue;
	      if (strcmp(dp->d_name, "..") == 0)
		continue;
	      if (stat64(dp->d_name, &buf2) == -1)
		throw xre( 106, xspf("stat64 %s", dp->d_name) );
	      if ( uid_flag || gid_flag ) {
		if ( chown(dp->d_name, uid, gid) == -1 )
		  throw xre( 111, xspf("chown %d:%d %s/%s", uid, gid, s, dp->d_name) );
	      }
	      if ( mode_flag ) {
		mode_t m = ( buf2.st_mode & S_IFDIR ) ? mode : mode & 0666;
		if (chmod( dp->d_name, m ) == -1)
		  throw xre( 107, xspf("chmod %04o %s/%s", m, s, dp->d_name) );
	      }
	    }
	  }
	  catch( xre e ) {
	    throw e;
	  }
	}
	try {
	  if ( rename(s, new_path) == -1 )
	    throw xre( 108, xspf("mv %s %s", s, new_path) );
	}
	catch( xre e ) {
	  if ( mode_flag )
	    if ( chmod(s, buf.st_mode) == -1 )
	      throw xre( 109, xspf("%s; chmod %04o %s", e.what(), buf.st_mode, s) );
	  throw e;
	}
      }
      catch( xre e ) {
	if ( chown(s, buf.st_uid, buf.st_gid) == -1 )
	  throw xre( 80, xspf("%s; chown %d:%d %s", e.what(), buf.st_uid, buf.st_gid, s) );
	throw e;
      }
    }
    catch( xre e ) {
      if ( rename(s, old_path) == -1 )
	throw xre( 82, xspf("%s; mv %s %s", e.what(), s, old_path) );
      throw e;
    }
  }

  void x_rmdir()
  {
    if (argc != 1)
      throw xia( 130, "Invalid number of parameters\n" );

    char* path = validation( *argv );
    // cout << "rmdir " << path << "\n";

    throw xia( 139, "rmdir is not implemented." );
  }
};


int main(int argc, char **argv)
{
  umask( 022 );
  try {
    Command c(argc, argv);
    c.dispatch();
  }
  catch ( xia e ) {
    fprintf(stderr, "%s: Version:%s Error %d: %s\n",
	    *argv, VERSION_NUMBER, e.code, e.what());
    exit( e.code );
  }
  catch( xre e ) {
    fprintf(stderr, "%s: Version:%s Error %d: ",
	    *argv, VERSION_NUMBER, e.code);
    if ( errno != 0 )
      perror( e.what() );
    else
      fprintf(stderr, "%s\n", e.what());
    exit( e.code );
  }
  return 0;
}

