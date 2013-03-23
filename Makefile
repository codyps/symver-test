all::


CC=gcc
LD=gcc
CFLAGS=-fPIC
LDFLAGS=

%.so : %.map
	$(LD) $(LDFLAGS) -shared -Wl,-soname,$@ -o $@ $(filter-out $*.map,$^) -Wl,--version-script=$*.map

%.o : %.c
	$(CC) $(CFLAGS) -o $@ $^ -c


libtest1.so : test1.o
libtest2.so : test2.o
all:: libtest1.so libtest2.so

test1: main.o
	$(LD) $(LDFLAGS) -o $@ $< -L. -ltest2

all:: test1

clean:
	$(RM) *.o *.so test1


#TARGETS = libtest1.so libtest1.a
#obj-libtest1.so = test1.o
#obj-libtest1.a  = test1.o

#LIBS = test1
#libobj-test1 = test1.o
#include lib-base.mk
