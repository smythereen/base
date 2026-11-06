# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
##
## This is the master makefile
##
## Usage:	make [ target ] [ UNITS="unit ..." ]
##
## Where:	Target is one of the following (the default is all):
##
##      		all		(the default) make sure the project is populated and its
##      				units are fetched, then header, library and product over
##      				all units; see "The project" below
##      		header		copy each unit's exported headers to ~/cmn
##      		library		build each unit's library into ~/lib
##      		product		build each unit's programs and install them in ~/bin
##      		cleanup, clean	delete built files, move installed files to .old
##      		dist_clean	cleanup, then delete the installed products and
##      				empty cmn, lib, tmp and the run files
##      		source_list	no-op, accepted by every unit
##      		dir		create bin cmn hlp lib run tmp and the unit directories
##      		help		print this text
##      	fetch		clone the units in the repo list (project.repos in this directory), and
##      			the units they need, with repo/fetch-units.sh; public units come from the
##      			catalog ($UNITS_CATALOG_URL), private ones from private.units.  Add or
##      			remove units with repo/repo.sh add|remove, see repo/repo.sh help
##      	order		print the units that are in the tree in dependency order
##      		populate	run "repo add" for every unit named in project.repos; a
##      				project without project.repos first gets the starter list
##      				("repo fetch --project NONE", from the project worker)
##      		units		print the UNITS that make uses (the units.mak list)
##      		newunit update	use the Git project tools (proj) when they are
##      				installed in ~/bin
##      		copy_to_peer copy_to_dev2 copy_to_dev3 source_rpm
##      				copy the sources to other computers, or write the
##      				rpm source list
##
##      	UNITS is optional, a quoted list of unit names.  The default is
##      	the list in units.mak, which make writes itself from the unit
##      	directories that are present (dependency order); without units.mak
##      	(REPO_AUTO=no) it is every directory in ~ that contains a makefile
##      	or Makefile.  It must be given on the command line (an environment
##      	UNITS is ignored, so a stale UNITS in the shell cannot hurt).
##
##      The project (a plain "make" does all of this, in one run):
##      	project.repos   the units of the project (see repo/repo.sh help).  If it is
##      			missing, make populates it from the starter list, clones those
##      			units and the units they need (repo add), and builds.
##      	project.repos.lock   written by every fetch.  When project.repos is newer than
##      			the lock, make runs "repo fetch --no-update": it clones the units
##      			that are not in the tree yet and rewrites the lock.
##      	units.mak       UNITS, generated from the unit directories present whenever the
##      			lock is newer.  It is an included makefile, so GNU make restarts
##      			itself when it changes: the new units are in this very build.
##      			When the list changes make prints
##      			    UNITS changed, run: source ~/.bash_profile
##      			(~/.bash_profile reads UNITS from units.mak, see env.example).
##      	.built          written after a full rebuild.  A FULL REBUILD (cleanup, then
##      			header library product) is done when .built is missing, when
##      			.rebuild-needed (written by repo add/update/fetch/remove) is newer
##      			than it, or when the lock's contents differ from the lock of the
##      			last full rebuild; otherwise the units are built incrementally.
##      			After a full rebuild without errors make runs "repo rebuilt".
##      	REPO_AUTO=no    skip all of this (an old project with no project.repos).
##      	PROJECT_WORKER_URL, UNITS_CATALOG_URL   the two workers (environment).
##
##      	For each unit, source files and a unit makefile reside in a
##      	subdirectory named after the unit.  Each phase runs over all
##      	units before the next one starts.
##
## The phases deliberately keep going when a unit fails, and the exit status
## is 0, so one build shows all the good and bad units.  The output of each
## target is written to <target>.log in this directory (header.log,
## library.log, product.log ...).  Scan the logs for "warn" and "error".
##
## Note: The newunit/populate/update targets use the modern Git project tools
## (proj / project-*) when available in ~/bin (the main project bin, populated
## by 'cd tools; make product' after the tools unit is obtained).
## The PROJECT environment variable (defined in .bash_profile) is the single
## source of truth for the project name and is passed to 'proj init $(PROJECT)'.
##
## Examples:	make
##		make cleanup
##		make header library "UNITS=map mio"
##

#
#	The project machinery (project.repos, project.repos.lock, units.mak, .built)
#

SHELL :=	/bin/bash

.DEFAULT_GOAL := all

REPO_AUTO ?=	yes
REPO =		repo/repo.sh
PROJ_LIST =	project.repos
PROJ_LOCK =	project.repos.lock
MARKER =	.rebuild-needed
BUILT =		.built
UNITS_MAK =	units.mak

# the rules below are only wanted by goals that build or populate; "make help", "make cleanup"
# and the like must not fetch anything
PROJECT_RULES :=
ifneq ($(REPO_AUTO),no)
ifeq ($(MAKECMDGOALS),)
PROJECT_RULES := yes
else ifneq ($(filter all populate fetch units $(UNITS_MAK) $(PROJ_LIST) $(PROJ_LOCK),$(MAKECMDGOALS)),)
PROJECT_RULES := yes
endif
endif

# An environment UNITS is never used (it may be stale): UNITS comes from units.mak, or from
# the command line.  units.mak is remade when it is out of date, and make then restarts.
UNITS :=
ifneq ($(PROJECT_RULES),)
include	$(UNITS_MAK)
else
-include $(UNITS_MAK)
endif
ifeq ($(strip $(UNITS)),)
UNITS =	$(shell cd ~; ls */[Mm]akefile 2>/dev/null | cut -d'/' -f1 | sort -u )
endif

#
#	Definitions
#

OTHER =	bin	\
	cmn	\
	hlp	\
	lib	\
	run	\
	tmp

SOURCE =	etcbashrc		\
		etcprofile		\
		makefile 		\
		rules.mak 		\
		targets.mak 		\
		.bash_profile 		\
		.bashrc			\
		.rpmmacros		\
		.vimrc

TGT_HOST ?= localhost
#
#	Targets
#
# populate: a project with no project.repos starts from the starter list of the project
# worker (project NONE); then "repo add" is run for every unit the list names (the ones asked
# for, not the "via=" entries that fetch records for dependencies).
define populate_cmds
if [ ! -f $(PROJ_LIST) ]; then echo "== no $(PROJ_LIST): starting from the starter list"; \
	$(REPO) fetch --project NONE --list-only || exit 1; fi; \
rc=0; for unit in $$(sed 's/#.*//' $(PROJ_LIST) | awk 'NF && $$2 !~ /^via=/ {print $$1}'); do \
	echo "	repo add $$unit"; $(REPO) add $$unit || rc=1; \
done; exit $$rc
endef

# regenerate units.mak; say so when UNITS changed (the shell's UNITS is then out of date)
define units_cmds
$(REPO) units --make > $(UNITS_MAK).new || { rm -f $(UNITS_MAK).new; exit 1; }; \
if [ -f $(UNITS_MAK) ] && cmp -s $(UNITS_MAK).new $(UNITS_MAK); then \
	rm -f $(UNITS_MAK).new; touch $(UNITS_MAK); \
else \
	mv -f $(UNITS_MAK).new $(UNITS_MAK); \
	echo "== $$(grep '^UNITS' $(UNITS_MAK))"; \
	echo "UNITS changed, run: source ~/.bash_profile"; \
fi
endef

ifneq ($(PROJECT_RULES),)

.PHONY:	all populate units fetch order help

$(PROJ_LIST):
	@$(populate_cmds)

$(PROJ_LOCK):	$(PROJ_LIST)
	@echo "== $(PROJ_LIST) is not covered by $(PROJ_LOCK): fetching the units that are not in the tree"
	@$(REPO) fetch --no-update

$(UNITS_MAK):	$(PROJ_LOCK)
	@$(units_cmds)

# a full rebuild when: no full rebuild has been done, the rebuild marker is newer than the last
# one, or the lock file differs from the lock of the last one; otherwise an incremental build
all:	$(UNITS_MAK)
	@full=; \
	if [ ! -f $(BUILT) ]; then full="no full build has been done yet"; \
	elif [ -f $(MARKER) ] && [ $(MARKER) -nt $(BUILT) ]; then full="$(MARKER) is newer than $(BUILT): unit versions changed"; \
	elif [ "$$(cksum < $(PROJ_LOCK))" != "$$(cat $(BUILT))" ]; then full="the units changed ($(PROJ_LOCK) differs from the last full build)"; fi; \
	if [ -n "$$full" ]; then echo "== FULL REBUILD: $$full"; $(MAKE) --no-print-directory cleanup; fi; \
	$(MAKE) --no-print-directory header library product; \
	if [ -n "$$full" ]; then \
		if grep -q -E 'error:|\*\*\* |Error [0-9]' header.log library.log product.log 2>/dev/null; then \
			echo "== the full rebuild had errors (see the *.log files): the next make does it again"; \
		else \
			cksum < $(PROJ_LOCK) > $(BUILT); $(REPO) rebuilt; \
		fi; \
	fi

else

all:	header library product

endif

units:
	@echo $(UNITS)

help:
	@-tput clear
	@-cat makefile | grep "##" | grep -v "###" | cut -c3- | more

header library product cleanup clean source_list dist_clean::
	@-for unit in $(UNITS) ;\
	do \
		echo	"	make -C $${unit}  $(@)" ;\
		make	-C $${unit} -S $(@) ;\
	done 2>&1 | tee $(@).log 

source_rpm:
	@-for F in $(SOURCE); do echo "`pwd`/$${F}"  ; done > rpm/source.list
	@-for unit in $(UNITS) ;\
	do \
		echo "`pwd`/$${unit}" >> rpm/source.list ;\
		make	-C $${unit} -S $(@) ;\
	done 2>&1 ;

dir:	 
	@-mkdir $(OTHER) 1>/dev/null 2>&1 ;
	@-mkdir $(UNITS) 1>/dev/null 2>&1 ;

dist_clean::
	@-rm	-rf	.cgi-bin/.old	;
	@-rm	-f	.cgi-bin/*	;
	@-rm	-rf	.html/.old	;
	@-rm	-f	.html/*		;
	@-rm	-rf	.html_sh/.old	;
	@-rm	-f	.html_sh/*	;
	@-rm	-f	bin/.K* 	;
	@-rm	-rf	bin/.old	;
	@-rm	-rf	cmn/*		;
	@-rm	-rf	lib/.old	;
	@-rm	-rf	lib/*		;
	@-rm	-f	run/*.trc*	;
	@-rm	-f	run/event.log	;
	@-rm	-f	run/*.txt	;
	@-rm	-rf	run/pipes/*	;
	@-rm	-rf	tmp/*		;
	@-rm	-f	*.log		;
	@-find	.	-name "core.*" -exec rm -f {} \; ;
	@-find	tmp	-type f -exec rm -f {} \; ;

fetch:
	@repo/repo.sh fetch

order:
	@repo/repo.sh order --present

newunit:
	@-for unit in $(UNITS) ;\
	do \
		echo	"	make -C $${unit}  $(@)" ;\
		make	-C $${unit} -S $(@) ;\
	done 2>&1 | tee $(@).log 
	@if [ -x ~/bin/proj ]; then \
		echo "	using new project tools (proj) from main project ~/bin"; \
		~/bin/proj init $(PROJECT) || true; \
	elif command -v proj >/dev/null 2>&1; then \
		proj init $(PROJECT) || true; \
	fi

populate:
	@$(populate_cmds)
	@$(units_cmds)

update:
	@if [ -x ~/bin/proj ]; then \
		echo "	using new project tools (proj) from main project ~/bin"; \
		~/bin/proj sync || true; \
	elif command -v proj >/dev/null 2>&1; then \
		proj sync || true; \
	fi

COPY_TO_PEER:
	@-for P in $(PEERS); do scp -p $(SOURCE) $(LOGNAME)@$${P}:. ; done

#	@-for P in $(PEERS); do ping -q -c 1 -W 1 $${P} >/dev/null 2>&1 || continue ; scp -p $(SOURCE) $(LOGNAME)@$${P}:. ; done

copy_to_peer:	COPY_TO_PEER
	@for unit in $(UNITS) ;\
	do \
		for P in $(PEERS); do ssh $(LOGNAME)@$${P} "mkdir -p $${unit} ;" ; done ;\
		cd	$${unit} 1>/dev/null 2>&1 ;\
		make	$(@) ;\
		cd	.. 1>/dev/null 2>&1 ;\
	done ;

#		for P in $(PEERS); do ping -q -c 1 -W 1 $${P} >/dev/null 2>&1 || continue ; ssh $(LOGNAME)@$${P} "mkdir -p $${unit} ;" ; done ;\

COPY_TO_DEV2:
	@scp -p $(SOURCE) dev2@$(TGT_HOST):.

copy_to_dev2:	COPY_TO_DEV2
	@for unit in $(UNITS) ;\
	do \
		cd	$${unit} 1>/dev/null 2>&1 ;\
		make	$(@) ;\
		cd	.. 1>/dev/null 2>&1 ;\
	done ;

COPY_TO_DEV3:
	@scp -p $(SOURCE) dev3@$(TGT_HOST):.

copy_to_dev3:	COPY_TO_DEV3
	@for unit in $(UNITS) ;\
	do \
		cd	$${unit} 1>/dev/null 2>&1 ;\
		make	$(@) ;\
		cd	.. 1>/dev/null 2>&1 ;\
	done ;

