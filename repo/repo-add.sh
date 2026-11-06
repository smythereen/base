#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo add [-n] [--no-fetch] [--catalog URL] [--deps-dir DIR] NAME [URL]
#
# Add the unit NAME to the project: its name goes into project.repos (in the project root),
# the repo is cloned into <project>/NAME at its newest version, and the units it requires
# (its UNIT.deps) are resolved, cloned and recorded too.
#
# Where the repo URL comes from:
#   NAME alone   a public unit: private.units if it has a line for NAME, else the catalog
#                worker ($UNITS_CATALOG_URL, or --catalog).  A unit that is in neither is
#                a private unit: it is an error, and you add it by hand (next line).
#   NAME URL     a private unit (or a fork): the line "NAME URL" is written to private.units
#                and used from then on.  Dependencies that are private need this too.
# If NAME is listed already its entry is changed (a unit that was only a dependency
# becomes one you asked for).  There are no tags to give: the newest version is always used.
#
# The check comes first: the new lists are resolved in a dry run (the repos are probed,
# nothing is written).  If the repo cannot be cloned, a required unit is unknown, or the
# result would be a dependency cycle, the lists and the tree are left unchanged.  If the
# real fetch fails after that, the lists are restored and the new directories are moved to
# .old.  When something was cloned, a full rebuild is needed (see "repo rebuilt").
#
#   --no-fetch   only check and record the entry; clone later with "repo update"
#   -n           check and show the result, change nothing
RL_PROG=repo-add
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DRY=0; NOFETCH=0; RARGS=; DIR=; UNIT=; URL=
while [ $# -gt 0 ]; do
	case $1 in
	-n|--dry-run) DRY=1 ;;
	--no-fetch) NOFETCH=1 ;;
	--root) DIR=$2; shift ;;
	--catalog) UNITS_CATALOG_URL=$2; export UNITS_CATALOG_URL; shift ;;
	--deps-dir) RARGS="$RARGS $1 $2"; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) rl_die 2 "unknown option $1" ;;
	*) if [ -z "$UNIT" ]; then UNIT=$1
	   elif [ -z "$URL" ]; then
		rl_valid_url "$1" || rl_die 2 "'$1' is not a repo URL (tags are not used: the newest version is always loaded)"
		URL=$1
	   else rl_die 2 "too many arguments (tags are not used: the newest version is always loaded)"; fi ;;
	esac; shift
done
[ -n "$UNIT" ] || rl_die 2 "usage: repo add [options] NAME [URL]"
rl_valid_name "$UNIT" || rl_die 2 "bad unit name '$UNIT'"
rl_root "$DIR"; rl_init_tmp; rl_catalog_check
rl_base_list | grep -x -q -- "$UNIT" && rl_die 2 "$UNIT is part of the base repo; it is always present"
[ -z "$URL" ] || rl_valid_url "$URL" || rl_die 2 "unacceptable repo URL '$URL' (use https://, ssh://, git@host:path, file:// or a path)"

# the new repo list
if [ -f "$LIST_FILE" ]; then cp "$LIST_FILE" "$RL_TMP/old"
else printf '# project.repos: the units of this project, one per line:  <unit> [via=<unit>,..]\n# owned by the repo unit tools; change it with "repo add" / "repo remove".\n' > "$RL_TMP/old"; fi
if rl_list_entries | awk -F'\t' -v u="$UNIT" '$1==u{f=1} END{exit !f}'; then
	echo "$UNIT is listed already: its entry is replaced"
fi
awk -v u="$UNIT" '
	{ line=$0; c=""; i=index(line,"#"); if (i) { c=substr(line,i); line=substr(line,1,i-1) }
	  n=split(line,f," ")
	  if (n>=1 && f[1]==u) { if (!seen) print u (c!="" ? "\t" c : ""); seen=1; next }
	  print $0 }
	END { if (!seen) print u }' "$RL_TMP/old" > "$RL_TMP/new"
# the new private.units
if [ -f "$PRIV_FILE" ]; then cp "$PRIV_FILE" "$RL_TMP/pold"; HAD_PRIV=1
else printf '# private.units: repo URLs of units that are not in the public catalog, one per line:  <unit> <repo URL>\n# change it with "repo add NAME URL", or by hand.\n' > "$RL_TMP/pold"; HAD_PRIV=0; fi
if [ -n "$URL" ]; then
	awk -v u="$UNIT" -v url="$URL" '
		{ line=$0; c=""; i=index(line,"#"); if (i) { c=substr(line,i); line=substr(line,1,i-1) }
		  n=split(line,f," ")
		  if (n>=1 && f[1]==u) { if (!seen) print u "\t" url (c!="" ? "\t" c : ""); seen=1; next }
		  print $0 }
		END { if (!seen) print u "\t" url }' "$RL_TMP/pold" > "$RL_TMP/pnew"
else cp "$RL_TMP/pold" "$RL_TMP/pnew"; fi

FU=$(rl_tool fetch-units)
# before: what the project resolves to now (to show what is new)
# shellcheck disable=SC2086
"$FU" --dry-run --porcelain --no-update --root "$ROOT" --list "$RL_TMP/old" --private "$RL_TMP/pold" $RARGS > "$RL_TMP/before" 2>/dev/null
# the check (probe clones what is not in the tree)
echo "checking $UNIT${URL:+  <- $URL (private)} ..."
# shellcheck disable=SC2086
if ! "$FU" --dry-run --porcelain --no-update --root "$ROOT" --list "$RL_TMP/new" --private "$RL_TMP/pnew" $RARGS > "$RL_TMP/after" 2> "$RL_TMP/after.err"; then
	cat "$RL_TMP/after.err" >&2
	echo "repo-add: NOT added: the check failed; the repo list, private.units and the tree are unchanged." >&2
	exit 1
fi
echo "check ok; the project resolves to (dependencies first):"
awk -F'\t' '$1=="ORDER"{ printf "  %-12s %-10s %-14s %s\n", $2, $3, ($4=="present" ? "(in tree)" : "(to be cloned)"), $6 }' "$RL_TMP/after"
awk -F'\t' '$1=="ORDER"{print $2}' "$RL_TMP/before" | sort > "$RL_TMP/b"
awk -F'\t' '$1=="ORDER"{print $2}' "$RL_TMP/after"  | sort > "$RL_TMP/a"
newdeps=$(comm -13 "$RL_TMP/b" "$RL_TMP/a" | grep -vx -- "$UNIT" | tr '\n' ' ')
[ -z "$newdeps" ] || echo "pulled in as dependencies: $newdeps"
if [ "$DRY" = 1 ]; then echo "(dry run: nothing changed)"; exit 0; fi

rl_present_units > "$RL_TMP/present.before"
[ -z "$URL" ] || rl_write_private "$RL_TMP/pnew" || rl_die 1 "cannot write $PRIV_FILE"
rl_write_list "$RL_TMP/new" || rl_die 1 "cannot write $LIST_FILE"
[ -z "$URL" ] || echo "$PRIV_FILE: $UNIT recorded"
echo "$LIST_FILE: $UNIT recorded"
if [ "$NOFETCH" = 1 ]; then echo "run: repo update    to clone it"; exit 0; fi
# shellcheck disable=SC2086
if ! "$FU" --root "$ROOT" --list "$LIST_FILE" --private "$PRIV_FILE" $RARGS; then
	echo "repo-add: the fetch failed; restoring the repo list" >&2
	rl_write_list "$RL_TMP/old"
	if [ -n "$URL" ]; then
		if [ "$HAD_PRIV" = 1 ]; then rl_write_private "$RL_TMP/pold"; else rm -f "$PRIV_FILE"; fi
	fi
	rl_present_units > "$RL_TMP/present.after"
	for d in $(comm -13 "$RL_TMP/present.before" "$RL_TMP/present.after"); do
		moved=$(rl_backup_dir "$d") && echo "  $d/ (new) moved to $moved" >&2
	done
	exit 1
fi
exit 0
