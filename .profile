# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# ~/.profile - the project login's environment (POSIX /bin/sh: sh, dash, ksh, bash).
#
# The base repo is the login directory (ROOT = $HOME), so this file is the project's
# shared developer setup.  bash reads ~/.bash_profile, which sources this file first.
# Every line here must be safe to source again (no duplicate PATH entries).
#
# Personal or secret settings (API keys, tokens, per-user overrides) go in
# ~/.profile.local, which is sourced near the end and is never committed
# (.gitignore).  Never put keys or passwords in this file.
#

#
#	Helpers (unset at the end)
#
#	define    VAR value	set and export VAR
#	def_dir   VAR dir	set and export VAR only when dir exists
#	eliminate VAR dir	remove dir from the : list in VAR
#	prefix    VAR dir	move or add dir to the front of VAR (dir must exist)
#	postfix   VAR dir	move or add dir to the end of VAR (dir must exist)
#
define( ) {
	eval ${1}=\"${2}\" export ${1} ;
}
def_dir( ) {
	[ -z "${2}" ] && return 0
	[ -d "${2}" ] || return 0
	eval ${1}=\"${2}\" export ${1} ;
}
eliminate( ) {
	define	"${1}"	"$(eval	echo	\$"${1}"	|
			sed	-e"s,:${2}:,:,g"	|
			sed	-e"s,:${2}:,:,g"	|
			sed	-e"s,^${2}:,,"		|
			sed	-e"s,:${2}\$,,"		|
			sed	-e"s,^${2}\$,,"		)"
}
prefix( ) {
	[ -z "${2}" ] && return 0
	[ -d "${2}" ] || return 0
	eliminate "${1}" "${2}"
	if [ -z "$(eval echo \$"${1}")" ]
	then	define "${1}" "${2}"
	else	define "${1}" "$(eval echo ${2}:\$"${1}")"
	fi
}
postfix( ) {
	[ -z "${2}" ] && return 0
	[ -d "${2}" ] || return 0
	eliminate "${1}" "${2}"
	if [ -z "$(eval echo \$"${1}")" ]
	then	define "${1}" "${2}"
	else	define "${1}" "$(eval echo \$"${1}":${2})"
	fi
}

#
#	Shell defaults for shared development
#
umask 002 ;					# group-writable files
ulimit -c unlimited 2>/dev/null || true ;	# core dumps for debugging (if the hard limit allows)
CDPATH=".:$HOME" export CDPATH ;		# cd <unit> from anywhere

#
#	Project directories.  Created before the def_dir lines below, so those variables
#	are exported on the very first login.  Only in a base tree (BASE marker present).
#
if [ -f "${HOME}/BASE" ]
then
	mkdir -p "${HOME}/run" "${HOME}/run/pipes" "${HOME}/run/database" \
		"${HOME}/bin" "${HOME}/lib" "${HOME}/cmn" "${HOME}/tmp" "${HOME}/log" \
		"${HOME}/hlp" 2>/dev/null || true
fi

#
#	PATH: project bin first, then personal bins, cargo (rustc, bindgen, cbindgen), system
#
prefix PATH ${HOME}/.cargo/bin
prefix PATH ${HOME}/.local/bin
prefix PATH ${HOME}/.bin
prefix PATH ${HOME}/bin

#
#	Shared libraries built into ~/lib (only needed for shared libraries; off by default)
#
postfix LD_LIBRARY_PATH /usr/local/lib
postfix LD_LIBRARY_PATH ${HOME}/lib

#
#	Compilers (an earlier CC/CXX in the environment wins)
#
define CC "${CC:-gcc}"
define CXX "${CXX:-g++}"

#
#	Run-time paths read by the units (getenv / File_Path):
#	  ELOG_FILE	sys event log
#	  FILE_PATH	sys print/file defaults; msg installs *.msg here
#	  DATA_PATH	general data
#	  PIPE_PATH	named pipes
#	  KILL_PATH	far/farkill: where the kill files are looked for
#	  MEMORY_PATH	map shared-memory files
#	  DATABASE_DIR	sql session map (unused when sql is absent)
#	  SCP_PATH	scp drop directory (only if ~/scp exists)
#	  MEMORY_ALL	mio: when set, show input-only / display-only fields
#	  TraceLevel	msg: hex trace mask (leave unset for the defaults)
#
define	ELOG_FILE	${HOME}/run/event.log
def_dir	FILE_PATH	${HOME}/run/
def_dir	DATA_PATH	${HOME}/run/
def_dir	PIPE_PATH	${HOME}/run/pipes/
def_dir	KILL_PATH	${HOME}/bin/
def_dir	MEMORY_PATH	${HOME}/run/
def_dir	DATABASE_DIR	${HOME}/run/database
def_dir	SCP_PATH	${HOME}/scp/
# define MEMORY_ALL	1
# define TraceLevel	0x00000000
#

#
#	Web / CGI administration (project servers with HTML-based administration).
#	Used by shell scripts and server programs, and by the make install rules.
#	The default directories are visible (no leading dot) and ship empty with
#	base (.gitkeep); none of them is a unit.  A value already set (environment,
#	or the BOX case / ~/.profile.local on a re-source) is kept.
#	  WEB_DIR	the Apache document root of the project's web server
#	  HTML_DIR	installed .html pages
#	  HSH_DIR	html scripts (.hsh installed as .sh) that modify map memory and
#			inject msg messages to control the server and display its status
#	  CGI_BIN	CGI programs (the cgi unit installs them setuid to the project login;
#			base has no setuid or CGI install rule)
#	  CSS_DIR	style sheets and JavaScript (.css, .js)
#	  IMG_DIR	images (bmp gif jpg ico)
#
define	WEB_DIR		"${WEB_DIR:-${HOME}/www}"
define	HTML_DIR	"${HTML_DIR:-${HOME}/html}"
define	HSH_DIR		"${HSH_DIR:-${HOME}/html_sh}"
define	CGI_BIN		"${CGI_BIN:-${HOME}/cgi-bin}"
define	CSS_DIR		"${CSS_DIR:-${HOME}/styles}"
define	IMG_DIR		"${IMG_DIR:-${HOME}/images}"
#
# Unit data directories are added the same way, for example:
# def_dir LERG_PATH	/lerg/
# def_dir CABS_PATH	/cabs/

#
#	PROJECT: the single source of truth for the project name (proj init $(PROJECT)).
#	Project-per-login, so it defaults to the login name; set it in the BOX case
#	below or in ~/.profile.local to use another name.
#
define PROJECT "${PROJECT:-${LOGNAME:-$(id -un)}}"

#
#	UNITS: the same list make uses (units.mak, written by the master makefile in
#	dependency order).  When make says "UNITS changed, run: source ~/.bash_profile",
#	do that (or ". ~/.profile" from sh).
#
if [ -f "${HOME}/units.mak" ]
then
	UNITS=$(sed -n 's/^UNITS[[:space:]]*:\{0,1\}=[[:space:]]*//p' "${HOME}/units.mak")
else
	UNITS=$(ls "${HOME}"/*/[Mm]akefile 2>/dev/null | sed 's#.*/\([^/]*\)/[Mm]akefile#\1#' | sort -u | tr '\n' ' ')
fi
export UNITS

#
#	Per-machine settings.  BOX is this machine's short host name.  Add a case
#	for each machine: PEERS (make copy_to_peer), OTHERS, TGT_HOST and any
#	variable above that differs on that machine.
#
BOX=`uname -n | cut -d. -f1`
case "${BOX}" in
# devbox1)
#	define PEERS	"devbox2 devbox3"
#	define OTHERS	"devbox4"
#	define TGT_HOST	devbox2
#	;;
*)	;;
esac

#
#	Personal and secret settings: never committed (see .gitignore).  The helpers
#	above (define, def_dir, prefix, postfix) can be used there.
#
if [ -f "${HOME}/.profile.local" ]
then
	. "${HOME}/.profile.local"
fi

unset -f define def_dir eliminate prefix postfix

#
#	Toolchain hints, interactive logins only (Rust is optional; RS_BINDGEN=auto)
#
case "$-" in
*i*)
	command -v rustc >/dev/null 2>&1 ||
		echo "warning: rustc not found in PATH (Rust unit builds need it; C/C++ still work)" >&2
	command -v bindgen >/dev/null 2>&1 ||
		echo "warning: bindgen not found in PATH (RS_BINDGEN=auto skips generation)" >&2
	;;
esac
