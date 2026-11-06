# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# The repo unit: the tools that maintain the project's list of unit repos.  Part of the base
# repo.  rules.mak installs every *.sh of this directory into ~/bin without the .sh:
# repo, fetch-units, repo-add, repo-remove, repo-purge, ...
# The project's lists (project.repos, private.units) are NOT here: this unit is a public repo
# shared by all projects.  They live in the project root; the tools find the root through
# their own location (repo/ or bin/ is below it).
#
include		../rules.mak

include		../targets.mak

# nothing is compiled; keep the generic .depend include happy
.depend:
	@touch .depend

include	.depend
