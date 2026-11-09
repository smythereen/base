# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#

#
#	Follow-Up Variables
#

LDEPS = $(patsubst %.a,  %.a \0134\012,$(patsubst -l%,$(LIB)/lib%.a,$(LIBRARIES)))

#
#	Common Targets
#

.PHONY:	all
# Sequential phases via sub-makes so header completes before bindings, etc.
# (GNU make forbids mixing : and :: on the same target name.)
all::	.depend source
	@$(MAKE) header
	@$(MAKE) bindings
	@$(MAKE) library
	@$(MAKE) product

.PHONY:	source
source::		$(SRC_ADD)
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

.PHONY:	header
header::		$(CHDRS)
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

.PHONY:	library
library::	$(LIBRARY) $(S_LIBRARY)
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

.PHONY:	product
product::	$(PRODUCTS)
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

.depend:
	-cat *.d > .depend 2> /dev/null || touch .depend ;

#
#	Unit Targets
#

ifneq	("$(L_OBJS)"," ")

$(LIBRARY):	$(L_OBJS)
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && cp -fp $@ $(LIB)/.old || exit 0 ;
	ar -rUs $@ $? ;

ifneq   ("$(NO_UNIT_SO)","yes")

$(S_LIBRARY):	$(L_OBJS)
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && mv -f $@ $(LIB)/.old || exit 0 ;
	$(LCC) -MD -o $@ -shared -Wl,-soname,lib$(UNIT).so $(L_OBJS) $(LDFLAGS) ;

endif

endif

$(HDR)/%.h :	%.h
	@mkdir -p -m 775 $(HDR) ;
	cp -fp	$? $@

#
#	Per-header Rust bindings (one $(HDR)/foo.rs per installed $(HDR)/foo.h)
#
#	RS_BINDGEN=auto|off|required. Generated files use a *.rs.bindgen ownership
#	sidecar; handwritten cmn/*.rs without that sidecar are never overwritten.
#	Bindings are NOT crate roots. See ~/RUST.md.
#

HAVE_BINDGEN := $(shell test -n "$(BINDGEN)" && command -v "$(BINDGEN)" >/dev/null 2>&1 && echo yes)

ifeq ($(RS_BINDGEN),off)
RS_BINDINGS :=
RS_BINDGEN_HEADER_CHECK :=
else ifeq ($(HAVE_BINDGEN),yes)
# Only C/C++ headers are bindgen roots. *.def in CHDRS are X-macro/type
# fragments included by those headers — install them, do not bindgen them.
RS_BINDINGS := $(patsubst %.h,%.rs,$(filter %.h,$(CHDRS)))
RS_BINDGEN_HEADER_CHECK :=
else ifeq ($(RS_BINDGEN),required)
RS_BINDINGS :=
RS_BINDGEN_HEADER_CHECK := echo "error: bindgen not found (RS_BINDGEN=required); install bindgen-cli (cargo install bindgen-cli) or set BINDGEN=" >&2; exit 1
else
# auto without bindgen: C-only headers succeed
RS_BINDINGS :=
RS_BINDGEN_HEADER_CHECK :=
endif

# Shared options stamp: mtime updates only when bindgen option text changes.
RS_BINDGEN_OPTTEXT := BINDGEN=$(BINDGEN); FLAGS=$(BINDGEN_FLAGS); CFLAGS=$(BINDGEN_CFLAGS); MODE=$(RS_BINDGEN)

.PHONY: $(HDR)/.bindgen.options.check
$(HDR)/.bindgen.options: $(HDR)/.bindgen.options.check
	@mkdir -p -m 775 $(HDR)
	@optnew=$@.new.$$$$; printf '%s\n' '$(RS_BINDGEN_OPTTEXT)' > $$optnew; \
	if cmp -s $@ $$optnew 2>/dev/null; then rm -f $$optnew; else mv -f $$optnew $@; fi

# Installed *.def fragments from this unit (not bindgen roots).
RS_DEFS := $(filter %.def,$(CHDRS))

ifneq ($(RS_BINDINGS),)
# Real deps on sibling installed .def so enum/struct fragment edits rebuild bindings.
$(RS_BINDINGS): $(HDR)/%.rs: $(HDR)/%.h $(HDR)/.bindgen.options $(RS_DEFS)
	@mkdir -p -m 775 $(HDR)
	@RS_BINDGEN='$(RS_BINDGEN)' BINDGEN='$(BINDGEN)' BINDGEN_FLAGS='$(BINDGEN_FLAGS)' \
		$(BINDGEN_HEADER) $< $@ $@.d $(HDR)/.bindgen.options -- $(BINDGEN_CFLAGS)
endif

# Bindings phase (separate from header). Prereqs expand after RS_BINDINGS is set.
.PHONY:	bindings
bindings::	$(HDR)/.bindgen.options $(CHDRS) $(RS_BINDINGS)
	@$(RS_BINDGEN_HEADER_CHECK)
	@fail=0; \
	for f in $(RS_BINDINGS); do \
		if [ -n "$$f" ] && [ ! -f "$$f" ] && [ "$(RS_BINDGEN)" != "off" ] && [ "$(HAVE_BINDGEN)" = "yes" ]; then \
			echo "warning: bindings: missing $$f (bindgen skipped/failed; RS_BINDGEN=$(RS_BINDGEN))" >&2; \
			fail=1; \
		fi; \
	done; \
	if [ "$(RS_BINDGEN)" = "required" ] && [ $$fail -ne 0 ]; then exit 1; fi
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

# Transitive header deps recorded by bindgen --depfile (shared across units).
-include $(wildcard $(HDR)/*.rs.d)


$(HDR)/%.dat :	%.dat
	@mkdir -p -m 775 $(HDR) ;
	cp -fp	$? $@

$(HDR)/%.def :	%.def
	@mkdir -p -m 775 $(HDR) ;
	cp -fp	$? $@

$(BIN)/% :	%.sh
	@-test -f $@ && mkdir -p -m 775 $(BIN)/.old && mv -f $@ $(BIN)/.old || exit 0 ;
	cp -fp	$? $@ ;
	chmod	775 $@ ;

$(BIN)/% :	%
	@-mkdir -p -m 775 $(BIN)/.old ;
	@test ! -f $@ || mv -f $@ $(BIN)/.old ;
	cp -fp	$? $@ ;

$(CSS_DIR)/%.css :	%.css
	@-mkdir -p -m 755 $(CSS_DIR) && test -f $@ && mkdir -p $(CSS_DIR)/.old && mv -f $@ $(CSS_DIR)/.old || exit 0 ;
	cp -fp	$? $@ ;
	chmod	644 $@ ;

$(CSS_DIR)/%.js :	%.js
	@-mkdir -p -m 755 $(CSS_DIR) && test -f $@ && mkdir -p $(CSS_DIR)/.old && mv -f $@ $(CSS_DIR)/.old || exit 0 ;
	cp -fp	$? $@ ;
	chmod	644 $@ ;

$(HTML_DIR)/%.html :	%.html
	@-mkdir -p -m 775 $(HTML_DIR) && test -f $@ && mkdir -p $(HTML_DIR)/.old && mv -f $@ $(HTML_DIR)/.old || exit 0 ;
	cp -fp	$? $@ ;
	chmod	664 $@ ;

$(HSH_DIR)/%.sh :	%.hsh
	@-mkdir -p -m 775 $(HSH_DIR) && test -f $@ && mkdir -p $(HSH_DIR)/.old && mv -f $@ $(HSH_DIR)/.old || exit 0 ;
	cp -fp	$< $@ ;
	chmod	770 $@ ;

$(IMG_DIR)/% :	%
	cp -fp	$< $@ ;
	chmod	644 $@ ;

ifneq	("$(L_OBJS)"," ")

ifneq   ("$(NO_UNIT_SO)","yes")

% :	%.c $(LIBRARY)
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) -l$(UNIT) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc $(LIBRARY)
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) -l$(UNIT) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

else

% :	%.c $(LIBRARY)
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) $(LIBRARY) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc $(LIBRARY)
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) $(LIBRARY) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

endif

else

% :	%.c
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   " | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) $(LIBRARIES) $(SYS_LIBS);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   " | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

endif

$(BIN)/% :	%
	@-mkdir -p -m 775 $(BIN)/.old ;
	@test ! -f $@ || mv -f $@ $(BIN)/.old ;
	cp -fp	$< $@ ;

#
#	Rust support
#
#	Computed here so unit makefiles can set RS_* after include ../rules.mak
#	and before this file. Empty RS_* lists produce no targets.
#
#	Far-style executables: when RS_AUTO_EXES=yes (default), every top-level
#	*.rs whose text matches a simple fixed-string `fn main` heuristic
#	becomes an executable crate root (not a Rust parse — documented heuristic,
#	same idea as the C main( grep). Excludes mod.rs/lib.rs/build.rs and any
#	file listed in RS_STATICLIBS/RS_RLIBS/RS_CDYLIBS/RS_OBJS/RS_EXTRA_SRCS/
#	RS_NO_EXES. Sibling modules without main are left for rustc `mod` deps.
#	~/cmn/*.rs bindgen outputs are outside the unit dir, so never auto-roots.
#

ifeq ($(RS_AUTO_EXES),yes)
RS_EXES_AUTO := $(shell grep -lF 'fn main' *.rs 2>/dev/null)
RS_EXES_AUTO := $(filter-out mod.rs lib.rs build.rs,$(RS_EXES_AUTO))
RS_EXES_AUTO := $(filter-out $(RS_STATICLIBS) $(RS_RLIBS) $(RS_CDYLIBS) $(RS_OBJS) $(RS_EXTRA_SRCS) $(RS_NO_EXES),$(RS_EXES_AUTO))
RS_EXES := $(sort $(RS_EXES) $(RS_EXES_AUTO))
endif

RS_EXE_NAMES :=		$(strip $(basename $(notdir $(RS_EXES))))

# Clear error on same-named C and Rust executables in one unit.
RS_C_EXE_NAMES := $(basename $(notdir $(C_SRCS))) $(basename $(notdir $(CC_SRCS)))
RS_NAME_COLLISION := $(filter $(RS_C_EXE_NAMES),$(RS_EXE_NAMES))
ifneq ($(strip $(RS_NAME_COLLISION)),)
$(error Rust/C executable name collision in unit $(UNIT): $(RS_NAME_COLLISION) [both .c/.cc and .rs]. Rename one side or set RS_NO_EXES / RS_AUTO_EXES=no.)
endif

#
#	Automatic unit Rust library (lib<crate>.rlib) — analogous to C sources
#	without main() going into lib$(UNIT).a. One rlib crate per unit by default.
#	Does NOT produce staticlib / does not collide with native lib$(UNIT).a.
#	Handwritten lib.rs is authoritative (never overwritten). Otherwise a
#	generated .rs_unit_lib.rs pub-mod root is used. Nested modules already
#	pulled via `mod name` are omitted from that root (grep heuristic).
#

RS_CRATE_NAME := $(shell printf '%s' '$(UNIT)' | sed -e 's/-/_/g' -e 's/[^A-Za-z0-9_]/_/g' -e '/^[0-9]/s/^/u_/')

ifeq ($(RS_AUTO_LIB),yes)
# Non-executable top-level *.rs candidates (complement of fn-main heuristic).
RS_ALL_RS := $(wildcard *.rs)
RS_LIB_CANDIDATES := $(filter-out $(RS_EXES) mod.rs lib.rs build.rs .rs_unit_lib.rs,$(RS_ALL_RS))
RS_LIB_CANDIDATES := $(filter-out $(RS_STATICLIBS) $(RS_RLIBS) $(RS_CDYLIBS) $(RS_OBJS) $(RS_NO_LIB),$(RS_LIB_CANDIDATES))
# If nothing to put in the unit lib and no handwritten lib.rs, skip.
ifneq ($(strip $(RS_LIB_CANDIDATES)$(wildcard lib.rs)),)
RS_UNIT_RLIB := lib$(RS_CRATE_NAME).rlib
RS_UNIT_RLIB_INST := $(LIB)/$(RS_UNIT_RLIB)
RS_UNIT_LIB_STAMP := .rs_unit_lib.modules
ifeq ($(wildcard lib.rs),)
RS_UNIT_LIB_ROOT := .rs_unit_lib.rs
else
RS_UNIT_LIB_ROOT := lib.rs
endif
else
RS_UNIT_RLIB :=
RS_UNIT_RLIB_INST :=
RS_UNIT_LIB_ROOT :=
RS_UNIT_LIB_STAMP :=
endif
else
RS_UNIT_RLIB :=
RS_UNIT_RLIB_INST :=
RS_UNIT_LIB_ROOT :=
RS_UNIT_LIB_STAMP :=
RS_LIB_CANDIDATES :=
endif

# Cross-unit and same-unit --extern args (crate name sanitized like RS_CRATE_NAME).
RS_EXTERN_ARGS := $(foreach u,$(RS_EXTERN),--extern $(shell printf '%s' '$(u)' | sed -e 's/-/_/g' -e 's/[^A-Za-z0-9_]/_/g' -e '/^[0-9]/s/^/u_/')=$(LIB)/lib$(shell printf '%s' '$(u)' | sed -e 's/-/_/g' -e 's/[^A-Za-z0-9_]/_/g' -e '/^[0-9]/s/^/u_/').rlib)
ifneq ($(RS_UNIT_RLIB),)
RS_UNIT_EXTERN_ARGS := --extern $(RS_CRATE_NAME)=$(RS_UNIT_RLIB_INST)
else
RS_UNIT_EXTERN_ARGS :=
endif

RS_STATIC_NAMES :=	$(strip $(basename $(notdir $(RS_STATICLIBS))))
RS_RLIB_NAMES :=	$(strip $(basename $(notdir $(RS_RLIBS))))
RS_CDY_NAMES :=		$(strip $(basename $(notdir $(RS_CDYLIBS))))
RS_OBJ_NAMES :=		$(strip $(basename $(notdir $(RS_OBJS))))

RS_STATIC_FILES :=	$(addprefix lib,$(addsuffix .a,$(RS_STATIC_NAMES)))
RS_RLIB_FILES :=	$(addprefix lib,$(addsuffix .rlib,$(RS_RLIB_NAMES)))
RS_CDY_FILES :=		$(addprefix lib,$(addsuffix .so,$(RS_CDY_NAMES)))
RS_OBJ_FILES :=		$(addsuffix .o,$(RS_OBJ_NAMES))

RS_LINK_ARGS := $(foreach x,$(LDFLAGS) $(LIBRARIES) $(SYS_LIBS) $(RS_SYS_LIBS),-C link-arg=$(x))

SOURCE += $(RS_EXES) $(RS_STATICLIBS) $(RS_RLIBS) $(RS_CDYLIBS) $(RS_OBJS) $(RS_EXTRA_SRCS) $(RS_LIB_CANDIDATES)

PRODUCTS += \
	$(RS_EXE_NAMES) \
	$(addprefix $(BIN)/,$(RS_EXE_NAMES)) \
	$(RS_STATIC_FILES) \
	$(addprefix $(LIB)/,$(RS_STATIC_FILES)) \
	$(RS_RLIB_FILES) \
	$(addprefix $(LIB)/,$(RS_RLIB_FILES)) \
	$(RS_UNIT_RLIB) \
	$(RS_UNIT_RLIB_INST) \
	$(RS_CDY_FILES) \
	$(addprefix $(LIB)/,$(RS_CDY_FILES)) \
	$(RS_OBJ_FILES)

EXECUTABLES += $(addprefix $(BIN)/,$(RS_EXE_NAMES))

# Inline rustc presence check (avoid a .PHONY prereq, which upsets rebuild decisions).
RS_RUSTC_CHECK = @command -v $(RUSTC) >/dev/null 2>&1 || { echo "error: $(RUSTC) not found; install rustc or unset RS_EXES/RS_* lists" >&2; exit 1; }

ifneq ($(RS_EXE_NAMES),)
$(RS_EXE_NAMES): %: %.rs $(RS_UNIT_RLIB_INST)
	$(RS_RUSTC_CHECK)
	$(RUSTC) $(RSFLAGS) --emit=link -o $@ --emit=dep-info=$@.d $< $(RS_LINK_ARGS) $(RS_UNIT_EXTERN_ARGS) $(RS_EXTERN_ARGS)
	@cat *.d > .depend 2>/dev/null || true
endif

ifneq ($(RS_STATIC_FILES),)
$(RS_STATIC_FILES): lib%.a: %.rs
	$(RS_RUSTC_CHECK)
	$(RUSTC) $(RSFLAGS) --crate-type=staticlib --emit=link --emit=dep-info=$*.d $<
	@cat *.d > .depend 2>/dev/null || true

$(LIB)/lib%.a: lib%.a
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && cp -fp $@ $(LIB)/.old || exit 0
	cp -fp $< $@
endif

# Auto unit library crate
ifneq ($(RS_UNIT_RLIB),)
# Candidate-set stamp: mtime changes only when the auto-lib membership list
# changes (add/remove). Nested content rebuilds come from rustc dep-info.
.PHONY: $(RS_UNIT_LIB_STAMP).check
$(RS_UNIT_LIB_STAMP): $(RS_UNIT_LIB_STAMP).check
	@printf '%s\n' $(sort $(RS_LIB_CANDIDATES)) > $@.new.$$$$; \
	if cmp -s $@ $@.new.$$$$ 2>/dev/null; then rm -f $@.new.$$$$; else mv -f $@.new.$$$$ $@; fi

$(RS_UNIT_RLIB): $(RS_UNIT_LIB_STAMP) $(RS_LIB_CANDIDATES) $(wildcard lib.rs)
	$(RS_RUSTC_CHECK)
	@$(RS_UNIT_LIB_ROOT_SH) $(RS_UNIT_LIB_ROOT) .rs_unit_lib.rootstamp $(RS_LIB_CANDIDATES)
	$(RUSTC) $(RSFLAGS) --crate-type=rlib --crate-name $(RS_CRATE_NAME) --emit=link --emit=dep-info=$(RS_UNIT_RLIB).d -o $(RS_UNIT_RLIB) $(RS_UNIT_LIB_ROOT) $(RS_EXTERN_ARGS)
	@cat *.d > .depend 2>/dev/null || true

$(RS_UNIT_RLIB_INST): $(RS_UNIT_RLIB)
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && cp -fp $@ $(LIB)/.old || exit 0
	cp -fp $< $@
endif

ifneq ($(RS_RLIB_FILES),)
$(RS_RLIB_FILES): lib%.rlib: %.rs
	$(RS_RUSTC_CHECK)
	$(RUSTC) $(RSFLAGS) --crate-type=rlib --emit=link --emit=dep-info=$*.d $<
	@cat *.d > .depend 2>/dev/null || true

$(LIB)/lib%.rlib: lib%.rlib
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && cp -fp $@ $(LIB)/.old || exit 0
	cp -fp $< $@
endif

ifneq ($(RS_CDY_FILES),)
$(RS_CDY_FILES): lib%.so: %.rs
	$(RS_RUSTC_CHECK)
	$(RUSTC) $(RSFLAGS) --crate-type=cdylib --emit=link --emit=dep-info=$*.d $<
	@cat *.d > .depend 2>/dev/null || true

$(LIB)/lib%.so: lib%.so
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && mv -f $@ $(LIB)/.old || exit 0
	cp -fp $< $@
endif

ifneq ($(RS_OBJ_FILES),)
$(RS_OBJ_FILES): %.o: %.rs
	$(RS_RUSTC_CHECK)
	$(RUSTC) $(RSFLAGS) --crate-type=lib --emit=obj --emit=dep-info=$*.d -o $@ $<
	@cat *.d > .depend 2>/dev/null || true
endif

ifneq ($(strip $(RS_STATIC_FILES) $(RS_RLIB_FILES) $(RS_CDY_FILES) $(RS_UNIT_RLIB_INST)),)
.PHONY:	library
library::	$(addprefix $(LIB)/,$(RS_STATIC_FILES)) \
		$(addprefix $(LIB)/,$(RS_RLIB_FILES)) \
		$(RS_UNIT_RLIB_INST) \
		$(addprefix $(LIB)/,$(RS_CDY_FILES))
endif


.PHONY:	clean cleanup
clean cleanup::
# the scripts keep their mode: the install rule sets the mode of the copy in bin, and a source
# script that loses its execute bit makes git report the unit as modified (and breaks repo/repo.sh)
	@-chmod	664 $(filter-out $(SCRIPTS),$(SOURCE))	;
	@rm -f	*.o		;
	@rm -f	*.a		;
	@rm -f	*.d		;
	@rm -f	*.tmp		;
	@rm -f	*.rlib		;
	@rm -f	core.*		;
	@rm -f	$(OBJS:.o=)	;
	@rm -f	$(RS_EXE_NAMES)	;
	@rm -f	$(RS_STATIC_FILES)	;
	@rm -f	$(RS_RLIB_FILES)	;
	@rm -f	$(RS_UNIT_RLIB)	;
	@rm -f	$(RS_UNIT_LIB_STAMP)	;
	@rm -f	.rs_unit_lib.rootstamp	;
	@rm -f	.rs_unit_lib.rs	;
	@rm -f	$(RS_CDY_FILES)	;
	@rm -f	$(SRC_ADD)	;
	@rm -f	$(CHDRS)	;
	@rm -f	$(RS_BINDINGS)	;
	@rm -f	$(addsuffix .d,$(RS_BINDINGS))	;
	@rm -f	$(addsuffix .bindgen,$(RS_BINDINGS))	;
	@rm -f	$(addsuffix .bindgen.opts,$(RS_BINDINGS))	;
	@-mkdir -p -m 770 $(BIN)/.old && mv -f $(EXECUTABLES)	$(BIN)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(LIBRARY)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(LIBRARY2)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(S_LIBRARY)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(addprefix $(LIB)/,$(RS_STATIC_FILES)) $(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(addprefix $(LIB)/,$(RS_RLIB_FILES)) $(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(RS_UNIT_RLIB_INST) $(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(addprefix $(LIB)/,$(RS_CDY_FILES)) $(LIB)/.old 2>/dev/null ; exit 0 ;
	@echo -e "\c" > .depend ;
	$(ECHO)	"	Unit	$(UNIT): $@ complete!" ;

.PHONY:		dist_clean
dist_clean::	cleanup
	@rm -f	$(PRODUCTS)	;

#
#	Dummy (no-op) target: the master makefile runs source_list in every unit
#

.PHONY:	source_list
source_list::
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

newunit:
	@if [ -x ~/bin/proj ]; then \
		echo "	using new project tools for newunit (contrib as new unit) from main ~/bin"; \
		~/bin/proj contribute --new-unit $(UNIT) || ~/bin/unit-contribute --new-unit || true; \
	elif command -v proj >/dev/null 2>&1; then \
		proj contribute --new-unit $(UNIT) || true; \
	fi
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

populate:
	@if [ -x ~/bin/proj ]; then \
		echo "	using new project tools for populate from main ~/bin"; \
		~/bin/proj sync --units || ~/bin/project-sync --units || true; \
	elif command -v proj >/dev/null 2>&1; then \
		proj sync --units || true; \
	fi
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

update:
	@if [ -x ~/bin/proj ]; then \
		echo "	using new project tools for update (contrib) from main ~/bin"; \
		~/bin/proj contribute $(UNIT) || ~/bin/unit-contribute || true; \
	elif command -v proj >/dev/null 2>&1; then \
		proj contribute $(UNIT) || true; \
	fi
	$(ECHO)	"	Unit	$(UNIT): $@ complete!" ;

copy_to_dev2:
	@-ssh dev2@$(TGT_HOST) mkdir -p $(UNIT) ;
	@scp -p $(SOURCE) dev2@$(TGT_HOST):$(UNIT)/. ;

copy_to_dev3:
	@-ssh dev3@$(TGT_HOST) rm -rf $(UNIT) ;
	@-ssh dev3@$(TGT_HOST) mkdir -p $(UNIT) ;
	@scp -p $(SOURCE) dev3@$(TGT_HOST):$(UNIT)/. ;

copy_to_peer:
	-for P in $(PEERS); do ssh $(LOGNAME)@$${P} mkdir -p $${PWD}/$(UNIT) || exit 0 ; scp -p $(SOURCE) $(LOGNAME)@$${P}:`pwd`/ ; done

#	-for P in $(PEERS); do ping -q -c 1 -W 1 $${P} >/dev/null 2>&1 || continue ; scp -p $(SOURCE) $(LOGNAME)@$${P}:`pwd`/ ; done

source_rpm:
	@-for F in $(SOURCE); do echo "`pwd`/$${F}"  ; done >> ../rpm/source.list ;

#.SILENT:
