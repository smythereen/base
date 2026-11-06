#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo remove [-n] [--force] [--keep-deps] [--catalog URL] [--deps-dir DIR] NAME
#
# Remove the unit NAME from the project: its entry leaves the repo list (project.repos)
# and its directory is MOVED to <project>/.old/NAME.YYYYMMDD-HHMMSS (so unpushed work is
# never lost; clear old backups with "repo purge").  A line for NAME in private.units is
# kept, so that adding it again, or a unit that needs it, still finds its URL.  A full
# rebuild is needed afterwards (see "repo rebuilt").
#
# It refuses, changing nothing, when another unit of the list requires NAME (its
# UNIT.deps says "require NAME"); --force removes it anyway, and says what will break.
# Units that were added only as dependencies of NAME, and that nothing else needs, are
# removed with it (--keep-deps keeps them, as entries of their own).
#
# Not removed: what NAME's build installed into lib/, bin/, cmn/ - rebuild or clean those.
#
#   --force      remove although other units require it
#   --keep-deps  keep the units that only NAME needed
#   -n           show what would happen, change nothing
RL_PROG=repo-remove
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DRY=0; FORCE=0; KEEP=0; RARGS=; DIR=; UNIT=
while [ $# -gt 0 ]; do
	case $1 in
	-n|--dry-run) DRY=1 ;;
	--force) FORCE=1 ;;
	--keep-deps) KEEP=1 ;;
	--root) DIR=$2; shift ;;
	--deps-dir) RARGS="$RARGS $1 $2"; shift ;;
	--catalog) UNITS_CATALOG_URL=$2; export UNITS_CATALOG_URL; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) rl_die 2 "unknown option $1" ;;
	*) [ -z "$UNIT" ] || rl_die 2 "one unit at a time"; UNIT=$1 ;;
	esac; shift
done
[ -n "$UNIT" ] || rl_die 2 "usage: repo remove [options] NAME"
rl_valid_name "$UNIT" || rl_die 2 "bad unit name '$UNIT'"
rl_root "$DIR"; rl_init_tmp; rl_catalog_check
rl_base_list | grep -x -q -- "$UNIT" && rl_die 2 "$UNIT is part of the base repo and cannot be removed"
[ -f "$LIST_FILE" ] || rl_die 1 "no repo list $LIST_FILE"
rl_list_entries > "$RL_TMP/entries"
awk -F'\t' -v u="$UNIT" '$1==u{f=1} END{exit !f}' "$RL_TMP/entries" || rl_die 1 "$UNIT is not in the repo list ($LIST_FILE)"

# who requires NAME: the other units of the list, by their UNIT.deps in the tree
: > "$RL_TMP/blockers"; : > "$RL_TMP/optional"
awk -F'\t' -v u="$UNIT" '$1!=u{print $1}' "$RL_TMP/entries" | while read -r o; do
	[ -f "$ROOT/$o/UNIT.deps" ] || continue
	sed 's/#.*//' "$ROOT/$o/UNIT.deps" | awk -v n="$UNIT" -v o="$o" '$2==n && $1=="require"{print o > "/dev/stderr"} $2==n && $1=="optional"{print o}' \
		>> "$RL_TMP/optional" 2>> "$RL_TMP/blockers"
done
if [ -s "$RL_TMP/blockers" ]; then
	echo "$UNIT is required by: $(sort -u "$RL_TMP/blockers" | tr '\n' ' ')"
	if [ "$FORCE" = 0 ]; then
		echo "repo-remove: NOT removed: remove those units first, or use --force." >&2
		exit 1
	fi
	echo "--force: removing it anyway; those units will not build without it, and the next"
	echo "         fetch brings it back as their dependency (URL: private.units or the catalog)"
fi
[ ! -s "$RL_TMP/optional" ] || echo "note: $(sort -u "$RL_TMP/optional" | tr '\n' ' ')can use $UNIT optionally; they will build without it"

# the new list, and which dependency-only units fall away with it
awk -v u="$UNIT" '
	{ line=$0; i=index(line,"#"); if (i) line=substr(line,1,i-1)
	  n=split(line,f," ")
	  if (n>=1 && f[1]==u) next
	  print $0 }' "$LIST_FILE" > "$RL_TMP/new"
FU=$(rl_tool fetch-units)
# shellcheck disable=SC2086
"$FU" --dry-run --porcelain --no-update --root "$ROOT" --list "$RL_TMP/new" --private "$PRIV_FILE" $RARGS > "$RL_TMP/closure" 2> "$RL_TMP/closure.err"; rc=$?
[ "$rc" -ne 2 ] && [ "$rc" -ne 3 ] || { cat "$RL_TMP/closure.err" >&2; rl_die 1 "the rest of the project does not resolve; nothing changed"; }
awk -F'\t' '$1=="ORDER"{print $2}' "$RL_TMP/closure" | sort > "$RL_TMP/needed"
awk -F'\t' -v u="$UNIT" '$2!="-" && $1!=u {print $1}' "$RL_TMP/entries" | sort > "$RL_TMP/derived"
comm -23 "$RL_TMP/derived" "$RL_TMP/needed" > "$RL_TMP/orphans"
echo "removing: $UNIT"
if [ -s "$RL_TMP/orphans" ]; then
	if [ "$KEEP" = 1 ]; then echo "kept (only $UNIT needed them; they become entries of their own): $(tr '\n' ' ' < "$RL_TMP/orphans")"
	else echo "removing too (only $UNIT needed them): $(tr '\n' ' ' < "$RL_TMP/orphans")"; fi
fi
if [ "$DRY" = 1 ]; then echo "(dry run: nothing changed)"; exit 0; fi

if [ "$KEEP" = 1 ]; then
	# the kept dependencies lose their via= and become explicit entries
	awk -v keep="$RL_TMP/orphans" 'BEGIN { while ((getline l < keep) > 0) k[l]=1 }
		{ line=$0; i=index(line,"#"); if (i) line=substr(line,1,i-1); n=split(line,f," ")
		  if (n>=1 && (f[1] in k)) { print f[1]; next }
		  print $0 }' "$RL_TMP/new" > "$RL_TMP/new2"
else
	awk -v drop="$RL_TMP/orphans" 'BEGIN { while ((getline l < drop) > 0) k[l]=1 }
		{ line=$0; i=index(line,"#"); if (i) line=substr(line,1,i-1); n=split(line,f," ")
		  if (n>=1 && (f[1] in k)) next
		  print $0 }' "$RL_TMP/new" > "$RL_TMP/new2"
fi
rl_write_list "$RL_TMP/new2" || rl_die 1 "cannot write $LIST_FILE"
echo "$LIST_FILE: entry removed"
gone=$UNIT
[ "$KEEP" = 1 ] || gone="$gone $(tr '\n' ' ' < "$RL_TMP/orphans")"
for g in $gone; do
	[ -d "$ROOT/$g" ] || { echo "  $g/: not in the tree"; continue; }
	rl_git_state "$g" >/dev/null 2>&1
	warn=; [ "$ST_DIRTY" = 1 ] && warn=" (it had local changes: they are in the backup)"
	if moved=$(rl_backup_dir "$g"); then echo "  $g/ moved to ${moved#"$ROOT"/}$warn"
	else rl_warn "could not move $g/ to .old; the directory is still in the tree"; fi
done
rl_mark_rebuild removed $gone
echo "== FULL REBUILD NEEDED: units were removed.  run:  cd $ROOT && HOME=$ROOT make cleanup && HOME=$ROOT make     then:  repo rebuilt"
[ ! -f "$LIST_FILE.lock" ] || { for g in $gone; do grep -v "^$g " "$LIST_FILE.lock" > "$RL_TMP/lock" ; cp "$RL_TMP/lock" "$LIST_FILE.lock"; done; }
exit 0
