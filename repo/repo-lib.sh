# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# repo-lib.sh - shared shell functions of the repo tools (sourced, POSIX sh).
# Installed into the project bin as "repo-lib" (the unit rules drop the .sh).

unset CDPATH
RL_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

rl_die()  { c=$1; shift; printf '%s: %s\n' "${RL_PROG:-repo}" "$*" >&2; exit "$c"; }
rl_warn() { printf '%s: warning: %s\n' "${RL_PROG:-repo}" "$*" >&2; }

# rl_tool NAME - path of a sibling tool, whether it is still NAME.sh (in the repo
# unit directory) or installed as NAME (in the project bin)
rl_tool() { if [ -f "$RL_DIR/$1.sh" ]; then printf '%s' "$RL_DIR/$1.sh"; else printf '%s' "$RL_DIR/$1"; fi; }

# rl_root [DIR] - set ROOT to the project tree: DIR, else the parent of the directory
# this tool lives in (repo/ or bin/), else the current directory.  It must hold BASE.
rl_root() {
	if [ -n "${1:-}" ]; then ROOT=$1
	elif [ -f "$RL_DIR/../BASE" ]; then ROOT=$RL_DIR/..
	else ROOT=.; fi
	ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || rl_die 2 "no such project directory"
	[ -f "$ROOT/BASE" ] && [ -f "$ROOT/rules.mak" ] && [ -f "$ROOT/base.units" ] ||
		rl_die 2 "the base repo is not installed in $ROOT (BASE, rules.mak or base.units missing).
        Every unit repo REQUIRES the base repo installed first; see README.md."
	# the project's own files live in the project root, never in repo/ (the repo unit is a
	# public repo shared by every project and must never commit a project's lists)
	LIST_FILE=${REPO_LIST:-$ROOT/project.repos}
	PRIV_FILE=${PRIVATE_UNITS:-$ROOT/private.units}
	MARK_FILE=$ROOT/.rebuild-needed
}

# rl_valid_name NAME
rl_valid_name() { case $1 in ''|-*|.*|*[!A-Za-z0-9_.-]*) return 1 ;; esac; return 0; }

# rl_base_list - the base units, one per line, sorted
rl_base_list() { sed 's/#.*//' "$ROOT/base.units" | awk 'NF{print $1}' | sort -u; }

# rl_present_units - directories in the tree that hold a makefile and are not base units
rl_present_units() {
	rl_base_list > "$RL_TMP/base.list"
	for d in "$ROOT"/*/; do
		d=${d%/}; d=${d##*/}
		{ [ -f "$ROOT/$d/makefile" ] || [ -f "$ROOT/$d/Makefile" ]; } || continue
		grep -x -q -- "$d" "$RL_TMP/base.list" && continue
		printf '%s\n' "$d"
	done | sort
}

# rl_list_entries - the repo list entries, one per line, tab separated:
#     unit  via(- for a unit you asked for)
rl_list_entries() {
	[ -f "$LIST_FILE" ] || return 0
	sed 's/#.*//' "$LIST_FILE" | awk 'NF{ v=$2; sub(/^via=/,"",v); if (v=="") v="-"; printf "%s\t%s\n", $1,v }'
}

# rl_private_url UNIT - the URL the project's private.units gives for UNIT (empty if none)
rl_private_url() {
	[ -f "$PRIV_FILE" ] || return 0
	sed 's/#.*//' "$PRIV_FILE" | awk -v u="$1" '$1==u{print $2; exit}'
}

# rl_catalog_check - the catalog base URL must be http(s):// or file://
rl_catalog_check() {
	[ -z "${UNITS_CATALOG_URL:-}" ] && return 0
	case $UNITS_CATALOG_URL in http://*|https://*|file://*) ;; *) rl_die 2 "UNITS_CATALOG_URL must start with https://, http:// or file://" ;; esac
	UNITS_CATALOG_URL=${UNITS_CATALOG_URL%/}; export UNITS_CATALOG_URL
}

# rl_valid_url URL - same rule as fetch-units: no option look-alikes, no ext:: helpers
rl_valid_url() {
	case $1 in
	*::*|-*|*[[:space:]]*) return 1 ;;
	https://*|http://*|ssh://*|git://*|file://*|git@*:*|/*|./*|../*) return 0 ;;
	esac
	return 1
}

# rl_backup_dir UNIT - move the unit directory to $ROOT/.old/UNIT.YYYYMMDD-HHMMSS (never
# deletes anything); prints the new place
rl_backup_dir() {
	mkdir -p "$ROOT/.old" || return 1
	b=$ROOT/.old/$1.$(date +%Y%m%d-%H%M%S)
	[ -e "$b" ] && b=$b.$$
	mv "$ROOT/$1" "$b" && printf '%s' "$b"
}

# rl_git_state UNIT - sets ST_NOW (tag, branch or short sha), ST_DIRTY (0/1),
# ST_AHEAD, ST_BEHIND (numbers, or "-" without an upstream)
rl_git_state() {
	d=$ROOT/$1
	ST_NOW=; ST_DIRTY=0; ST_AHEAD=-; ST_BEHIND=-
	git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || { ST_NOW='(not git)'; return 1; }
	ST_NOW=$(git -C "$d" describe --tags --exact-match HEAD 2>/dev/null) ||
	ST_NOW=$(git -C "$d" symbolic-ref --short -q HEAD 2>/dev/null) ||
	ST_NOW=$(git -C "$d" rev-parse --short HEAD 2>/dev/null) || ST_NOW='(no commits)'
	# untracked files (build output) are not local changes: only edited tracked files make a unit dirty
	[ -n "$(git -C "$d" status --porcelain --untracked-files=no 2>/dev/null)" ] && ST_DIRTY=1
	if cnt=$(git -C "$d" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
		ST_BEHIND=${cnt%%[[:space:]]*}; ST_AHEAD=${cnt##*[[:space:]]}
	fi
	return 0
}

# rl_newest_ref DIR - the newest version tag of the unit checkout (v1.10 after v1.9), empty
# when the repo has no version tags (then the head of the default branch is "newest")
rl_newest_ref() { git -C "$1" tag --list --sort=-v:refname 2>/dev/null | grep -E '^v?[0-9]' | sed -n 1p; }

# rl_mark_rebuild REASON UNIT... - note in $MARK_FILE that units changed, so the whole
# tree needs a full rebuild (a newer unit may change headers other units were built against).
# "repo rebuilt" removes the marker.
rl_mark_rebuild() {
	r=$1; shift
	for u in "$@"; do printf '%s %s %s\n' "$(date +%Y%m%d-%H%M%S)" "$u" "$r" >> "$MARK_FILE"; done
}
rl_rebuild_hint() {
	echo "== FULL REBUILD NEEDED: unit versions changed ($*)."
	echo "   run:  cd $ROOT && HOME=$ROOT make cleanup && HOME=$ROOT make     then:  repo rebuilt"
}

# rl_resolve [fetch-units options] - run the resolver without touching the tree and
# leave its machine readable output in $RL_TMP/resolve (stderr in $RL_TMP/resolve.err);
# returns fetch-units' exit status
rl_resolve() {
	"$(rl_tool fetch-units)" --dry-run --porcelain --no-update --root "$ROOT" --list "$LIST_FILE" --private "$PRIV_FILE" "$@" > "$RL_TMP/resolve" 2> "$RL_TMP/resolve.err"
}

rl_init_tmp() { RL_TMP=$(mktemp -d "${TMPDIR:-/tmp}/repo.XXXXXX") || exit 2; trap 'rm -rf "$RL_TMP"' EXIT HUP INT TERM; }

# rl_write_list FILE / rl_write_private FILE - atomically replace the repo list / private.units
rl_write_list() { cp "$1" "$LIST_FILE.new" && mv "$LIST_FILE.new" "$LIST_FILE"; }
rl_write_private() { cp "$1" "$PRIV_FILE.new" && mv "$PRIV_FILE.new" "$PRIV_FILE"; }
