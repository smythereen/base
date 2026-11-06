#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo rebuilt [--root DIR]
#
# Say that the full rebuild is done: removes the marker .rebuild-needed that "repo add",
# "repo remove", "repo fetch" and "repo update" write in the project root when a unit was
# cloned, removed or changed version.  Run it after:  HOME=<project> make cleanup && make
RL_PROG=repo-rebuilt
. "$(dirname "$0")/repo-lib.sh" 2>/dev/null || . "$(dirname "$0")/repo-lib"
DIR=
while [ $# -gt 0 ]; do
	case $1 in
	--root) DIR=$2; shift ;;
	-h|--help) sed -n '5,/^RL_PROG/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	*) rl_die 2 "unknown argument $1" ;;
	esac; shift
done
rl_root "$DIR"
if [ -f "$MARK_FILE" ]; then
	rm -f "$MARK_FILE" && echo "full rebuild recorded as done ($MARK_FILE removed)"
else echo "no full rebuild was pending"; fi
