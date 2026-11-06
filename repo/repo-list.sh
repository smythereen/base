#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo list [--root DIR]
#
# Show the project's units (project.repos in the project root): the version checked out,
# why the unit is there ("asked" = added by you with repo add, "dep of X" = added because
# X requires it), where its repo URL comes from ("private" = private.units, "catalog" =
# the catalog worker) and the URL.  Nothing is looked up on the network.
RL_PROG=repo-list
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DIR=
while [ $# -gt 0 ]; do
	case $1 in
	--root) DIR=$2; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
rl_root "$DIR"; rl_init_tmp
printf '%-14s %-10s %-12s %-8s %s\n' UNIT VERSION WHY SOURCE URL
rl_list_entries | while IFS='	' read -r u via; do
	if [ "$via" = - ]; then why=asked; else why="dep of $via"; fi
	purl=$(rl_private_url "$u")
	if [ -n "$purl" ]; then src=private; else src=catalog; fi
	ver=-; url=$purl
	if [ -d "$ROOT/$u" ]; then
		ver=$(git -C "$ROOT/$u" describe --tags --exact-match HEAD 2>/dev/null || git -C "$ROOT/$u" rev-parse --short HEAD 2>/dev/null || echo '?')
		url=$(git -C "$ROOT/$u" remote get-url origin 2>/dev/null || echo "$purl")
	fi
	[ -n "$url" ] || url="(from the catalog when needed)"
	printf '%-14s %-10s %-12s %-8s %s\n' "$u" "$ver" "$why" "$src" "$url"
done
echo "(list: $LIST_FILE; private units: $PRIV_FILE; base units are not listed: $(rl_base_list | tr '\n' ' '))"
[ ! -f "$MARK_FILE" ] || echo "FULL REBUILD NEEDED since unit versions changed (see $MARK_FILE); after rebuilding run: repo rebuilt"
