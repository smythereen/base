# The unit make system

Copyright (c) 2026 John R. Smythe Jr.

A guide for people and Grok Bots who pull common units from the CAYE repository and want to build, test and
use them. Everything here comes from the real `rules.mak`, `targets.mak` and root `makefile`, and from the
unit makefiles (`far`, `trigger`, `mio`, `sys`, `map`, `msg`, `sem`, `atomic`, `buf`, `now`). The behaviour was
also run in a scratch tree with GNU make 4.4.1.

## 1. What it is

The unit system is a small, project-independent way to build a large C/C++ project from many directories
called **units**. It has three shared files at the project root and a tiny makefile per unit:

| File | Role |
|---|---|
| `rules.mak` | Directories, compiler flags, suffix rules, and the automatic discovery of what a unit contains |
| `targets.mak` | The standard targets and the rules that install headers, libraries and programs |
| `makefile` (root) | The master makefile: runs one standard target across every unit |
| `<unit>/makefile` | About 15 lines: include the two files above and say which headers to export and which libraries to link |

John R. Smythe Jr. designed it and it does not depend on any one project. It has been used on huge projects
with hundreds of developers. Its value is that a large project stays **modular and organized**. A developer
keeps only the units he is responsible for, builds and **unit-tests** them on his own computer, and releases
them to the main project's build and test system when they pass. The same targets run for one unit
(design, debugging, testing) or for all units (a clean, complete project build).

## 2. Layout and environment

**The project root is the build user's home directory.** `rules.mak` finds everything through `~`.

```
~/                  project root (the build user's $HOME)
  rules.mak         shared definitions and discovery
  targets.mak       shared targets
  makefile          master makefile
  LICENSE, LICENSES/
  far/  sys/  mio/  trigger/ ...   one directory per unit, each with its own makefile and LICENSE
  junk/             private catch-all for helper and test programs; not published (see junk/README.md)
  cmn/              exported headers, shared by all units (no makefile, so not a unit)
  bin/              installed programs (old copies kept in bin/.old)
  lib/              installed libraries, lib<unit>.a (old copies kept in lib/.old)
  hlp/ run/ tmp/    other project directories (created by `make dir`)
```

Units are **direct subdirectories** of the root. A directory is a unit if it contains `makefile` or `Makefile`.
`cmn/` has none, so it is shared data and not a unit. `make dir` in the root creates `bin cmn hlp lib run tmp`
and the unit directories.

To build somewhere other than the real home directory, set `HOME` for the make command, for example
`HOME=/path/to/tree make`. This works because `rules.mak` runs `echo ~`.

What you need installed: GNU make, gcc and g++ (or another compiler, see section 9), `ar`, GNU grep and **bash**.
`rules.mak` sets `SHELL := /bin/bash`, so every recipe runs under bash whatever `/bin/sh` is.

The project login's dotfiles (`.profile` in the base repo, sourced by `.bash_profile`) set:

| Variable | Used for |
|---|---|
| `CC`, `CXX` | The compilers (`gcc`, `g++`) |
| `PATH` | Must include `~/bin` to run what you build |
| `LD_LIBRARY_PATH` | Includes `~/lib` (only needed for shared libraries; they are off by default) |
| `FILE_PATH`, `DATA_PATH`, `PIPE_PATH`, `MEMORY_PATH`, `ELOG_FILE` ... | Run-time paths under `~/run/`. The `msg` unit installs its `*.msg` files into `$(FILE_PATH)` |
| `KILL_PATH` | `~/bin/`; used by `far/farkill` |
| `WEB_DIR`, `HTML_DIR`, `HSH_DIR`, `CGI_BIN`, `CSS_DIR`, `IMG_DIR` | Web / CGI administration: `~/www` (Apache document root), `~/html` (pages), `~/html_sh` (html scripts that modify map memory and inject msg messages to control the server and show its status), `~/cgi-bin` (CGI programs; only the `cgi` unit installs them, setuid to the project login), `~/styles` (`.css`, `.js`), `~/images`. Run-time variables for shell scripts and server programs, not make-only: make's install rules use the environment value when set, otherwise these defaults. The directories ship empty in base (visible, `.gitkeep`) and are not units |
| `PEERS`, `TGT_HOST` | Only for the `copy_to_*` targets (section 7) |
| `PROJECT` | Project name, used by the source-control tools |

Building the units that need nothing from the profile works with just `CC` and `CXX` (or the defaults).

## 3. How a unit is discovered

`rules.mak` looks at the directory it is run in. You never list files in a unit makefile.

- **Unit name** = the directory name up to the first dot (`far`, `sys`; `cnam.old` would be `cnam`).
- **Programs:** every `*.c` or `*.cc` file with a line containing `main(` ... `)` is a program. The test is
  `grep -l "[ <tab>]main(.*)\|^main(.*)"`, so `main(` must be preceded by a space or tab (or start the line), and
  the closing `)` must be on the same line. `int main( int argc, char ** argv )` on one line is found.
  The program takes its name from the file: `smash.c` gives `smash`.
- **Library sources:** every other `*.c` / `*.cc` file. They are compiled and archived into
  `~/lib/lib<unit>.a`. A unit with no such files has no library (for example `atomic`, which is headers plus
  one test program, and `junk`, which only has programs). If any library source is `.cc`, C++ is used for the unit's shared library.
- **Headers:** `*.h` in the unit directory. Only the ones named in `CHDRS` are exported (section 4).
- **Scripts and web files:** `*.sh` is installed into `~/bin` without the `.sh` (mode 775). `*.hsh`,
  `*.html`, `*.css`, `*.js` and the image types `bmp gif jpg ico` are installed into `$(HSH_DIR)` (`~/html_sh`),
  `$(HTML_DIR)` (`~/html`), `$(CSS_DIR)` (`~/styles`, `.css` and `.js`) and `$(IMG_DIR)` (`~/images`); the
  environment values win when set (section 2).
- **Dependencies:** every compile uses `-MD`, so each `x.c` leaves an `x.d` file listing the headers it read.
  `cat *.d > .depend` merges them and the unit makefile ends with `include .depend`. Change one header and
  `make` rebuilds exactly the files that use it. For each program, the `.d` file also records the
  libraries it links, so it relinks when a library changes. `.depend` is created on the first run.

Default compile flags (`rules.mak`): `-g -march=native -O0 -fPIC -I$(HDR)` plus `-Wall` options and
`-fcommon`, with `-L$(LIB)` for linking. Shared libraries (`lib<unit>.so`) are switched off by
`NO_UNIT_SO := yes`.

## 4. The unit makefile

This is `trigger/makefile` without its comments:

```make
include		../rules.mak

CHDRS =		$(HDR)/$(UNIT).h

LIBRARIES =	-lsys

include		../targets.mak

include	.depend
```

- **`CHDRS`** lists the headers to export into `~/cmn`. Three forms are used:
  `$(HDR)/$(UNIT).h` (`far`, `trigger`, `map`, `msg`, `sem`, `buf`, `now`), an explicit file (`mio`:
  `$(HDR)/mem_io.h`), or every header in the unit (`sys`: `$(HDRS:%.h=$(HDR)/%.h)`; `atomic` does the
  same with `$(addprefix $(HDR)/,$(HDRS))`). Files ending `.h`, `.dat` or `.def` can be exported.
  A header not in `CHDRS` stays private (for example `trigger/triglocal.h`).
- **`LIBRARIES`** lists the other units' libraries your unit links, `-lmap -lsem -lfar -lsys` style, found
  in `~/lib`. Each unit replaces the default list in `rules.mak`. Programs link in this order: your own
  `lib<unit>.a`, then `LIBRARIES`, then `SYS_LIBS`.
- **Unit's own targets** go between the two includes. `trigger` adds `test::`, which builds everything and
  runs `tests/trigtest.sh`. `msg` adds `*.msg` files to `PRODUCTS`.
- Optional variables: `SRC_ADD` (extra generated source files; the `source` target builds them),
  `LIBRARY2` (an extra library, used by `clean`), `SYS_LIBS` (extra link flags).

## 5. The standard targets

Run `make [target]` inside a unit, or from the root for all units. With no target the default is `all`.

| Target | What it does in one unit |
|---|---|
| `all` (default) | `.depend source`, then `header` → `bindings` → `library` → `product` |
| `source` | Builds `SRC_ADD` (extra generated sources), if any, and reports completion |
| `source_list` | Does nothing but report completion. It exists so the root `source_list` phase finds the target in every unit |
| `header` | Copies each file in `CHDRS` to `~/cmn` with `cp -fp` when it is newer |
| `bindings` | Optional: generate `~/cmn/*.rs` from installed `*.h` when `bindgen` is installed (`RS_BINDGEN=required` makes a missing bindgen an error; see `RUST.md`). `*.def` in `CHDRS` are installed but are not bindgen roots |
| `library` | Compiles the library sources and adds them to `~/lib/lib<unit>.a` with `ar -rUs`. The previous library is first saved in `~/lib/.old` |
| `product` | Builds every program in the unit directory (linking the unit library and `LIBRARIES`), and installs it in `~/bin`. The previous copy is moved to `~/bin/.old`. Installs scripts and web files too |
| `cleanup` / `clean` | The same rule under two names. Deletes `*.o *.a *.d *.tmp core.*` and the built programs in the unit directory, deletes the unit's exported headers from `~/cmn`, moves its installed programs to `~/bin/.old` and its library to `~/lib/.old`, and empties `.depend`. It does not delete anything for good |
| `dist_clean` | `cleanup`, then deletes the installed products |

Every target prints `Unit <name>: <target> complete!` when it finishes, even when the commands before it
ignored an error (see section 10).

**Running them from the root.** The master `makefile` has `all: header bindings library product`. Each phase runs over
**all units** before the next phase starts, so the order is: every unit's `header`, then every unit's
`bindings`, then `library`, then `product`. This is what lets units depend on each other's headers and
libraries (even circularly, as `sys`, `map`, `sem` and `far` do) with no ordering between units: all
headers are in `~/cmn` before any compile, and all libraries exist before any program links.

The root also runs `header`, `bindings`, `library`, `product`, `cleanup`, `clean`, `source_list` and `dist_clean`
across the units. Per-unit logs go under `log/<phase>/<unit>.log`; combined `<phase>.log` stays in the project root. A unit whose makefile is not a standard unit makefile must still answer these phases;
the cheap way is a **dummy (no-op) target** that only prints `Unit <name>: <target> complete!`, as
`source_list` does in `targets.mak`. A unit that really uses the unit system (`c-saw`, `load-saw`) needs none. For each one, it does `make -C <unit> -S <target>` and writes the output to
`<target>.log` in the root (`header.log`, `library.log`, `product.log`, `cleanup.log`).

**Choosing units.** By default the root builds every directory in `~` with a `makefile` or `Makefile`, in sorted
order. Select some with `UNITS` **on the command line** (a `UNITS` in the environment is ignored):

```sh
make                              # all units: header, library, product
make header library UNITS="sys far trigger"
make cleanup UNITS=trigger
make -C trigger                   # one unit, no root makefile needed (or: cd trigger; make)
make -C trigger test              # a unit's own target
```

The root also has `help` (prints its `##` comment block), `dir`, and the source-control and copy targets
in section 7.

## 6. Adding things

**A new program.** Put a `.c` file with `main( ... )` on one line into a unit and run `make` (or `make product`).
No makefile change. It is linked with the unit library and `LIBRARIES`, then installed as `~/bin/<name>`.

**A new library source.** Add a `.c` file with no `main(`. It goes into `lib<unit>.a` on the next `make library`.

**A new exported header.** Name it in `CHDRS` (or use the "all headers" form), then `make header`.

**A new unit.**

1. `mkdir ~/myunit`, put your sources in it.
2. Copy a unit makefile (`trigger/makefile` is a good template) and set `CHDRS` and `LIBRARIES`.
3. Add a `LICENSE` file (section 8) and SPDX lines to every file.
4. `make -C ~/myunit`. The root `makefile` finds the unit by itself on the next full build; no list to edit.
   Build the units named in `LIBRARIES` first, or at least have their headers in `~/cmn` and libraries in `~/lib`.

**A new language** follows the "Adding a language" rule in `README.md`. It
mirrors the C rules exactly: a no-dependency suffix rule in `rules.mak`, lists
next to the C lists, and dependency and library rules in `targets.mak` where
the C ones are, all overridable between the includes. A standalone source file
dropped into any unit builds and installs with plain `make`, just like a `.c`
file. Rust is the example; see `RUST.md`.

## 7. Working on a subset of units

This is how a large team uses the system. A developer does not need the whole project, and how he
develops and tests is up to him. The system only asks for this:

1. Make a small project directory (a build login, or any directory used as `HOME`) with `rules.mak`,
   `targets.mak` and the root `makefile`.
2. Copy into it **the complete units** his unit references (the units named in `LIBRARIES` and in his
   `#include`s, and theirs in turn), together with his own unit(s).
3. Run a complete build of that mini project in its main directory: `make` for everything, or just
   `make header library` when he only needs the headers and libraries of the other units. Add
   `product` to build the programs. `make header library UNITS="far trigger"` limits it to some units.
4. Develop and unit-test his unit(s) against them (`make -C far`, `make -C trigger test`, ...).
5. Release his unit(s) to the main project, whose build and test system builds them the same way because
   the rules are the same files.

The `newunit`, `populate` and `update` targets use the `proj` tools of the `tools` unit when
`~/bin/proj` (or `proj` on `PATH`) exists (`proj sync --units`, `proj contribute <unit>`,
`proj init $(PROJECT)`), and quietly do nothing otherwise. Install the tools with `cd tools; make product`.
The `copy_to_peer`, `copy_to_dev2` and `copy_to_dev3` targets copy sources to other computers with `scp`
(they need `PEERS` / `TGT_HOST`).

Do not commit build output: `*.o *.a *.d *.so .depend core.* *.tmp *.log` and the built programs.

## 8. Licensing

- **Units** (and these make files): every source file starts with
  `SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later` and a `Copyright (c) <years> John R. Smythe Jr.`
  line. You may use a unit under **either** licence. Use Apache-2.0 to put it in any project, including a
  closed-source one. The GPL alternative lets the units be built into the CAYE kernel.
- **c-saw** (the CAYE compiler) and the loader: `GPL-2.0-or-later` only.
- **Each unit repository has a `LICENSE` file** that explains this and lists exceptions. The license texts are in
  `LICENSES/Apache-2.0.txt` and `LICENSES/GPL-2.0.txt` in each repository.
- **Exceptions** (their own licence still applies; see `cmn/LICENSE`): `atomic_32.h` is GPL-2.0-only (derived
  from the Linux kernel), `bitops.h` is Linux kernel GPL-2.0 code, the `*_codec.h` headers are
  LGPL-2.1-or-later, `galois.h` is LGPL-2.1-or-later, `par.h` and `zconf.h`/`zlib.h` keep their authors'
  terms.
- Put the same two lines at the top of anything you contribute, with your own copyright line.

## 9. Choosing the compiler

`rules.mak` never sets `CC` or `CXX` (the old `#CC = gcc32` lines are commented out). They come from the
environment, where `.bash_profile` sets `gcc` and `g++`, or from the command line:

```sh
make CC=gcc-13 CXX=g++-13
```

The flags are in `CFLAGS` and `CXXFLAGS` and can be replaced the same way (`make CFLAGS="-O2 -I$HOME/cmn"`).

**c-saw** (the CAYE compiler) is itself a standard unit (`~/c-saw`): `make` builds `~/lib/libc-saw.a`,
installs `cayecc` and `cayedump` into `~/bin`, and exports `c_saw.h` and `caye_addr.h` to `~/cmn`. It is
not yet a drop-in `CC`. Its `cayecc` can produce `.o` files with `-c`, and `c-saw/tests/cc-build.sh` is a
gcc-like wrapper that tries `cayecc -c` and falls back to gcc (logging the fallback). The loader,
`load-saw`, is a separate unit (`~/load-saw`) that calls `cayecc` as a separate process. Both units have
their own extra targets: `make -C c-saw test` (also `test-far`), `make -C load-saw test` (also `test-far`).

## 10. Tips and pitfalls

- **The root build keeps going on purpose.** With hundreds or thousands of units you want one quick build that
  shows which units are good and which are bad, not a `make` that stops at the first error. So the root
  `make` always exits 0, and each phase writes `<target>.log` (`header.log`, `bindings.log`, `library.log`, `product.log`,
  `cleanup.log`) in the root. **Scan the logs** after a build:
  `grep -n 'warning:\|error:\|\*\*\*' *.log`. The plain words "warn" and "error" also match file names such as
  `syserror.c` and `syswarn.c`, so the patterns above are more precise. A failing unit shows the compiler
  message and a `make[1]: *** ... Error` line, and its other targets may still print `complete!`.
  To stop at the first failure, run one unit: `make -C <unit>` exits non-zero when it fails.
- **A new program is not found if `main(` is not on one line**, for example `main(int argc,` continued on the next
  line, or written `main (`. It is then built as a library source instead. A comment or call that has
  ` main( )` in a library file is taken for a program.
- **`clean` removes the unit's header from `~/cmn`**, which breaks other units until `make header` is run again.
  Run `header` for the unit after cleaning, or use the root phases.
- **Everything installs into the shared `~/bin`, `~/lib` and `~/cmn`.** Two units with a program or header of
  the same name overwrite each other (the previous file is kept in `.old`).
- **`UNITS` in the environment has no effect on the root makefile.** Pass it on the command line.
- The root `dist_clean` also removes everything in `~/cmn`, `~/lib` and `~/tmp`, plus run files and cores.
  Use `cleanup` for normal work.
- A unit's tests may need other units built first (`load-saw` needs `c-saw`'s `cayecc` and `~/cmn/caye_addr.h`).
  Build order matters between units only for the very first build: do `header` for all units, then `library`,
  then `product`, which is exactly what a root `make` does.
