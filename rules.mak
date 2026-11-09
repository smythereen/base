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
#	Rust (optional)
#
#	Units list crate roots explicitly between include ../rules.mak and
#	include ../targets.mak. Nested modules are NOT crate roots; list them
#	in RS_EXTRA_SRCS if copy_to_* should carry them. See ~/RUST.md.
#
#	RS_EXES        optional explicit crate-root .rs executables (far-style:
#	               top-level *.rs with fn main are auto-discovered; see RS_AUTO_EXES)
#	RS_AUTO_EXES   yes (default) | no — auto-pick top-level *.rs containing fn main
#	RS_NO_EXES     extra .rs basenames to exclude from auto-exe discovery
#	RS_STATICLIBS  crate-root .rs files -> libNAME.a  (--crate-type=staticlib, C ABI)
#	RS_RLIBS       crate-root .rs files -> libNAME.rlib (Rust-only)
#	RS_CDYLIBS     crate-root .rs files -> libNAME.so (--crate-type=cdylib)
#	RS_OBJS        crate-root .rs files -> NAME.o (--emit=obj); final link must
#	               still supply the Rust runtime (prefer linking with rustc)
#	RS_EXTRA_SRCS  extra .rs modules for SOURCE/copy lists (also excluded from auto-exe)
#	RS_AUTO_LIB    yes (default) | no — auto-build lib<crate>.rlib from non-main .rs
#	RS_NO_LIB      .rs files excluded from auto unit-library membership
#	RS_EXTERN      other unit/crate names this unit links via --extern (see RUST.md)
#	RSFLAGS        extra rustc flags
#	RS_SYS_LIBS    extra native linker args for Rust links (e.g. -lstdc++)
#	RS_NATIVE_LIBS native libs C/C++ needs when linking a Rust staticlib
#
#	Rust cannot call arbitrary C++ ABI symbols. Export extern "C" wrappers
#	from C/C++ (or use a C API) and declare them in Rust with extern "C".
#	Per-header bindgen (optional): after headers are copied into $(HDR)/cmn,
#	each installed foo.h can produce foo.rs. See ~/RUST.md (RS_BINDGEN).
#	Generated cmn/*.rs files are NOT crate roots.
#

RUSTC ?=	rustc
RSFLAGS ?=
RS_EXES ?=
RS_AUTO_EXES ?=	yes
RS_NO_EXES ?=
RS_STATICLIBS ?=
RS_RLIBS ?=
RS_CDYLIBS ?=
RS_OBJS ?=
RS_EXTRA_SRCS ?=
RS_AUTO_LIB ?=	yes
RS_NO_LIB ?=
RS_EXTERN ?=
RS_UNIT_LIB_ROOT_SH ?=	$(HOME)/bin/rust-unit-lib-root
RS_SYS_LIBS ?=
RS_NATIVE_LIBS ?=	-lgcc_s -lutil -lrt -lpthread -lm -ldl -lc

# auto (default): generate when bindgen is available; otherwise C-only headers succeed
# off: never generate   required: fail if bindgen missing or generation fails
RS_BINDGEN ?=	auto
BINDGEN ?=	$(shell PATH="$(HOME)/.cargo/bin:$$PATH" command -v bindgen 2>/dev/null)
# HAVE_BINDGEN is computed in targets.mak after unit/cmdline BINDGEN overrides.
BINDGEN_FLAGS ?=
# Clang args for bindgen. Include $(HDR) and the unit dir (.) so public
# header fragments (*.def enums/structs) resolve like the C compile, whether
# found via installed ~/cmn or still source-local in the unit.
BINDGEN_CFLAGS ?=	$(INCLUDES) -I. $(RS_BINDGEN_CFLAGS)
RS_BINDGEN_CFLAGS ?=
BINDGEN_HEADER ?=	$(HOME)/bin/bindgen-header

#
#	Common Rules
#

.SUFFIXES:
.SUFFIXES:	.so .a .o .s .i .c .cc .cxx .rs .h .hxx .dat .class .rlib

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
		$(addprefix $(BIN)/,$(SCRIPTS:.sh=))

PRODUCTS :=	$(OBJS:.o=)					\
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
		$(SCRIPTS)		\
		$(H_SCRIPTS)		\
		$(HTML)			\
		$(PICS)

