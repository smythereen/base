#!/bin/bash
# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# Atomic per-header bindgen helper used by targets.mak.
# Usage: bindgen-header.sh <header.h> <output.rs> <depfile> <optstamp> -- [clang-args...]
# Environment: BINDGEN, BINDGEN_FLAGS, RS_BINDGEN (auto|off|required)
set -euo pipefail

if [[ $# -lt 4 ]]; then
	echo "usage: $0 header.h output.rs depfile optstamp -- [clang-args...]" >&2
	exit 2
fi

hdr=$1
out=$2
dep=$3
optstamp=$4
shift 4
if [[ "${1:-}" == "--" ]]; then
	shift
fi
clang_args=("$@")

bindgen_bin=${BINDGEN:-bindgen}
mode=${RS_BINDGEN:-auto}
flags=${BINDGEN_FLAGS:-}

if [[ "$mode" == "off" ]]; then
	exit 0
fi

if ! command -v "$bindgen_bin" >/dev/null 2>&1; then
	if [[ "$mode" == "required" ]]; then
		echo "error: bindgen not found (RS_BINDGEN=required); install bindgen-cli or set BINDGEN=" >&2
		exit 1
	fi
	exit 0
fi

owned="${out}.bindgen"
if [[ -e "$out" && ! -f "$owned" ]]; then
	echo "error: refusing to overwrite handwritten binding '$out' (no ${owned} sidecar)." >&2
	echo "       Remove/rename it, or let make header own generated files only." >&2
	exit 1
fi

outdir=$(dirname "$out")
mkdir -p "$outdir"
tmp="${out}.tmp.$$"
dep_tmp="${dep}.tmp.$$"

cleanup() {
	rm -f "$tmp" "$dep_tmp"
}
trap cleanup EXIT

set +e
# shellcheck disable=SC2086
"$bindgen_bin" "$hdr" -o "$tmp" --depfile "$dep_tmp" $flags -- "${clang_args[@]}"
bg_rc=$?
set -e

if [[ $bg_rc -ne 0 ]]; then
	echo "error: bindgen failed for '$hdr' (leaving existing '$out' untouched)." >&2
	if [[ "$mode" == "required" ]]; then
		exit 1
	fi
	if [[ -f "$out" ]]; then
		touch -r "$hdr" "$out" || true
	fi
	exit 0
fi

if [[ -f "$dep_tmp" ]]; then
	python3 -c 'import pathlib,sys; t,d,a,b=sys.argv[1:5]; pathlib.Path(d).write_text(pathlib.Path(t).read_text().replace(a,b))' \
		"$dep_tmp" "$dep" "$tmp" "$out"
else
	printf '%s: %s\n' "$out" "$hdr" > "$dep"
fi

opt_txt="$bindgen_bin $flags -- ${clang_args[*]}"
printf '%s\n' "$opt_txt" > "${owned}.opts"
printf 'generated-by=unit-mak-bindgen\n' > "$owned"
mv -f "$tmp" "$out"
trap - EXIT
rm -f "$dep_tmp"
exit 0
