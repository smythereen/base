# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# bin unit: project helpers installed as suffixless executables in ~/bin.
# When the project directory is HOME, ~/bin is this directory.
#

include		../rules.mak

CHDRS :=
HDRS :=

# Do not let clean/dist_clean relocate or delete committed helpers.
# Product still installs *.sh → suffixless names via targets.mak.
EXECUTABLES :=
PRODUCTS := $(addprefix $(BIN)/,$(SCRIPTS:.sh=))

include		../targets.mak

# ensure .depend exists for -include (targets.mak owns the recipe)
$(shell touch -a .depend)

# Reinstall suffixless copies after any clean that might have touched them.
clean cleanup::
	@for s in $(SCRIPTS); do \
		[ -f "$$s" ] || continue; \
		b=$${s%.sh}; \
		cp -fp "$$s" "$(BIN)/$$b"; \
		chmod 775 "$(BIN)/$$b"; \
	done

# dist_clean in targets.mak would rm PRODUCTS (== committed helpers when HOME
# is the project). Reinstall from .sh sources instead of deleting them.
dist_clean::
	@for s in $(SCRIPTS); do \
		[ -f "$$s" ] || continue; \
		b=$${s%.sh}; \
		cp -fp "$$s" "$(BIN)/$$b"; \
		chmod 775 "$(BIN)/$$b"; \
	done

-include	.depend
