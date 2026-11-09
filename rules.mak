# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#

.DEFAULT_GOAL := all

#
#	The rules use bash features (echo -e), so make must not use dash
#

SHELL := /bin/bash

#
#	Common Directories
#

BIN =		$(shell echo ~)/bin
HDR =		$(shell echo ~)/cmn
HLP =		$(shell echo ~)/hlp
LIB =		$(shell echo ~)/lib
LOG =		$(shell echo ~)/log
RUN =		$(shell echo ~)/run
TMP =		$(shell echo ~)/tmp

CGI_BIN =	$(shell echo ~)/.cgi-bin
CSS_DIR =	$(shell echo ~)/.styles
HTML_DIR =	$(shell echo ~)/.html
HSH_DIR =	$(shell echo ~)/.html_sh
IMG_DIR =	$(shell echo ~)/.images
WEB_DIR =	$(shell echo ~)/.www

TGT_HOST ?=	localhost

# Hardware/OS variant for the sys unit. Default: supported Linux x86-64 tree.
# Other variants must be set explicitly; the host is NOT auto-detected.
SYS_VARIANT ?=	linux-x86_64

#
#	Common Commands
#

#CC =	gcc32
CD =	@-cd
#CXX =	g++32
ECHO =	@-echo
PROC =	proc
RM =	@-rm -f
MKDIR =	@-mkdir -p -m 0777
LN =	@-ln -s -f

#
#	Common Flags
#
#
#		-I/opt/nms/include
#		-I/usr/java/jdk1.3/include
#		-I/usr/java/jdk1.3/include/linux

COPTS =		-Wall

INCLUDES =	-I$(HDR)

LIBRARIES =	$(LIB)/libmap.a	\
		$(LIB)/libmsg.a	\
		$(LIB)/libfar.a	\
		$(LIB)/libsys.a

#CFLAGS =	-march=native -O2 -finline-functions $(INCLUDES)
#CXXFLAGS =	-march=native -O2 -finline-functions $(INCLUDES)
CFLAGS =	-g -march=native -O0 -fPIC $(INCLUDES) -Wno-implicit-int -Wno-address-of-packed-member -fcommon
CXXFLAGS =	-g -march=native -O0 -fPIC $(INCLUDES) -Wno-write-strings -Wno-address-of-packed-member
#CFLAGS =	-march=native -O2 -fpic -finline-functions $(INCLUDES)
#CXXFLAGS =	-march=native -O2 -fpic -finline-functions $(INCLUDES)
#CFLAGS =	-g -fpic $(INCLUDES)
#CXXFLAGS =	-mtune=native -g -fpic $(INCLUDES)

#CFLAGS =	-g -m32 -fpic $(INCLUDES)
#CXXFLAGS =	-g -m32 -fpic $(INCLUDES) -Wno-deprecated
#CXXFLAGS =	-g -fpic $(INCLUDES) -I/usr/include/g++-3

NO_UNIT_SO	:= yes

#LDFLAGS =	-L$(LIB)\
#		-L/lib\
#		-L/usr/lib\
#		-L/usr/local/lib

#LDFLAGS =	-L$(LIB)\
#		-L/lib64\
#		-L/usr/lib64\
#		-L/usr/local/lib64

LDFLAGS =	-L$(LIB)


#
#	Rust (optional, see RUST.md).  Units may set RS_EXTERN (other units' rlibs
#	to link) and RSFLAGS.  Per-header bindings need bindgen; RS_BINDGEN=required
#	makes a missing bindgen an error, BINDGEN= turns bindings off.
#

RUSTC ?=	rustc
RSFLAGS =	-g --edition=2021
RS_EXTERN =
RS_BINDGEN ?=	auto
BINDGEN ?=	$(shell PATH="$(HOME)/.cargo/bin:$$PATH" command -v bindgen 2>/dev/null)
BINDGEN_FLAGS =
RS_BINDGEN_CFLAGS =

#
#	Common Rules
#

.SUFFIXES:
.SUFFIXES:	.so .a .o .s .i .c .cc .cxx .rs .h .hxx .dat .class

.cxx.a:
	$(CXX) -o $* -c -MD $(CXXFLAGS) $< ;
	@cat *.d > .depend ;
	ar -rUs $@ $*.o

.cc.a:
	$(CXX) -o $*.o -c -MD $(CXXFLAGS) $< ;
	@cat *.d > .depend ;
	ar -rUs $@ $*.o

.c.a:
	$(CC) -o $*.o -c -MD $(CFLAGS) $< ;
	@cat *.d > .depend ;
	ar -rUs $@ $*.o

.cxx.o:
	$(CXX) -o $*.o -c -MD $(CXXFLAGS) $< ;
	@cat *.d > .depend ;

.cc.o:
	$(CXX) -o $*.o -c -MD $(CXXFLAGS) $< ;
	@cat *.d > .depend ;

.c.o:
	$(CC) -o $*.o -c -MD $(CFLAGS) $< ;
	@cat *.d > .depend ;

.c.s:
	$(CC) -S -MD $(CFLAGS) $< ;

.c.i:
	$(CC) -P $(CFLAGS) $< ;

.o:
	$(CC) -o $* -MD $(CFLAGS) $< $(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES) ;
	@mv $@.d $@.tmp ; echo -e "$@ \c" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;
	@-test -f $(BIN)/$@ && mkdir -p $(BIN)/.old && mv -f $(BIN)/$@ $(BIN)/$@.old > /dev/null 2>&1 ; exit 0 ;
	cp -p $@ $(BIN) ;

.c:
	$(CC) -o $* -MD $(CFLAGS) $< $(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES) ;
	@mv $@.d $@.tmp ; echo -e "$@ \c" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;
	@-test -f $(BIN)/$@ && mkdir -p $(BIN)/.old && mv -f $(BIN)/$@ $(BIN)/$@.old > /dev/null 2>&1 ; exit 0 ;
	cp -p $@ $(BIN) ;

.cc:
	$(CXX) -o $* -MD $(CXXFLAGS) $< $(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES) ;
	@mv $@.d $@.tmp ; echo -e "$@ \c" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;
	@-test -f $(BIN)/$@ && mkdir -p $(BIN)/.old && mv -f $(BIN)/$@ $(BIN)/$@.old > /dev/null 2>&1 ; exit 0 ;
	cp -p $@ $(BIN) ;

.cxx:
	$(CXX) -o $* -MD $(CXXFLAGS) $< $(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES) ;
	@mv $@.d $@.tmp ; echo -e "$@ \c" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;
	@-test -f $(BIN)/$@ && mkdir -p $(BIN)/.old && mv -f $(BIN)/$@ $(BIN)/$@.old > /dev/null 2>&1 ; exit 0 ;
	cp -p $@ $(BIN) ;

#
#	Common UNIT Initialization
#

UNIT :=		$(shell basename `pwd` | cut -d. -f1 )

HDRS :=		$(wildcard *.h)

C_SRCS :=	$(shell grep -l "[ 	]main(.*)\|^main(.*)" *.c 2>/dev/null )
CC_SRCS :=	$(shell grep -l "[ 	]main(.*)\|^main(.*)" *.cc 2>/dev/null )
OBJS :=		$(C_SRCS:.c=.o) $(CC_SRCS:.cc=.o)

L_C_SRCS :=	$(shell grep -L "[ 	]main(.*)\|^main(.*)" *.c 2>/dev/null )
L_CC_SRCS :=	$(shell grep -L "[ 	]main(.*)\|^main(.*)" *.cc 2>/dev/null )
L_OBJS :=	$(L_C_SRCS:.c=.o) $(L_CC_SRCS:.cc=.o)

# Rust: top-level *.rs with "fn main" are programs, the others form the unit
# crate lib<unit>.rlib (root lib.rs, else a generated .lib.rs).
RS_SRCS :=	$(shell grep -l "fn main" *.rs 2>/dev/null )
L_RS_SRCS :=	$(shell grep -L "fn main" *.rs 2>/dev/null )
RS_EXES :=	$(RS_SRCS:.rs=)
RS_CRATE :=	$(subst -,_,$(UNIT))
RS_LIBRARY :=	$(if $(L_RS_SRCS),$(LIB)/lib$(RS_CRATE).rlib)

ifneq	("$(L_CC_SRCS)","")

LCC := $(CXX)

else

LCC := $(CC)

endif

ifneq	("$(L_OBJS)"," ")

LIBRARY :=	$(LIB)/lib$(UNIT).a

ifneq   ("$(NO_UNIT_SO)","yes")

S_LIBRARY :=	$(LIB)/lib$(UNIT).so

else

S_LIBRARY :=

endif

.PRECIOUS:	$(LIBRARY)

else

LIBRARY :=
S_LIBRARY :=

endif

HTML :=		$(wildcard *.html)
PICS :=		$(wildcard *.bmp *.gif *.jpg *.ico)
STYLES :=	$(wildcard *.css *.js)

SCRIPTS :=	$(wildcard *.sh)
H_SCRIPTS :=	$(wildcard *.hsh)

EXECUTABLES :=	$(addprefix $(BIN)/,$(OBJS:.o=))	\
		$(addprefix $(BIN)/,$(RS_EXES))		\
		$(addprefix $(BIN)/,$(SCRIPTS:.sh=))

PRODUCTS :=	$(OBJS:.o=) $(RS_EXES)				\
		$(EXECUTABLES)					\
		$(addprefix $(CSS_DIR)/,$(STYLES))		\
		$(addprefix $(IMG_DIR)/,$(PICS))		\
		$(addprefix $(HSH_DIR)/,$(H_SCRIPTS:.hsh=.sh))	\
		$(addprefix $(HTML_DIR)/,$(HTML))

#
#	Common Source Files
#

SOURCE :=	$(wildcard ?akefile)	\
		$(HDRS)			\
		$(C_SRCS)		\
		$(CC_SRCS)		\
		$(L_C_SRCS)		\
		$(L_CC_SRCS)		\
		$(RS_SRCS)		\
		$(L_RS_SRCS)		\
		$(SCRIPTS)		\
		$(H_SCRIPTS)		\
		$(HTML)			\
		$(PICS)

#
#	Rust bindings: every installed $(HDR)/foo.h can give $(HDR)/foo.rs (the
#	list is RS_BINDINGS in targets.mak).  A foo.rs without the foo.rs.bindgen
#	marker is handwritten and never overwritten.  Nothing here expands a unit
#	list, so the rule stays with the other compile rules.
#

$(HDR)/%.rs :	$(HDR)/%.h
	@if [ -f $@ ] && [ ! -f $@.bindgen ]; then echo "error: $@ is handwritten (no $@.bindgen), not overwritten" >&2; exit 1; fi
	$(BINDGEN) $< -o $@.tmp --depfile $@.d $(BINDGEN_FLAGS) -- $(INCLUDES) -I. $(RS_BINDGEN_CFLAGS) \
		&& sed -i 's|$@.tmp|$@|' $@.d && mv -f $@.tmp $@ && touch $@.bindgen \
		|| { rm -f $@.tmp ; echo "error: bindgen failed for $<" >&2 ; test "$(RS_BINDGEN)" != required ; }

-include $(wildcard $(HDR)/*.rs.d)
