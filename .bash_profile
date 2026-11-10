# SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
# Copyright (c) 2026 John R. Smythe Jr.
#
# ~/.bash_profile - bash login shells.  bash does not read ~/.profile when this file
# exists, so the shared project setup is sourced from ~/.profile (one copy, also used
# by /bin/sh logins).  Then BASH_ENV makes every non-interactive bash, including the
# shells make runs (SHELL := /bin/bash), read ~/.bashrc, and the interactive settings
# are loaded.
#
if [ -f ~/.profile ]; then . ~/.profile; fi
BASH_ENV=$HOME/.bashrc export BASH_ENV ;
if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
