#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo order [--present] [--check] [--catalog URL] [--deps-dir DIR]
#
# List the units in dependency order (a unit comes after the units it requires).
#
#   (default)   the units the repo list resolves to, including ones not fetched yet,
#               with their versions and where they come from.  Units that are not in the
#               tree are looked up (private.units, catalog) and probe-cloned.
#   --present   only the directories in the tree: the base units first (they need each
#               other and are built together), then the others.  One name per line, for
#               scripts:   make UNITS="$(repo order --present)"
#   --check     with --present: complain about units whose "require" is not in the tree
#               (exit status 1)
RL_PROG=repo-order
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
PRESENT=0; CHECK=0; RARGS=; DIR=
while [ $# -gt 0 ]; do
	case $1 in
	--present) PRESENT=1 ;;
	--check) CHECK=1 ;;
	--root) DIR=$2; shift ;;
	--deps-dir) RARGS="$RARGS $1 $2"; shift ;;
	--catalog) UNITS_CATALOG_URL=$2; export UNITS_CATALOG_URL; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
rl_root "$DIR"; rl_init_tmp; rl_catalog_check

if [ "$PRESENT" = 0 ]; then
	# shellcheck disable=SC2086
	rl_resolve $RARGS; rc=$?
	i=0
	echo "base: $(rl_base_list | tr '\n' ' ')"
	while IFS='	' read -r kind u ver state by url; do
		[ "$kind" = ORDER ] || continue
		i=$((i+1)); printf '%3d  %-12s %-10s %-12s needed by %-12s %s\n' "$i" "$u" "$ver" "[$state]" "$by" "$url"
	done < "$RL_TMP/resolve"
	[ "$rc" -ne 0 ] && { cat "$RL_TMP/resolve.err" >&2; exit "$rc"; }
	exit 0
fi

rl_base_list
rl_present_units > "$RL_TMP/present"
: > "$RL_TMP/edges"; bad=0
while read -r u; do
	echo "$u $u" >> "$RL_TMP/edges"
	[ -f "$ROOT/$u/UNIT.deps" ] || { [ "$CHECK" = 1 ] && { rl_warn "$u has no UNIT.deps"; bad=1; }; continue; }
	sed 's/#.*//' "$ROOT/$u/UNIT.deps" | while read -r k n rest; do
		case $k in require|optional) ;; *) continue ;; esac
		grep -x -q -- "$n" "$RL_TMP/base.list" && continue
		if grep -x -q -- "$n" "$RL_TMP/present"; then echo "$n $u"
		elif [ "$k" = require ] && [ "$CHECK" = 1 ]; then echo "MISSING $u $n" >&2; fi
	done >> "$RL_TMP/edges" 2> "$RL_TMP/miss"
	if [ -s "$RL_TMP/miss" ]; then sed 's/^MISSING \([^ ]*\) \(.*\)/repo-order: unit \1 requires \2, which is not in the tree/' "$RL_TMP/miss" >&2; bad=1; fi
done < "$RL_TMP/present"
tsort "$RL_TMP/edges" || { echo "repo-order: dependency cycle between units" >&2; exit 3; }
[ "$bad" = 0 ] || exit 1
exit 0
