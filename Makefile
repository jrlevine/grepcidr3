#
# Makefile for grepcidr 3.x
#

# Set to where you'd like grepcidr installed
INSTALL=install
INSTALLDIR=/usr/local
INSTALLDIR_BIN=${INSTALLDIR}/bin
INSTALLDIR_MAN=${INSTALLDIR}/man/man1
#INSTALLDIR_MAN=${INSTALLDIR}/share/man/man1

# Set to your favorite C compiler and flags
# with GCC, -O3 makes a lot of difference
# -DDEBUG=1 prints out hex versions of IPs and matches

CFLAGS=-O3 -Wall -pedantic
#CFLAGS=-g -Wall -pedantic -DDEBUG=1
TFILES=COPYING LICENSE ChangeLog Makefile README grepcidr.1 grepcidr.c
DIR := $(shell basename ${PWD})

# End of settable values

all:	grepcidr

grepcidr:	grepcidr.c
	$(CC) $(CFLAGS) $(RPM_OPT_FLAGS) $(RPM_LD_FLAGS) -o grepcidr grepcidr.c

install:	all  grepcidr.1
	$(INSTALL) grepcidr $(DESTDIR)$(INSTALLDIR_BIN)
	$(INSTALL) -m 0644 grepcidr.1 $(DESTDIR)$(INSTALLDIR_MAN)

clean:
	rm -f grepcidr

tar:
	cd ..; tar cvjf ${DIR}.tjz $(patsubst %,${DIR}/%,${TFILES})
