#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo - manage the units of a whole project (one git repo per unit).
#
#   repo list                       the project's units: where each one is from, why it is there
#   repo add NAME [URL]             add a unit: public ones are found in the catalog; with URL
#                                   it is a private unit (recorded in private.units); check,
#                                   clone, record, add its dependencies
#   repo remove [--force] NAME      remove a unit: refuses if another unit needs it; the
#                                   directory is moved to .old, not deleted
#   repo fetch [options]            clone the units of the list and what they need
#   repo update [-n] [unit..]       bring the units to their newest version, then say whether
#                                   a full rebuild is needed
#   repo status [options]           version, dirty, ahead/behind of every unit
#   repo order [options]            the units in dependency order
#   repo url NAME                   the repo URL of a unit (private.units, else the catalog)
#   repo rebuilt                    clear the "full rebuild needed" marker after rebuilding
#   repo purge [--keep N] [--dry-run]   delete old backups from the .old/ directories
#   repo units [--make|--sh|--list]     the UNITS of the tree (units with a makefile, dependency
#                                       order): what the master makefile writes to units.mak
#   repo fetch --project NAME       a project with no list yet: take the list of project NAME from
#                                   the project worker ($PROJECT_WORKER_URL); NONE is the starter
#                                   list of a new project.  --list-only writes only the list
#
# The project's own files are in the project root, NOT in repo/ (this unit is a public repo
# shared by all projects): project.repos (the units), project.repos.lock (what was cloned),
# private.units (URLs of units that are not in the catalog), .rebuild-needed (marker).
# The catalog is the worker at $UNITS_CATALOG_URL.
# "repo <command> --help" tells more.  Every unit repo REQUIRES the base repo to be
# installed first; the commands refuse to run in a tree without it.
# This is the only command that does not source repo-lib.
d=$(dirname "$0")
cmd=${1:-help}
[ $# -gt 0 ] && shift
case $cmd in
fetch)	t=fetch-units ;;
url)	t=fetch-units; set -- --lookup "$@" ;;
update|status|add|remove|order|list|purge|rebuilt|units)	t=repo-$cmd ;;
-h|--help|help)	sed -n '5,/^# "repo <command>/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
*)	echo "repo: unknown command '$cmd' (try: repo help)" >&2; exit 2 ;;
esac
if [ -x "$d/$t.sh" ]; then exec "$d/$t.sh" "$@"; else exec "$d/$t" "$@"; fi
