# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#

#
#	Follow-Up Variables
#

LDEPS = $(patsubst %.a,  %.a \0134\012,$(patsubst -l%,$(LIB)/lib%.a,$(LIBRARIES)))

RS_LDEPS = $(foreach u,$(subst -,_,$(RS_EXTERN)),$(LIB)/lib$(u).rlib)

RS_STD = $(if $(filter $(patsubst %.rs,%.o,$(wildcard *.rs)),$(L_OBJS) $(OBJS) $(LIBRARIES)),$(RS_STD_LIBS))

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
library::	$(LIBRARY) $(S_LIBRARY) $(RS_LIBRARY)
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

ifneq	("$(L_RS_SRCS)","")

$(RS_LIBRARY):	$(L_RS_SRCS)
	@-mkdir -p -m 775 $(LIB) && test -f $@ && mkdir -p $(LIB)/.old && cp -fp $@ $(LIB)/.old || exit 0 ;
	@for f in $(L_RS_SRCS) ; do echo "#[path = \"$$f\"] pub mod `basename $$f .rs | tr -c 'A-Za-z0-9_\n' _`;" ; done > .lib.rs ;
	$(RUSTC) -o $@ --crate-type=rlib --crate-name $(RS_CRATE) --emit=link,dep-info=lib$(RS_CRATE).d $(RSFLAGS) .lib.rs -L$(LIB) $(RS_EXTERN_ARGS) ;
	@mv lib$(RS_CRATE).d lib$(RS_CRATE).tmp ; echo -e "$@: $(RS_LDEPS)" | cat - lib$(RS_CRATE).tmp > lib$(RS_CRATE).d ; rm lib$(RS_CRATE).tmp ; cat *.d > .depend ;

endif

$(HDR)/%.h :	%.h
	@mkdir -p -m 775 $(HDR) ;
	cp -fp	$? $@

#
#	Rust bindings phase: one $(HDR)/foo.rs per exported foo.h (rule in rules.mak)
#

RS_BINDINGS :=	$(if $(BINDGEN),$(patsubst %.h,%.rs,$(filter %.h,$(CHDRS))))

.PHONY:	bindings
bindings::	$(CHDRS) $(RS_BINDINGS)
	@test -n "$(BINDGEN)" -o "$(RS_BINDGEN)" != required || { echo "error: bindgen not found (RS_BINDGEN=required)" >&2 ; exit 1 ; }
	$(ECHO)	"	Unit	$(UNIT): $@ complete!"

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
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) -l$(UNIT) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc $(LIBRARY)
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) -l$(UNIT) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.rs $(LIBRARY) $(RS_LIBRARY)
	$(RUSTC) -o $@ --emit=link,dep-info=$@.d $(RSFLAGS) $@.rs -L$(LIB) $(RS_LIBRARY:%=--extern $(RS_CRATE)=%) $(RS_EXTERN_ARGS) -C link-args="$(LDFLAGS) -l$(UNIT) $(LIBRARIES) $(SYS_LIBS)" ;
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY) $(RS_LDEPS) $(RS_LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

else

% :	%.c $(LIBRARY)
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) $(LIBRARY) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc $(LIBRARY)
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) $(LIBRARY) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.rs $(LIBRARY) $(RS_LIBRARY)
	$(RUSTC) -o $@ --emit=link,dep-info=$@.d $(RSFLAGS) $@.rs -L$(LIB) $(RS_LIBRARY:%=--extern $(RS_CRATE)=%) $(RS_EXTERN_ARGS) -C link-args="$(LDFLAGS) $(LIBRARY) $(LIBRARIES) $(SYS_LIBS)" ;
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(LIBRARY) $(RS_LDEPS) $(RS_LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

endif

else

% :	%.c
	$(CC) -MD -o $@ $(CFLAGS) $@.c $(LDFLAGS) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   " | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.cc
	$(CXX) -MD -o $@ $(CXXFLAGS) $@.cc $(LDFLAGS) $(LIBRARIES) $(SYS_LIBS) $(RS_STD);
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   " | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

% :	%.rs $(RS_LIBRARY)
	$(RUSTC) -o $@ --emit=link,dep-info=$@.d $(RSFLAGS) $@.rs -L$(LIB) $(RS_LIBRARY:%=--extern $(RS_CRATE)=%) $(RS_EXTERN_ARGS) -C link-args="$(LDFLAGS) $(LIBRARIES) $(SYS_LIBS)" ;
	@mv $@.d $@.tmp ; echo -e "$@: $(LDEPS)   $(RS_LDEPS) $(RS_LIBRARY)" | cat - $@.tmp > $@.d ; rm $@.tmp ; cat *.d > .depend ;

endif

ifneq	("$(filter %.a,$(RS_STD))","")

$(OBJS:.o=):	$(filter %.a,$(RS_STD))

endif

$(BIN)/% :	%
	@-mkdir -p -m 775 $(BIN)/.old ;
	@test ! -f $@ || mv -f $@ $(BIN)/.old ;
	cp -fp	$< $@ ;

.PHONY:	clean cleanup
clean cleanup::
# the scripts keep their mode: the install rule sets the mode of the copy in bin, and a source
# script that loses its execute bit makes git report the unit as modified (and breaks repo/repo.sh)
	@-chmod	664 $(filter-out $(SCRIPTS),$(SOURCE))	;
	@rm -f	*.o		;
	@rm -f	*.a		;
	@rm -f	*.d		;
	@rm -f	*.tmp		;
	@rm -f	core.*		;
	@rm -f	$(OBJS:.o=) $(RS_SRCS:.rs=) .lib.rs	;
	@rm -f	$(SRC_ADD)	;
	@rm -f	$(CHDRS)	;
	@for f in $(patsubst %.h,%.rs,$(filter %.h,$(CHDRS))) ; do test ! -f $$f.bindgen || rm -f $$f $$f.d $$f.bindgen ; done ;
	@-mkdir -p -m 770 $(BIN)/.old && mv -f $(EXECUTABLES)	$(BIN)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(LIBRARY)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(LIBRARY2)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(S_LIBRARY)	$(LIB)/.old 2>/dev/null ; exit 0 ;
	@-mkdir -p -m 770 $(LIB)/.old && mv -f $(RS_LIBRARY)	$(LIB)/.old 2>/dev/null ; exit 0 ;
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
