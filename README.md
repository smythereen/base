# base

The base repo of the unit system. Clone it once per project: directory
structure, shared make files, and the **repo** unit.

**sys** and **atomic** are **not** shipped in base. They are on the starter
list (`GET /projects/NONE`) and are fetched before any compile. A plain
`make` populates the starter list, fetches units, then builds.

## Requires

This *is* the base. Every other unit repository requires this base first.

## License

Unlicense (public domain). See `LICENSE` and `LICENSE.NOTE`.

## Local bootstrap

```sh
git clone <base-repo> myproject && cd myproject
export PROJECT_WORKER_URL=... UNITS_CATALOG_URL=...
HOME=$PWD make
```

## Layout

`BASE`, `rules.mak`, `targets.mak`, `makefile`, `base.units` (lists `repo` only),
`repo/`, empty `bin/` `cmn/` `lib/` `hlp/` `run/` `tmp/`, examples.

Project lists are gitignored. Private units are never in public base docs.

## Starter list (project NONE)

```
sys
atomic
far
map
sem
now
mio
tp
tpi
```

## SYS_VARIANT

Defaults to `linux-x86_64` in `rules.mak`. Not auto-detected from the host.
