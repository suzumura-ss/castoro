RUBYLIB = /usr/local/lib
RUBYINC = /usr/local/include/ruby

CXX = g++

TARGET = main
OUTFLAG = -o
CFLAGS = -fPIC -g -Wall -DRUBY_VERSION=\"1.9\"
DEFS = -D_FILE_OFFSET_BITS=64
INCFLAGS = -I. -I$(RUBYINC)/i686-linux -I$(RUBYINC)/ruby/backward -I$(RUBYINC)
LIBPATH = -L. -L$(RUBYLIB) -Wl,-R$(RUBYLIB) -Wl,-R -Wl,$(RUBYLIB)
LDFLAGS = -lstdc++ -lruby -lpthread -lrt -ldl -lcrypt -lm -lc
OBJS = ../mapping.o ../page.o ../cache.o ../database.o


$(TARGET):
	$(CXX) $(OUTFLAG)$@ main.cxx $(OBJS) $(CFLAGS) $(DEFS) $(INCFLAGS) $(LIBPATH) $(LDFLAGS)

clean:
	$(RM) $(TARGET)

