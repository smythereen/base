#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo units [--make | --sh | --list] [--root DIR]
#
# Print the UNITS of the project: the unit directories that are in the tree and have a
# makefile, in dependency order (the base units first, then every unit after the units it
# requires).  Only the tree is read: nothing is fetched.
#
#   --list   one name per line (default)
#   --make   the one line  UNITS := a b c   that the master makefile writes to units.mak
#            and includes (make restarts itself when that file changes)
#   --sh     the same as  UNITS="a b c"; export UNITS   for a shell profile
#
# ~/.bash_profile should read UNITS from units.mak (see env.example), so the shell and
# make always agree.
RL_PROG=repo-units
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
FMT=list; DIR=
while [ $# -gt 0 ]; do
	case $1 in
	--list) FMT=list ;;
	--make) FMT=make ;;
	--sh) FMT=sh ;;
	--root) DIR=$2; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
rl_root "$DIR"; rl_init_tmp
"$(rl_tool repo-order)" --present --root "$ROOT" > "$RL_TMP/order" || exit $?
: > "$RL_TMP/units"
while read -r u; do
	[ -f "$ROOT/$u/makefile" ] || [ -f "$ROOT/$u/Makefile" ] && printf '%s\n' "$u" >> "$RL_TMP/units"
done < "$RL_TMP/order"
case $FMT in
list) cat "$RL_TMP/units" ;;
make) printf '# units.mak: written by the master makefile (repo units --make); do not edit.\n'
      printf 'UNITS := %s\n' "$(tr '\n' ' ' < "$RL_TMP/units" | sed 's/ *$//')" ;;
sh)   printf 'UNITS="%s"; export UNITS\n' "$(tr '\n' ' ' < "$RL_TMP/units" | sed 's/ *$//')" ;;
esac
