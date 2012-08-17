/*
 *  Copyright 2010 Ricoh Company, Ltd.
 *
 *  This file is part of Castoro.
 *
 *  Castoro is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Castoro is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Build Instructions
 *   ruby extconf.rb
 *   make
 *
 * Usage
 *
 *  ruby -d -e 'require "./ruby_tracer"; RubyTracer.open "/dev/tty"; RubyTracer.enable; sleep 1'
 *
 *  With Ruby 1.9.1 - RubyTracer.enable will be required in each thread.
 *  
 *   require './ruby_tracer'
 *   RubyTracer.open "/dev/tty"   # RubyTracer.open "tracer.log"
 *   RubyTracer.enable
 *   t=Thread.new do
 *     RubyTracer.enable
 *     sleep 2
 *   end
 *   sleep 4'
 *   RubyTracer.disable
 *   RubyTracer.close
 *
 *
 *  With Ruby 1.9.1 - Once RubyTracer.enable is done in the main thread, 
 *  it will not be needed in every thread.
 *
 *   require './ruby_tracer'
 *   RubyTracer.open "/dev/tty"   # RubyTracer.open "tracer.log"
 *   RubyTracer.enable
 *   t=Thread.new do
 *     sleep 2
 *   end
 *   sleep 4'
 *   RubyTracer.disable
 *   RubyTracer.close
 *
 */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <ruby.h>

#if defined(linux)
#include <sys/syscall.h>
#define THREAD_ID_T   pid_t
#define GET_THREAD_ID syscall(SYS_gettid)
#else
#include <pthread.h>
#define THREAD_ID_T   pthread_t
#define GET_THREAD_ID pthread_self()
#endif

static struct timeval start_time;
static int fd = -1;

static VALUE rb_open(VALUE obj, VALUE filename)
{
  char *file = RSTRING_PTR(filename);

  /* adding O_SYNC to the 2nd parameter of open() might be useful in a certain situation */
  if ((fd = open(file, (O_WRONLY | O_APPEND | O_CREAT), 0666)) == -1)
    rb_sys_fail(file);
  return Qnil;
}

static VALUE rb_close(VALUE obj)
{
  if (0 <= fd)
    close(fd);
  fd = -1;
  return Qnil;
}

static const char * rb_get_event_name(rb_event_flag_t event)
{
  switch (event) {
  case RUBY_EVENT_LINE:     return "line";
  case RUBY_EVENT_CLASS:    return "class";
  case RUBY_EVENT_END:      return "end";
  case RUBY_EVENT_CALL:     return "call";
  case RUBY_EVENT_RETURN:   return "return";
  case RUBY_EVENT_C_CALL:   return "c-call";
  case RUBY_EVENT_C_RETURN: return "c-return";
  case RUBY_EVENT_RAISE:    return "raise";
  }
  return "unknown";
}

static void ruby_tracer_func(rb_event_flag_t event, VALUE data, VALUE self, ID id, VALUE klass)
{
  struct timeval elapsed_time, current_time;
  pid_t pid = getpid();
  THREAD_ID_T tid = GET_THREAD_ID;
  const char *eventname = rb_get_event_name(event);
  const char *filename = rb_sourcefile();
  int line = rb_sourceline();
  char buffer[PATH_MAX + 60];

  gettimeofday(&current_time, NULL);
  timersub(&current_time, &start_time, &elapsed_time);

  if (0 <= fd) {
    int n = snprintf(buffer, sizeof(buffer), "%ld.%06ld %d %d %-8s %s %d\n", elapsed_time.tv_sec, elapsed_time.tv_usec, 
		     (int)pid, (int)tid, eventname, filename, line);
    write(fd, buffer, n);
  }
}

static VALUE rb_enable(VALUE obj)
{
  rb_remove_event_hook(ruby_tracer_func);
  rb_add_event_hook(ruby_tracer_func, RUBY_EVENT_ALL, Qnil);
  return Qnil;
}

static VALUE rb_disable(VALUE obj)
{
  rb_remove_event_hook(ruby_tracer_func);
  return Qnil;
}

void Init_ruby_tracer(void)
{
  VALUE c = rb_define_class("RubyTracer", rb_cObject);
  rb_define_singleton_method(c, "open", rb_open, 1);
  rb_define_singleton_method(c, "close", rb_close, 0);
  rb_define_singleton_method(c, "enable", rb_enable, 0);
  rb_define_singleton_method(c, "disable", rb_disable, 0);
  gettimeofday(&start_time, NULL);
}
