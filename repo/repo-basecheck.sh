#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# add-base-check.sh unit-makefile ... - insert templates/base-check.mak in front of the
# "include ../rules.mak" line, so that make stops at once with a clear message when the
# base repo is not installed.  Idempotent; keeps the old file as <file>.orig.
here=$(cd "$(dirname "$0")/.." && pwd)
snippet=$here/templates/base-check.mak
[ -f "$snippet" ] || { echo "add-base-check.sh: no $snippet" >&2; exit 2; }
rc=0
for f in "$@"; do
	if grep -q 'REQUIRES the base repo' "$f"; then echo "$f: already has the base check"; continue; fi
	if ! grep -q '^include[[:space:]]*\.\./rules\.mak' "$f"; then echo "$f: no 'include ../rules.mak' line; not changed" >&2; rc=1; continue; fi
	cp -p "$f" "$f.orig" || { rc=1; continue; }
	awk -v snip="$snippet" '
		!done && /^include[ \t]*\.\.\/rules\.mak/ { while ((getline l < snip) > 0) print l; print ""; done=1 }
		{ print }' "$f.orig" > "$f" && echo "$f: base check added"
done
exit $rc
