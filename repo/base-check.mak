# ---- this unit REQUIRES the base repo installed first (see README.md) -------------
ifeq ($(and $(wildcard ../rules.mak),$(wildcard ../targets.mak),$(wildcard ../BASE)),)
$(error This unit requires the base repo installed first: ../rules.mak, ../targets.mak or ../BASE is missing. Clone the base repo, then put this unit in the base tree, with: repo/repo.sh add <unit>. See the Requires section of README.md)
endif
ifneq ($(abspath ..),$(abspath $(shell echo ~)))
$(warning The project tree $(abspath ..) is not your home directory $(shell echo ~): rules.mak installs into bin, cmn and lib below the home directory. Run: HOME=$(abspath ..) make)
endif
# ------------------------------------------------------------------------------------
