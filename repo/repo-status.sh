#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo status [--fetch] [--dirty] [--root DIR] [--catalog URL]
#
# One line per unit of the project: what is checked out now (tag, branch or commit), the
# newest version tag the unit has, whether the working tree is dirty and how far the
# checkout is ahead of / behind its upstream.  Units that are needed but missing, and
# unit directories that nothing needs, are listed too, and so is a pending full rebuild.
#
#   --fetch   run "git fetch" in every unit first, so the newest version and ahead/behind
#             are current (network)
#   --dirty   show only units that need attention
RL_PROG=repo-status
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
FETCH=0; ONLY=0; RARGS=; DIR=
while [ $# -gt 0 ]; do
	case $1 in
	--fetch) FETCH=1 ;;
	--dirty) ONLY=1 ;;
	--root) DIR=$2; shift ;;
	--deps-dir) RARGS="$RARGS $1 $2"; shift ;;
	--catalog) UNITS_CATALOG_URL=$2; export UNITS_CATALOG_URL; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
rl_root "$DIR"; rl_init_tmp; rl_catalog_check
# shellcheck disable=SC2086
rl_resolve $RARGS 2>/dev/null; rc=$?
printf '%-14s %-14s %-10s %-8s %-18s %s\n' UNIT NOW NEWEST TREE UPSTREAM NOTE
attn=0
while IFS='	' read -r kind u ver state by url; do
	[ "$kind" = ORDER ] || continue
	note=
	if [ "$state" = MISSING ] || [ "$state" = would-clone ] || [ "$state" = deps-dir ]; then
		printf '%-14s %-14s %-10s %-8s %-18s %s\n' "$u" "-" "-" "-" "-" "NOT IN TREE (repo update clones it${url:+ from $url}; needed by $by)"
		attn=1; continue
	fi
	[ "$FETCH" = 1 ] && git -C "$ROOT/$u" fetch -q --tags 2>/dev/null
	rl_git_state "$u"
	tree=clean; [ "$ST_DIRTY" = 1 ] && { tree=DIRTY; note="local changes"; }
	if [ "$ST_BEHIND" = - ]; then up=no-upstream; else up="+$ST_AHEAD/-$ST_BEHIND"; fi
	[ "$ST_AHEAD" != - ] && [ "$ST_AHEAD" -gt 0 ] && note="$note unpushed commits"
	newest=$(rl_newest_ref "$ROOT/$u"); newest=${newest:--}
	if [ "$newest" != - ] && [ "$ST_NOW" != "$newest" ]; then note="$note not at the newest version $newest (repo update)"; fi
	if [ "$newest" = - ] && [ "$ST_BEHIND" != - ] && [ "$ST_BEHIND" -gt 0 ]; then note="$note behind upstream (repo update)"; fi
	[ -n "$note" ] && attn=1
	[ "$ONLY" = 1 ] && [ -z "$note" ] && continue
	printf '%-14s %-14s %-10s %-8s %-18s %s\n' "$u" "$ST_NOW" "$newest" "$tree" "$up" "$note"
done < "$RL_TMP/resolve"
while IFS='	' read -r kind u rest; do
	[ "$kind" = UNUSED ] || continue
	printf '%-14s %-14s %-10s %-8s %-18s %s\n' "$u" "-" "-" "-" "-" "NOT IN THE REPO LIST and not needed by it (repo add it, or move it away)"
	attn=1
done < "$RL_TMP/resolve"
[ "$rc" -ne 0 ] && { echo "note: the unit list does not resolve cleanly:" >&2; sed 's/^/  /' "$RL_TMP/resolve.err" >&2; }
if [ -f "$MARK_FILE" ]; then
	echo "FULL REBUILD NEEDED: units changed version since the last rebuild:"; awk '{print "  " $2 " (" $3 ")"}' "$MARK_FILE" | sort -u
	echo "  run:  cd $ROOT && HOME=$ROOT make cleanup && HOME=$ROOT make     then:  repo rebuilt"
elif [ "$attn" = 0 ] && [ "$rc" -eq 0 ]; then echo "all units are at their newest version and clean"; fi
exit 0
