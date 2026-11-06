#!/bin/sh
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# fetch-units.sh - clone/update the units of the project's repo list, and, transitively,
# the units they need, into this project tree (one git repo per unit).
#
#   Usage: fetch-units.sh [options]
#
#   The project's own files live in the PROJECT ROOT (never in repo/, which is a public
#   repo shared by all projects):
#     project.repos   one unit per line:   <unit> [via=<unit>,<unit>]
#                     no via=: a unit you asked for (see "repo add"); via=: added by this
#                     script because those units require it, re-computed on every real run.
#     private.units   one unit per line:   <unit> <repo URL>
#                     units that are not in the public catalog (private units, forks).
#
#   Where the repo URL of a unit that is not in the tree yet comes from: private.units,
#   else the catalog worker (GET $UNITS_CATALOG_URL/units/<unit> -> JSON with a "url"
#   field; the top-level one when jq is installed, else the first in the text).  A unit found in neither is an error: add it by hand to private.units.
#
#   Versions: one git version and one directory per unit.  A unit is always taken at its
#   newest version tag (v1.10 is newer than v1.9), or the head of its default branch when
#   it has no version tags; newer versions must stay backward compatible.  When any unit
#   was cloned or changed version, the tree needs a FULL REBUILD: this script says so and
#   writes the marker .rebuild-needed in the project root (remove it with: repo rebuilt).
#
#   -n, --dry-run        do not touch the tree or the list: print the resolution order
#   --list FILE          the repo list (default: $REPO_LIST or <project>/project.repos)
#   --private FILE       private.units (default: $PRIVATE_UNITS or <project>/private.units)
#   --root DIR           the project tree (default: the parent of this script's directory)
#   --catalog URL        catalog base URL (default: $UNITS_CATALOG_URL); https://, http://
#                        or file:// (a directory with units/<name> files, for tests)
#   --lookup UNIT        only print the repo URL of UNIT (private.units, else catalog)
#   --deps-dir DIR       dry-run only: read DIR/X.deps (or DIR/X/UNIT.deps) for units
#                        that are not in the tree, instead of probe-cloning them
#   --with-optional      also fetch the "optional" units named in UNIT.deps files
#   --no-update          leave units that are already in the tree untouched
#   --project NAME       the project has no repo list yet: download the list of project NAME
#                        from the project worker ($PROJECT_WORKER_URL, GET <worker>/projects/NAME,
#                        a plain text list in the project.repos format) into project.repos, then
#                        fetch as usual.  NAME NONE is the starter list that a brand new project
#                        starts from.  Refuses to overwrite an existing list.  With --dry-run
#                        the list is shown and nothing is written.
#   --list-only          with --project: write the list and stop (no cloning); "make populate"
#                        then adds the units one by one with "repo add"
#   --no-record          do not rewrite the dependency entries of the repo list
#   --porcelain          machine readable result on stdout (used by the other repo tools):
#                        tab separated ORDER/UNUSED lines
#   -v, --verbose        say more
#   -h, --help           this text
#
#   Environment: UNITS_CATALOG_URL, PROJECT_WORKER_URL, REPO_LIST, PRIVATE_UNITS,
#                BASE_REPO_URL (only for the "base missing" text)
#
#   Exit status: 0 ok, 1 a unit is missing or could not be fetched,
#                2 usage error or the base repo is not installed,
#                3 dependency cycle between non-base units.
#
# The base repo must be installed first: this script refuses to run in a tree that lacks
# rules.mak, targets.mak, makefile, BASE and base.units.  Units listed in base.units
# belong to the base repo and are never fetched.
#
# POSIX sh only (needs git, curl, tsort, sed, awk, mktemp, sort -V; jq is used if present).

PROG=fetch-units.sh
unset CDPATH
# never let git run helper programs named by a URL (ext::...)
GIT_ALLOW_PROTOCOL=file:git:http:https:ssh; export GIT_ALLOW_PROTOCOL
ROOT=
LIST=${REPO_LIST:-}
PRIV=${PRIVATE_UNITS:-}
CATALOG=${UNITS_CATALOG_URL:-}
LOOKUP=
DRY=0
UPDATE=1
OPTIONAL=0
VERBOSE=0
RECORD=1
PORCELAIN=0
DEPS_DIR=
PROJECT=
LISTONLY=0
WORKER=${PROJECT_WORKER_URL:-}
BASE_REPO_URL=${BASE_REPO_URL:-https://github.com/<owner>/base}

die() { code=$1; shift; printf '%s: %s\n' "$PROG" "$*" >&2; exit "$code"; }
say() { [ "$PORCELAIN" = 1 ] || printf '%s\n' "$*"; return 0; }
vsay() { [ "$VERBOSE" = 1 ] && [ "$PORCELAIN" = 0 ] && printf '%s\n' "$*"; return 0; }
warn() { printf '%s: warning: %s\n' "$PROG" "$*" >&2; }
usage() { sed -n '4,/^# POSIX sh only/p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
	case $1 in
	-n|--dry-run)	DRY=1 ;;
	--list)		[ $# -ge 2 ] || die 2 "--list needs a file"; LIST=$2; shift ;;
	--private)	[ $# -ge 2 ] || die 2 "--private needs a file"; PRIV=$2; shift ;;
	--root)		[ $# -ge 2 ] || die 2 "--root needs a directory"; ROOT=$2; shift ;;
	--catalog)	[ $# -ge 2 ] || die 2 "--catalog needs a URL"; CATALOG=$2; shift ;;
	--lookup)	[ $# -ge 2 ] || die 2 "--lookup needs a unit name"; LOOKUP=$2; shift ;;
	--deps-dir)	[ $# -ge 2 ] || die 2 "--deps-dir needs a directory"; DEPS_DIR=$2; shift ;;
	--with-optional) OPTIONAL=1 ;;
	--no-update)	UPDATE=0 ;;
	--project)	[ $# -ge 2 ] || die 2 "--project needs a project name"; PROJECT=$2; shift ;;
	--list-only)	LISTONLY=1 ;;
	--worker)	[ $# -ge 2 ] || die 2 "--worker needs a URL"; WORKER=$2; shift ;;
	--no-record)	RECORD=0 ;;
	--porcelain)	PORCELAIN=1 ;;
	-v|--verbose)	VERBOSE=1 ;;
	-h|--help)	usage; exit 0 ;;
	*)		die 2 "unknown argument $1 (try --help)" ;;
	esac
	shift
done

if [ -z "$ROOT" ]; then
	here=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
	if [ -f "$here/../BASE" ]; then ROOT=$here/..; else ROOT=.; fi
fi
ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || die 2 "no such project directory: $ROOT"
if [ -n "$CATALOG" ]; then
	case $CATALOG in http://*|https://*|file://*) ;; *) die 2 "the catalog URL must start with https://, http:// or file://" ;; esac
	CATALOG=${CATALOG%/}
fi

# ---------------------------------------------------------------------------
# 1. The base repo must be here (fail early, with a clear message)
# ---------------------------------------------------------------------------

missing=
for f in rules.mak targets.mak makefile BASE base.units; do
	[ -f "$ROOT/$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then
	cat >&2 <<MSG
$PROG: the base repo is not installed in $ROOT
        missing:$missing
        Every unit repo REQUIRES the base repo installed first.  Do:

            git clone $BASE_REPO_URL <project-dir>
            cd <project-dir>
            export UNITS_CATALOG_URL=<catalog worker URL>
            repo/repo.sh add <unit>          # public unit: its URL comes from the catalog
            repo/repo.sh add <unit> <URL>    # private unit: recorded in private.units
            repo/fetch-units.sh

MSG
	exit 2
fi
BASE_FORMAT=$(sed -n 's/^base-format:[[:space:]]*//p' "$ROOT/BASE" | sed -n 1p)
BASE_VERSION=$(sed -n 's/^base-version:[[:space:]]*//p' "$ROOT/BASE" | sed -n 1p)
case $BASE_FORMAT in ''|*[!0-9]*) die 2 "$ROOT/BASE has no valid 'base-format: N' line" ;; esac
[ -n "$LIST" ] || LIST=$ROOT/project.repos
[ -n "$PRIV" ] || PRIV=$ROOT/private.units
MARK=$ROOT/.rebuild-needed

WORK=$(mktemp -d "${TMPDIR:-/tmp}/fetch-units.XXXXXX") || die 2 "cannot create a temporary directory"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/seen" "$WORK/probe" "$WORK/url" "$WORK/via" "$WORK/cat"
: > "$WORK/queue"; : > "$WORK/edges"; : > "$WORK/optedges"; : > "$WORK/errors"; : > "$WORK/order.tags"; : > "$WORK/changed"

sed 's/#.*//' "$ROOT/base.units" | awk 'NF{print $1}' | sort -u > "$WORK/base.list"
is_base() { grep -x -q -- "$1" "$WORK/base.list"; }
while read -r bu; do
	[ -d "$ROOT/$bu" ] || die 2 "base repo is incomplete: base unit '$bu' (base.units) has no directory $ROOT/$bu"
done < "$WORK/base.list"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

valid_name() { case $1 in ''|-*|.*|*[!A-Za-z0-9_.-]*) return 1 ;; esac; return 0; }
valid_url() {
	case $1 in
	*::*|-*|*[[:space:]]*) return 1 ;;
	https://*|http://*|ssh://*|git://*|file://*|git@*:*|/*|./*|../*) return 0 ;;
	esac
	return 1
}
# a URL the catalog hands out: network schemes only (file:// and paths only from a file:// catalog)
valid_catalog_url() {
	case $1 in
	*::*|-*|*[[:space:]]*) return 1 ;;
	https://*|http://*|ssh://*|git://*|git@*:*) return 0 ;;
	file://*|/*|./*|../*) case $CATALOG in file://*) return 0 ;; esac ;;
	esac
	return 1
}
err() { printf '%s\n' "$*" >> "$WORK/errors"; printf '%s: error: %s\n' "$PROG" "$*" >&2; }

# newest version tag of a checkout / of a remote repo (empty: no version tags)
newest_ref() { git -C "$1" tag --list --sort=-v:refname 2>/dev/null | grep -E '^v?[0-9]' | sed -n 1p; }
remote_newest_tag() {
	git ls-remote --tags -- "$1" 2>/dev/null | sed -n 's#^[0-9a-f]*[[:space:]]refs/tags/\(.*\)$#\1#p' |
		grep -v '\^{}$' | grep -E '^v?[0-9]' | sort -V | sed -n '$p'
}
version_of() { git -C "$1" describe --tags --exact-match HEAD 2>/dev/null || echo -; }

# catalog_lookup UNIT - ask the catalog worker for the repo URL; sets CAT_URL.
# Returns 0 found, 1 not in the catalog, 2 no catalog configured, 3 catalog trouble (CAT_ERR).
CAT_URL=; CAT_ERR=
catalog_lookup() {
	CAT_URL=; CAT_ERR=
	if [ -f "$WORK/cat/$1.url" ]; then CAT_URL=$(cat "$WORK/cat/$1.url"); return 0; fi
	[ ! -f "$WORK/cat/$1.no" ] || return 1
	[ -n "$CATALOG" ] || return 2
	code=$(curl -s --max-time 20 --proto '=http,https,file' -o "$WORK/cat.body" -w '%{http_code}' "$CATALOG/units/$1" 2>"$WORK/cat.err"); rc=$?
	case $CATALOG in
	file://*)	if [ "$rc" = 37 ]; then : > "$WORK/cat/$1.no"; return 1; fi
			[ "$rc" = 0 ] || { CAT_ERR="catalog lookup failed (curl exit $rc)"; return 3; } ;;
	*)		if [ "$rc" = 0 ] && [ "$code" = 404 ]; then : > "$WORK/cat/$1.no"; return 1; fi
			[ "$rc" = 0 ] || { CAT_ERR="catalog $CATALOG not reachable (curl exit $rc)"; return 3; }
			[ "$code" = 200 ] || { CAT_ERR="catalog answered HTTP $code for $1"; return 3; } ;;
	esac
	# the top-level "url" string (jq when it is installed; else the first "url": "..." in the text)
	if command -v jq >/dev/null 2>&1; then cu=$(jq -r 'if type=="object" and (.url|type)=="string" then .url else empty end' "$WORK/cat.body" 2>/dev/null)
	else cu=$(sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WORK/cat.body" | sed -n 1p | sed 's#\\/#/#g'); fi
	[ -n "$cu" ] || { CAT_ERR="the catalog answer for $1 has no \"url\" field"; return 3; }
	valid_catalog_url "$cu" || { CAT_ERR="the catalog gave an unacceptable repo URL for $1"; return 3; }
	printf '%s\n' "$cu" > "$WORK/cat/$1.url"; CAT_URL=$cu
	return 0
}

# the private.units file
if [ -f "$PRIV" ]; then
	sed 's/#.*//' "$PRIV" | awk 'NF' > "$WORK/priv.data"
	while read -r pu purl prest; do
		valid_name "$pu" || die 2 "$PRIV: bad unit name '$pu'"
		valid_url "$purl" || die 2 "$PRIV: unit '$pu': missing or unacceptable repo URL '$purl' (format: unit URL)"
		[ -z "$prest" ] || die 2 "$PRIV: unit '$pu': too many fields (format: unit URL)"
		[ ! -f "$WORK/url/$pu" ] || die 2 "$PRIV: unit '$pu' is listed twice"
		if is_base "$pu"; then warn "$pu is part of the base repo; ignoring its entry in $PRIV"; continue; fi
		printf '%s\n' "$purl" > "$WORK/url/$pu"
	done < "$WORK/priv.data"
fi

# --lookup UNIT: print the URL and where it came from
if [ -n "$LOOKUP" ]; then
	valid_name "$LOOKUP" || die 2 "bad unit name '$LOOKUP'"
	if [ -f "$WORK/url/$LOOKUP" ]; then cat "$WORK/url/$LOOKUP"; exit 0; fi
	catalog_lookup "$LOOKUP"; rc=$?
	case $rc in
	0) printf '%s\n' "$CAT_URL"; exit 0 ;;
	1) die 1 "unit '$LOOKUP' is not in the catalog and not in $PRIV" ;;
	2) die 1 "unit '$LOOKUP' is not in $PRIV and no catalog is set (UNITS_CATALOG_URL)" ;;
	*) die 1 "$CAT_ERR" ;;
	esac
fi

DEPS_FILE=
STATE=
URL_USED=

# need_url UNIT - set URL_USED for a unit that is not in the tree: private.units first, then
# the catalog.  Anything else is an error that says what to do.
need_url() {
	u=$1; by=$(sed -n 1p "$WORK/via/$u" 2>/dev/null); by=${by:-the repo list}
	if [ -f "$WORK/url/$u" ]; then URL_USED=$(cat "$WORK/url/$u"); return 0; fi
	catalog_lookup "$u"; rc=$?
	case $rc in
	0)	URL_USED=$CAT_URL; return 0 ;;
	1)	err "unit '$u' (needed by $by) is not in the catalog, so it is a private unit: add it by hand with  repo add $u <URL>  (or a line '$u <URL>' in private.units)" ;;
	2)	err "unit '$u' (needed by $by) is not in private.units and no catalog is set: set UNITS_CATALOG_URL for public units, or add it by hand with  repo add $u <URL>" ;;
	*)	err "unit '$u' (needed by $by): $CAT_ERR; if it is a private unit add it by hand with  repo add $u <URL>" ;;
	esac
	return 1
}

obtain() {
	u=$1; DEPS_FILE=; STATE=; URL_USED=
	dir=$ROOT/$u
	if [ -d "$dir" ]; then
		if [ "$DRY" = 0 ] && [ "$UPDATE" = 1 ]; then update_unit "$u" || return 1; fi
		STATE=present
		have=$(git -C "$dir" remote get-url origin 2>/dev/null)
		if [ -f "$WORK/url/$u" ] && [ -n "$have" ] && [ "$have" != "$(cat "$WORK/url/$u")" ]; then
			warn "unit $u: its origin is $have but private.units says $(cat "$WORK/url/$u")"
		fi
		URL_USED=$have
	elif [ "$DRY" = 1 ]; then
		if [ -n "$DEPS_DIR" ] && { [ -f "$DEPS_DIR/$u.deps" ] || [ -f "$DEPS_DIR/$u/UNIT.deps" ]; }; then
			if [ -f "$DEPS_DIR/$u.deps" ]; then DEPS_FILE=$DEPS_DIR/$u.deps; else DEPS_FILE=$DEPS_DIR/$u/UNIT.deps; fi
			STATE=deps-dir
			[ ! -f "$WORK/url/$u" ] || URL_USED=$(cat "$WORK/url/$u")
			return 0
		fi
		need_url "$u" || return 1
		nt=$(remote_newest_tag "$URL_USED")
		if [ -n "$nt" ]; then
			git clone -q --depth 1 --branch "$nt" -- "$URL_USED" "$WORK/probe/$u" 2>"$WORK/gitlog" ||
				{ err "unit '$u' cannot be fetched from $URL_USED: $(tr '\n' ' ' < "$WORK/gitlog")"; return 1; }
		else
			git clone -q --depth 1 -- "$URL_USED" "$WORK/probe/$u" 2>"$WORK/gitlog" ||
				{ err "unit '$u' cannot be fetched from $URL_USED: $(tr '\n' ' ' < "$WORK/gitlog")"; return 1; }
		fi
		dir=$WORK/probe/$u
		STATE=would-clone
	else
		need_url "$u" || return 1
		git clone -q -- "$URL_USED" "$dir" 2>"$WORK/gitlog" ||
			{ err "cannot clone unit '$u' from $URL_USED: $(tr '\n' ' ' < "$WORK/gitlog")"; return 1; }
		nt=$(newest_ref "$dir")
		if [ -n "$nt" ]; then
			git -C "$dir" -c advice.detachedHead=false checkout -q "$nt" 2>"$WORK/gitlog" ||
				{ err "unit '$u': cannot check out its newest version '$nt': $(tr '\n' ' ' < "$WORK/gitlog")"; return 1; }
		fi
		say "  clone    $u  <- $URL_USED  ($(version_of "$dir"))"
		printf '%s cloned\n' "$u" >> "$WORK/changed"
		STATE=cloned
	fi
	[ -f "$dir/UNIT.deps" ] && DEPS_FILE=$dir/UNIT.deps
	CUR_VER=$(version_of "$dir")
	return 0
}

# update_unit UNIT - bring a clean checkout to the newest version
update_unit() {
	u=$1; dir=$ROOT/$u
	if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
		err "$dir exists but is not a git checkout; not touching it"
		return 1
	fi
	# untracked files (*.o *.d .depend, programs: what a build leaves in the unit) do not count as local changes
	if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
		warn "$u has local changes; left as it is"
		return 0
	fi
	oldrev=$(git -C "$dir" rev-parse HEAD 2>/dev/null); oldver=$(version_of "$dir")
	git -C "$dir" fetch -q --tags 2>"$WORK/gitlog" || warn "$u: fetch failed: $(tr '\n' ' ' < "$WORK/gitlog")"
	nt=$(newest_ref "$dir")
	if [ -n "$nt" ]; then
		git -C "$dir" -c advice.detachedHead=false checkout -q "$nt" 2>"$WORK/gitlog" ||
			{ err "unit '$u': cannot check out its newest version '$nt': $(tr '\n' ' ' < "$WORK/gitlog")"; return 1; }
	elif git -C "$dir" symbolic-ref -q HEAD >/dev/null 2>&1; then
		git -C "$dir" pull -q --ff-only 2>/dev/null || warn "$u: could not fast-forward; left as it is"
	fi
	newrev=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
	if [ "$oldrev" != "$newrev" ]; then
		say "  update   $u  $oldver -> $(version_of "$dir")"
		printf '%s updated\n' "$u" >> "$WORK/changed"
	else
		vsay "  current  $u  ($oldver)"
	fi
	return 0
}

enqueue() {	# unit requiredby
	[ -f "$WORK/seen/$1" ] && return 0
	: > "$WORK/seen/$1"
	printf '%s|%s\n' "$1" "$2" >> "$WORK/queue"
}

# ---------------------------------------------------------------------------
# 1b. --project NAME: a project without a repo list gets one from the project worker
#     (NONE = the starter list of a brand new project)
# ---------------------------------------------------------------------------

if [ -n "$PROJECT" ]; then
	valid_name "$PROJECT" || die 2 "bad project name '$PROJECT'"
	[ -n "$WORKER" ] || die 1 "no project worker is set: export PROJECT_WORKER_URL=<project worker URL>  (https://, http:// or file://)"
	case $WORKER in http://*|https://*|file://*) WORKER=${WORKER%/} ;; *) die 2 "the project worker URL must start with https://, http:// or file://" ;; esac
	[ ! -f "$LIST" ] || die 2 "$LIST exists already: --project only starts a project that has no repo list (edit the list, or use repo add)"
	code=$(curl -s --max-time 20 --proto '=http,https,file' -o "$WORK/project.body" -w '%{http_code}' "$WORKER/projects/$PROJECT" 2>"$WORK/project.err"); rc=$?
	case $WORKER in
	file://*)	[ "$rc" = 0 ] || die 1 "the project worker has no project '$PROJECT' (curl exit $rc)" ;;
	*)		[ "$rc" = 0 ] || die 1 "the project worker $WORKER is not reachable (curl exit $rc)"
			[ "$code" != 404 ] || die 1 "the project worker has no project '$PROJECT'"
			[ "$code" = 200 ] || die 1 "the project worker answered HTTP $code for project '$PROJECT'" ;;
	esac
	[ "$(wc -c < "$WORK/project.body")" -le 65536 ] || die 1 "the project list of '$PROJECT' is too large (more than 64 KB)"
	# only "<unit> [via=<unit>,..]" lines and comments are accepted, nothing that could be
	# anything else (URLs belong in private.units, they are never taken from the worker)
	sed 's/#.*//' "$WORK/project.body" | awk 'NF' > "$WORK/project.data"
	[ -s "$WORK/project.data" ] || die 1 "the project list of '$PROJECT' is empty"
	while read -r pu pvia prest; do
		valid_name "$pu" || die 1 "the project list of '$PROJECT' has a bad unit name '$pu'"
		[ -z "$prest" ] || die 1 "the project list of '$PROJECT': unit '$pu': too many fields"
		case $pvia in ''|via=*) ;; *) die 1 "the project list of '$PROJECT': unit '$pu': unknown field '$pvia'" ;; esac
	done < "$WORK/project.data"
	{ printf '# project.repos: the units of this project (one per line: <unit> [via=<unit>,..]).\n'
	  printf '# Started from project %s of the project worker on %s; change it with repo add / repo remove.\n' "$PROJECT" "$(date +%Y-%m-%d)"
	  tr -d '\r' < "$WORK/project.body"; } > "$WORK/project.list"
	if [ "$DRY" = 1 ]; then
		say "== dry run: the list of project $PROJECT from $WORKER would be written to $LIST:"
		sed 's/#.*//' "$WORK/project.list" | awk 'NF{print "     " $0}' | { [ "$PORCELAIN" = 1 ] && cat >/dev/null || cat; }
		LIST=$WORK/project.list
	else
		cp "$WORK/project.list" "$LIST.new" && mv "$LIST.new" "$LIST" || die 1 "cannot write $LIST"
		say "== $LIST: the list of project $PROJECT ($(wc -l < "$WORK/project.data" | tr -d ' ') units) from $WORKER"
	fi
	if [ "$LISTONLY" = 1 ]; then exit 0; fi
fi

# ---------------------------------------------------------------------------
# 2. Read the repo list
# ---------------------------------------------------------------------------

[ -f "$LIST" ] || die 2 "no repo list: $LIST   (a new project: repo fetch --project NONE; else create it with:  repo add <unit> [URL])"

: > "$WORK/roots"
sed 's/#.*//' "$LIST" | awk 'NF' > "$WORK/list.data"
seenlist=
while read -r ru rvia rest; do
	valid_name "$ru" || die 2 "$LIST: bad unit name '$ru'"
	[ -z "$rest" ] || die 2 "$LIST: unit '$ru': too many fields (format: unit [via=unit,..]; URLs belong in private.units, versions are not pinned)"
	case $rvia in ''|via=*) ;; *) die 2 "$LIST: unit '$ru': unknown field '$rvia' (format: unit [via=unit,..]; URLs belong in private.units, versions are not pinned)" ;; esac
	case " $seenlist " in *" $ru "*) die 2 "$LIST: unit '$ru' is listed twice" ;; esac
	seenlist="$seenlist $ru"
	if is_base "$ru"; then warn "$ru is part of the base repo; ignoring its entry in $LIST"; continue; fi
	case $rvia in
	via=*)	: ;;				# derived entry: found again through its requirer
	'')	printf '%s\n' "$ru" >> "$WORK/roots"; enqueue "$ru" "repo list" ;;
	esac
done < "$WORK/list.data"

# ---------------------------------------------------------------------------
# 3. Discover the closure (breadth first), collecting edges "dep unit"
# ---------------------------------------------------------------------------

[ "$DRY" = 1 ] && say "== dry run: nothing in $ROOT will be changed"
say "== base: $ROOT  (base-format $BASE_FORMAT${BASE_VERSION:+, version $BASE_VERSION})"

n=1
while line=$(sed -n "${n}p" "$WORK/queue"); [ -n "$line" ]; do
	n=$((n+1))
	u=${line%%|*}; by=${line#*|}
	valid_name "$u" || { err "bad unit name '$u' (required by $by)"; continue; }
	CUR_VER=-
	if ! obtain "$u"; then
		printf '%s|%s|MISSING|%s|%s\n' "$u" "-" "$by" "$URL_USED" > "$WORK/rec.$u"
		printf '%s %s\n' "$u" "$u" >> "$WORK/edges"
		continue
	fi
	printf '%s|%s|%s|%s|%s\n' "$u" "$CUR_VER" "$STATE" "$by" "$URL_USED" > "$WORK/rec.$u"
	printf '%s %s\n' "$u" "$u" >> "$WORK/edges"		# makes isolated nodes visible to tsort
	if [ -z "$DEPS_FILE" ]; then
		warn "unit $u has no UNIT.deps; assuming it needs only the base repo"
		continue
	fi
	sed 's/#.*//' "$DEPS_FILE" | awk 'NF' > "$WORK/deps.cur"
	while read -r kind name f1 f2 rest; do
		case $kind in
		base)	case $name in ''|*[!0-9]*) err "$u: UNIT.deps: 'base' needs a number"; continue ;; esac
			[ "$name" -le "$BASE_FORMAT" ] ||
				err "unit $u needs base-format $name but this base is $BASE_FORMAT; update the base repo" ;;
		require|optional)
			valid_name "$name" || { err "$u: UNIT.deps: bad unit name '$name'"; continue; }
			[ "$name" = "$u" ] && { err "unit $u requires itself"; continue; }
			is_base "$name" && continue		# satisfied by the base repo
			# a version word is documentation (newest is always loaded); url= is not used
			for fld in $f1 $f2 $rest; do
				case $fld in url=*) warn "$u: UNIT.deps: url= for $name is ignored (URLs come from private.units or the catalog)" ;; esac
			done
			if [ "$kind" = require ] || [ "$OPTIONAL" = 1 ]; then
				printf '%s %s\n' "$name" "$u" >> "$WORK/edges"
				printf '%s\n' "$u" >> "$WORK/via/$name"
				enqueue "$name" "$u"
			else
				printf '%s %s\n' "$name" "$u" >> "$WORK/optedges"
			fi ;;
		system)	vsay "  note     $u needs system package: $name${f1:+ $f1}${f2:+ $f2}${rest:+ $rest}" ;;
		*)	warn "$u: UNIT.deps: unknown directive '$kind' ignored" ;;
		esac
	done < "$WORK/deps.cur"
done

while read -r d u; do
	if [ -f "$WORK/seen/$d" ] && [ -f "$WORK/seen/$u" ]; then printf '%s %s\n' "$d" "$u" >> "$WORK/edges"; fi
done < "$WORK/optedges"

# mark_changed - units cloned or moved to another version: note it (marker file + message),
# even when a later unit failed
mark_changed() {
	[ "$DRY" = 0 ] && [ -s "$WORK/changed" ] || return 0
	cp "$WORK/changed" "$WORK/changed.list"; : > "$WORK/changed"
	while read -r u why; do printf '%s %s %s\n' "$(date +%Y%m%d-%H%M%S)" "$u" "$why" >> "$MARK"; done < "$WORK/changed.list"
	say ""
	say "== units changed: $(awk '{print $1}' "$WORK/changed.list" | tr '\n' ' ')"
	say "== FULL REBUILD NEEDED (a newer unit may change headers the others were built against)."
	say "   run:  cd $ROOT && HOME=$ROOT make cleanup && HOME=$ROOT make     then:  repo rebuilt"
	say "   (marker: $MARK)"
}

# ---------------------------------------------------------------------------
# 4. Order (dependencies first) and cycle detection
# ---------------------------------------------------------------------------

if ! tsort "$WORK/edges" > "$WORK/order" 2> "$WORK/tsort.err"; then
	mark_changed
	say ""
	printf '%s: error: dependency cycle between units (none of them is in the base repo):\n' "$PROG" >&2
	sed -n 's/^tsort: //p' "$WORK/tsort.err" | grep -v 'input contains' | sed 's/^/          /' >&2
	exit 3
fi

say ""
say "== resolution order (dependencies first)"
i=0
while read -r u; do
	i=$((i+1))
	rec=$(cat "$WORK/rec.$u" 2>/dev/null)
	ver=$(printf '%s' "$rec" | cut -d'|' -f2); st=$(printf '%s' "$rec" | cut -d'|' -f3)
	by=$(printf '%s' "$rec" | cut -d'|' -f4); url=$(printf '%s' "$rec" | cut -d'|' -f5)
	if [ "$PORCELAIN" = 1 ]; then
		printf 'ORDER\t%s\t%s\t%s\t%s\t%s\n' "$u" "${ver:--}" "$st" "$by" "${url:--}"
	else
		printf '  %2d. %-12s %-10s %-12s required by: %-12s %s\n' "$i" "$u" "${ver:--}" "[$st]" "$by" "$url"
	fi
done < "$WORK/order"
[ "$i" -gt 0 ] || say "  (no units besides the base repo)"
say ""
say "== provided by the base repo (never fetched): $(tr '\n' ' ' < "$WORK/base.list")"
if [ "$OPTIONAL" = 0 ] && [ -s "$WORK/optedges" ]; then
	skipped=
	while read -r d u; do [ -f "$WORK/seen/$d" ] || skipped="$skipped $d(for $u)"; done < "$WORK/optedges"
	[ -z "$skipped" ] || say "== optional units not selected (add them with: repo add <unit>, or use --with-optional):$skipped"
fi

for d in "$ROOT"/*/; do
	d=${d%/}; d=${d##*/}
	{ [ -f "$ROOT/$d/makefile" ] || [ -f "$ROOT/$d/Makefile" ]; } || continue
	is_base "$d" && continue
	[ -f "$WORK/seen/$d" ] && continue
	[ "$PORCELAIN" = 1 ] && printf 'UNUSED\t%s\n' "$d"
	warn "unit directory '$d' is in the tree but is not in the repo list or needed by it; the root make will still build it"
done

mark_changed

if [ -s "$WORK/errors" ]; then
	say ""
	say "== FAILED: $(wc -l < "$WORK/errors" | tr -d ' ') problem(s):"
	sed 's/^/   /' "$WORK/errors"
	exit 1
fi

# ---------------------------------------------------------------------------
# 5. Record: derived entries of the list, the lock file, the rebuild marker
# ---------------------------------------------------------------------------

if [ "$DRY" = 0 ]; then
	if [ "$RECORD" = 1 ]; then
		# explicit entries and comments stay as they are; derived entries are re-written
		awk '{ l=$0; i=index(l,"#"); if (i) l=substr(l,1,i-1); n=split(l,f," ");
		       if (n>=2 && f[2] ~ /^via=/) next; print $0 }' "$LIST" > "$WORK/list.new"
		while read -r u; do
			grep -x -q -- "$u" "$WORK/roots" && continue
			vias=$(sort -u "$WORK/via/$u" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
			printf '%s\tvia=%s\n' "$u" "$vias" >> "$WORK/list.new"
		done < "$WORK/order"
		if ! cmp -s "$WORK/list.new" "$LIST"; then cp "$WORK/list.new" "$LIST.new" && mv "$LIST.new" "$LIST"; vsay "  recorded dependency entries in $LIST"; fi
	fi
	# the project tree is a clone of the base repo: keep the unit clones out of its git status
	gx=$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null)
	if [ -n "$gx" ]; then
		case $gx in /*) ;; *) gx=$ROOT/$gx ;; esac
		mkdir -p "$(dirname "$gx")"
		while read -r u; do grep -x -q -- "/$u/" "$gx" 2>/dev/null || printf '/%s/\n' "$u" >> "$gx"; done < "$WORK/order"
	fi
	: > "$LIST.lock"
	while read -r u; do
		rev=$(git -C "$ROOT/$u" rev-parse HEAD 2>/dev/null || echo unknown)
		url=$(git -C "$ROOT/$u" remote get-url origin 2>/dev/null || echo -)
		printf '%s %s %s %s\n' "$u" "$url" "$(version_of "$ROOT/$u")" "$rev" >> "$LIST.lock"
		[ -f "$ROOT/$u/makefile" ] || [ -f "$ROOT/$u/Makefile" ] || warn "unit $u has no makefile"
	done < "$WORK/order"
	say "== done; wrote $LIST.lock"
else
	say "== dry run complete"
fi
exit 0
