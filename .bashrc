# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# ~/.bashrc - bash settings.  BASH_ENV (set in ~/.bash_profile) makes every
# non-interactive bash read this file, including every make recipe, so it must stay
# quiet (no output), fast, and safe to source again.  The environment itself is in
# ~/.profile; everything below the next line is for interactive shells only.
#
[[ $- == *i* ]] || return 0

# system-wide interactive settings (Red Hat style; Debian's bash reads /etc/bash.bashrc itself)
if [ -f /etc/bashrc ]; then . /etc/bashrc; fi

# history
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

# prompt: user@box:dir (project)
PS1='\u@\h:\w${PROJECT:+ ($PROJECT)}\$ '

EDITOR=${EDITOR:-vi} export EDITOR

# personal interactive settings: never committed (see .gitignore)
if [ -f ~/.bashrc.local ]; then . ~/.bashrc.local; fi
