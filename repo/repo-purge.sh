#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo purge [--keep N] [-n|--dry-run] [--root DIR]
#
# Delete old backups from the .old/ directories of the project: <project>/.old (where
# "repo remove" moves unit directories) and <dir>/.old of every directory of the project
# (backups of files in that unit).  A backup is an entry named  NAME.YYYYMMDD-HHMMSS
# (optionally followed by .PID).  For each NAME in each .old/ the newest N are kept
# (default 1) and the older ones are deleted for good.  --keep 0 deletes every backup.
# Entries whose name has no such timestamp suffix are never touched.
#
#   --keep N      how many of the newest backups of each NAME to keep (default 1)
#   -n, --dry-run show what would be deleted, delete nothing
RL_PROG=repo-purge
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DRY=0; KEEP=1; DIR=
while [ $# -gt 0 ]; do
	case $1 in
	-n|--dry-run) DRY=1 ;;
	--keep) [ $# -ge 2 ] || rl_die 2 "--keep needs a number"; KEEP=$2; shift ;;
	--root) DIR=$2; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
case $KEEP in ''|*[!0-9]*) rl_die 2 "--keep needs a number (0, 1, 2 ...)" ;; esac
rl_root "$DIR"; rl_init_tmp

# every backup: .old directory, name, timestamp key, path
: > "$RL_TMP/all"; skipped=0
for od in "$ROOT/.old" "$ROOT"/*/.old; do
	[ -d "$od" ] && [ ! -L "$od" ] || continue
	for e in "$od"/* "$od"/.[!.]*; do
		[ -e "$e" ] || [ -L "$e" ] || continue
		b=${e##*/}
		k=$(printf '%s' "$b" | sed -n 's/^\(.*\)\.\([0-9]\{8\}-[0-9]\{6\}\(\.[0-9]*\)\{0,1\}\)$/\1	\2/p')
		case $b in *'	'*) k= ;; esac
		if [ -z "$k" ]; then skipped=$((skipped+1)); continue; fi
		printf '%s\t%s\t%s\n' "$od/${k%%	*}" "${k#*	}" "$e" >> "$RL_TMP/all"
	done
done
# per group, newest first; everything after the first KEEP is to be deleted
sort -t '	' -k1,1 -k2,2r "$RL_TMP/all" | awk -F'\t' -v keep="$KEEP" '{ c[$1]++; if (c[$1] > keep) print $3 }' > "$RL_TMP/del"
total=$(wc -l < "$RL_TMP/all" | tr -d ' '); n=$(wc -l < "$RL_TMP/del" | tr -d ' ')
kb=0; gone=0
while IFS= read -r p; do
	[ -n "$p" ] || continue
	case $p in "$ROOT"/.old/*|"$ROOT"/*/.old/*) ;; *) continue ;; esac		# never anything else
	s=$(du -sk -- "$p" 2>/dev/null | awk '{print $1}'); kb=$((kb + ${s:-0}))
	if [ "$DRY" = 1 ]; then echo "would delete ${p#"$ROOT"/}"
	elif rm -rf -- "$p"; then echo "deleted ${p#"$ROOT"/}"; gone=$((gone+1))
	else rl_warn "could not delete $p"; fi
done < "$RL_TMP/del"
if [ "$DRY" = 1 ]; then echo "dry run: $n of $total backups would be deleted (about $kb KB); keeping the newest $KEEP of each"
else echo "$gone of $total backups deleted (about $kb KB); kept the newest $KEEP of each"; fi
[ "$skipped" = 0 ] || echo "($skipped entries without a timestamp suffix were left alone)"
exit 0
