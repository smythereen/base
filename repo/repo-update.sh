#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo update [-n] [--catalog URL] [unit ...]
#
# Bring every unit of the project to its NEWEST version: the newest version tag (v1.10 is
# newer than v1.9), or the head of the default branch for a repo without version tags;
# units that are missing are cloned.  There are no pins: a project has one version of each
# unit in one directory, and newer versions must be backward compatible.
#
# Whenever a unit was cloned or changed version, the whole tree needs a FULL REBUILD: the
# command says so and writes the marker .rebuild-needed in the project root.  After the
# rebuild run "repo rebuilt".
#
#   unit ...   only these units (they must be in the project and in the tree)
#   -n         show what would be done
#
# Units with local changes are never touched.
RL_PROG=repo-update
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DRY=0; RARGS=; DIR=; NAMES=
while [ $# -gt 0 ]; do
	case $1 in
	-n|--dry-run) DRY=1 ;;
	--root) DIR=$2; shift ;;
	--deps-dir) RARGS="$RARGS $1 $2"; shift ;;
	--catalog) UNITS_CATALOG_URL=$2; export UNITS_CATALOG_URL; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) rl_die 2 "unknown option $1" ;;
	*) rl_valid_name "$1" || rl_die 2 "bad unit name '$1'"; NAMES="$NAMES $1" ;;
	esac; shift
done
rl_root "$DIR"; rl_init_tmp; rl_catalog_check
FU=$(rl_tool fetch-units)

if [ -z "$NAMES" ]; then
	[ "$DRY" = 1 ] && set -- --dry-run || set --
	# shellcheck disable=SC2086
	exec "$FU" --root "$ROOT" --list "$LIST_FILE" --private "$PRIV_FILE" $RARGS "$@"
fi

# a subset: work unit by unit
# shellcheck disable=SC2086
rl_resolve $RARGS || { cat "$RL_TMP/resolve.err" >&2; rl_die 1 "the unit list does not resolve; fix that first (repo order)"; }
for n in $NAMES; do
	awk -F'\t' -v n="$n" '$1=="ORDER" && $2==n{f=1} END{exit !f}' "$RL_TMP/resolve" || rl_die 1 "$n is not in the project (repo list)"
done
: > "$RL_TMP/changed"
while IFS='	' read -r kind u ver state by url; do
	[ "$kind" = ORDER ] || continue
	case " $NAMES " in *" $u "*) ;; *) continue ;; esac
	[ "$state" = present ] || { echo "$u: not in the tree; run: repo update   (no unit names)"; continue; }
	rl_git_state "$u" || { echo "$u: not a git checkout; skipped"; continue; }
	[ "$ST_DIRTY" = 1 ] && { echo "$u: local changes; skipped"; continue; }
	git -C "$ROOT/$u" fetch -q --tags 2>/dev/null || rl_warn "$u: fetch failed"
	new=$(rl_newest_ref "$ROOT/$u")
	old=$ST_NOW; oldrev=$(git -C "$ROOT/$u" rev-parse HEAD 2>/dev/null)
	if [ "$DRY" = 1 ]; then
		if [ -n "$new" ] && [ "$new" != "$old" ]; then echo "$u: would move $old -> $new"
		elif [ -z "$new" ]; then echo "$u: would fast-forward $old"
		else echo "$u: already at the newest version ($old)"; fi
		continue
	fi
	if [ -n "$new" ]; then
		git -C "$ROOT/$u" -c advice.detachedHead=false checkout -q "$new" 2>/dev/null || { echo "$u: cannot check out '$new'"; continue; }
	else
		git -C "$ROOT/$u" symbolic-ref -q HEAD >/dev/null 2>&1 && { git -C "$ROOT/$u" pull -q --ff-only 2>/dev/null || echo "$u: could not fast-forward"; }
	fi
	rl_git_state "$u"
	if [ "$oldrev" = "$(git -C "$ROOT/$u" rev-parse HEAD 2>/dev/null)" ]; then echo "$u: unchanged ($ST_NOW)"
	else echo "$u: $old -> $ST_NOW"; echo "$u" >> "$RL_TMP/changed"; fi
done < "$RL_TMP/resolve"
if [ -s "$RL_TMP/changed" ]; then
	# shellcheck disable=SC2046
	rl_mark_rebuild updated $(cat "$RL_TMP/changed")
	rl_rebuild_hint "$(tr '\n' ' ' < "$RL_TMP/changed")"
fi
exit 0
