# base

Project bootstrap for John R. Smythe Jr.'s public **unit** make system. It
builds C, C++, and Rust — mixed in one unit or across units — for large and
mixed-language projects.

Clone **base** once per project. It ships the shared make files, empty install
directories, and the **repo** unit that fetches other units. It does **not**
ship starter unit sources and has **no** Dockerfile.

Starter units come from the public catalog / project worker. Live starter list
(`GET /projects/NONE`) is exactly:

`sys` `atomic` `far` `map` `sem` `now` `mio` `tp` `tpi`

## License

Original files: `Apache-2.0 OR GPL-2.0-or-later` (your choice). See `LICENSE`
and `LICENSES/`. Copyright notices are retained. Third-party-derived files keep
their own terms; notably `atomic_32.h` is `GPL-2.0-only` (Linux-kernel derived).

## Prerequisites

- Unix shell, **GNU make**, `cc`/`gcc`, `ar`, `ranlib`
- `git`, `curl`, `tsort`, `awk`, `sed` (repo tools)
- **Linux** is the supported host. Windows is not supported.
- HTTPS clone URLs by default (catalog). SSH URLs work if you put them in
  `private.units` or override a clone yourself.
- Environment (see `env.example`):
  - `PROJECT_WORKER_URL` — project lists (`…/projects/NAME`)
  - `UNITS_CATALOG_URL` — public unit URLs (`…/units/<name>` → JSON `{name,url}`)

Public worker used for the published starter/catalog today:

`https://unit-catalog.dejavu-archive.workers.dev`

## What a unit is

A **unit** is an independent git repository checked out as a **subdirectory of
the project root** (the directory you treat as `HOME` for builds).

Convention:

| Piece | Role |
|---|---|
| `<unit>/makefile` | ~15 lines: `include ../rules.mak`, set `CHDRS` / `LIBRARIES`, `include ../targets.mak` |
| `<unit>/UNIT.deps` | Declared fetch dependencies (`require`, `optional`, `base N`) |
| `~/cmn` | Exported headers (`make header`) |
| `~/lib/lib<unit>.a` | Unit library (`make library`) |
| `~/bin` | Programs / scripts (`make product`) |

`rules.mak` discovers sources automatically: `.c`/`.cc` with `main(` become
programs; other `.c`/`.cc` go into the library. You do not list object files.
Rust works the same way: `.rs` with `fn main` are programs, and the other
`.rs` files form `~/lib/lib<unit>.rlib`.

Each unit builds with its own makefile. The root makefile runs phases across
selected units: **header → bindings → library → product**. For each unit it runs
`make -C <unit> -S <target>` and keeps going to the next unit so one pass shows
good and bad units. Combined logs land in `header.log`, `bindings.log`,
`library.log`, `product.log`; each unit also gets `log/<phase>/<unit>.log`.
Rust is optional (`RS_BINDGEN=auto`: generate `~/cmn/*.rs` when `bindgen` is
available; otherwise C-only builds succeed). See `RUST.md`.

`UNITS.md` is the longer make-system guide shipped in this repo.

## What base does

Base is only the **project shell**:

| Path | Purpose |
|---|---|
| `BASE` | Marker (`base-format: 1`); tools refuse trees without it |
| `makefile` | Master build + project populate/fetch/units.mak restart |
| `rules.mak` / `targets.mak` | Shared compile/install rules |
| `base.units` | Units that ship inside base (`repo`) |
| `repo/` | Shell tools: `repo.sh`, `fetch-units.sh`, add/remove/list/… |
| `.profile` / `.bash_profile` / `.bashrc` | The project login's dotfiles (base is the login directory) |
| `bin/` | Empty install directory for programs (`~/bin`); not a unit |
| `www/` `html/` `html_sh/` `cgi-bin/` `styles/` `images/` | Empty web / CGI administration directories (`WEB_DIR` … `IMG_DIR`); not units |
| `cmn/` `lib/` `hlp/` `log/` `run/` `tmp/` | Install / log dirs (`.gitkeep` where empty) |
| `RUST.md` | Optional Rust / bindgen make integration |
| `project.repos.example` / `private.units.example` / `env.example` | Templates |

`sys` and `atomic` are **not** in base; they are on the starter list and are
fetched before compile.

## Adding a language

This is the standing rule for every language added to the unit system. Rust
was the first one added this way (see `RUST.md`). A new language mirrors the
C implementation rule for rule:

1. **`rules.mak`** gets the language's defaults (compiler, flags) and a suffix
   rule with **no dependencies**, modeled line for line on `.c:`. The rule
   compiles and links with `$(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES)`,
   fixes up the `.d` file, writes `.depend`, moves the old `$(BIN)` copy to
   `.old`, and copies the program to `$(BIN)`.
   Each C compile-only rule (`.c.o`, `.c.a`, `.c.s`, `.c.i`) gets a
   no-dependency counterpart where the language has one, so C units can link
   the language's objects directly (Rust: `.rs.o`, `.rs.a`, `.rs.s`). These
   rules are opt-in and never change default discovery. A language that can
   write a C header for its objects gets a suffix rule for that too (Rust:
   `.rs.h`, via cbindgen), so the header and the C that includes it rebuild
   through normal dependencies.
2. **`rules.mak`** also gets the source lists, placed next to the C lists
   (`C_SRCS`/`L_C_SRCS`, `LIBRARY`), and adds them to `EXECUTABLES`,
   `PRODUCTS` and `SOURCE` where the C lists are added.
3. **`targets.mak`** gets the dependency and pattern rules (`% : %.x
   $(LIBRARY) ...`), the library rule next to the `ar` rule, and the install
   and `clean` lines, all placed where the C ones are and shaped like them.
4. Everything stays **overridable between `include ../rules.mak` and
   `include ../targets.mak`**, as for C. A unit can change lists,
   dependencies and rules there.
5. **Drop-in works**: this is the unit system's existing convention for most
   source-to-product types: `.c`, `.cc`, `.cxx` and `.rs` programs go to
   `$(BIN)`, `.sh` scripts to `$(BIN)` without the suffix, `.hsh` to
   `$(HSH_DIR)`, and `.html` to `$(HTML_DIR)`. A standalone file of any of
   these types, dropped into any unit directory, builds or installs with plain
   `make`. A new type must follow the same convention. For a language with a
   main program, that holds in every kind of unit: C-only, C++, no library,
   units with other languages, and units with overrides.

Nothing language-specific is added unless the language needs it, and each
such addition is documented with its reason (see `RUST.md`).

## Project-per-login model

Each project is its own login: **ROOT = `$HOME`**. The base repo *is* the login
directory, so it ships the login's dotfiles at its root:

| File | Read by | Holds |
|---|---|---|
| `.profile` | `sh`/`dash`/`ksh` logins, and `.bash_profile` | All the shared setup (POSIX sh) |
| `.bash_profile` | bash logins | Sources `.profile`, sets `BASH_ENV=$HOME/.bashrc`, sources `.bashrc` |
| `.bashrc` | interactive bash, and every non-interactive bash through `BASH_ENV` | Interactive settings only (history, prompt, `EDITOR`); silent and a no-op when not interactive, so make recipes are unaffected |
| `.profile.local`, `.bashrc.local` | `.profile` / `.bashrc`, when present | Personal and **secret** settings (API keys, tokens, overrides). Gitignored; never put keys in the tracked files |

Bootstrap a new project login:

```sh
# as the new login, in its (empty) home directory
mkdir -p ~/.dotfiles.old; mv ~/.profile ~/.bash_profile ~/.bashrc ~/.dotfiles.old/ 2>/dev/null
git clone https://github.com/smythereen/base.git /tmp/base.$$ &&
	cp -a /tmp/base.$$/. ~ && rm -rf /tmp/base.$$   # a home is never empty, so clone beside it and copy in
. ~/.bash_profile        # or log out and in again
make
```

Back up any existing `.profile`, `.bash_profile` and `.bashrc` first, and move
anything personal from them (keys especially) into `~/.profile.local`.
After pulling a base update, re-login or run `. ~/.bash_profile`.

What `.profile` sets up:

- **Helpers** `define`, `def_dir`, `eliminate`, `prefix`, `postfix` (unset at
  the end; usable in `.profile.local`). `prefix PATH dir` removes any existing
  copy of `dir` before adding it, and skips a `dir` that does not exist, so
  sourcing the profile again never duplicates `PATH` entries.
- **`umask 002`** (group-writable files for shared development) and
  **`ulimit -c unlimited`** (core dumps; ignored if the hard limit forbids it).
- **`CDPATH=".:$HOME"`**: `cd sql` works from anywhere in the project. An
  exported `CDPATH` makes `cd dir` print the directory in scripts, so scripts
  that use `$(cd dir && pwd)` must `unset CDPATH` first (the repo tools do).
- **`PATH`**: `~/bin` first, then `~/.bin`, `~/.local/bin`, `~/.cargo/bin`
  (`rustc`, `bindgen`, `cbindgen`), then the system path.
  **`LD_LIBRARY_PATH`**: `/usr/local/lib` and `~/lib` appended.
- **`CC`/`CXX`**: `gcc`/`g++` unless already set.
- **Project directories**: `run`, `run/pipes`, `run/database`, `bin`, `lib`,
  `cmn`, `tmp`, `log`, `hlp` are created (only in a base tree, i.e. when
  `~/BASE` exists) before the run paths are defined, so those are exported on
  the very first login.
- **Run paths** read by the units via `getenv` / `File_Path`: `ELOG_FILE`,
  `FILE_PATH`, `DATA_PATH`, `PIPE_PATH`, `MEMORY_PATH`, `DATABASE_DIR`,
  **`KILL_PATH`** (`~/bin/`, used by `far/farkill`), and `SCP_PATH` (only if
  `~/scp` exists). Each `def_dir` path is exported only when its directory
  exists. `MEMORY_ALL` and `TraceLevel` are commented examples.
- **Web / CGI administration** (project servers with HTML-based project
  administration), always exported, and not make-only: shell scripts and
  server programs read them too. `WEB_DIR=~/www` (the Apache document root),
  `HTML_DIR=~/html` (pages), `HSH_DIR=~/html_sh` (html scripts that modify
  map memory and inject msg messages to control the server and display its
  status), `CGI_BIN=~/cgi-bin` (CGI programs), `CSS_DIR=~/styles`
  (`.css`, `.js`) and `IMG_DIR=~/images`. A value already in the environment
  is kept. `rules.mak` uses the environment value too (`?=`), falling back to
  the same defaults. The six default directories are visible (no leading dot)
  and ship empty in base with a `.gitkeep`; their contents are gitignored and
  none of them is a unit. Base has **no setuid or CGI install rule**: only the
  `cgi` unit installs its programs setuid, running as the project's login.
  **Cleaning the web directories is under review**: `make dist_clean` still
  empties `$(CGI_BIN)`, `$(HTML_DIR)` and `$(HSH_DIR)` as before, which takes
  a live web service down at once (unlike `~/bin`, where running programs
  keep going until they re-spawn). A directory-swap / Apache symlink scheme
  is being considered.
- **`PROJECT`**: the single source of truth for the project name
  (`proj init $(PROJECT)`). It defaults to the login name (project-per-login);
  an inherited `PROJECT`, the `BOX` case, or `.profile.local` can set another.
- **`UNITS`**: read from `units.mak`, the same list make uses.
- **`BOX`** (the short host name) and an empty `case "${BOX}"` template for
  per-machine settings: `PEERS` (`make copy_to_peer`), `OTHERS`, `TGT_HOST`
  and any override.
- On interactive logins only, a warning if `rustc` or `bindgen` is missing
  (Rust is optional).

`bin/` holds only a `.gitkeep`: it is where `make product` installs programs,
not a unit.

Historically **dev1** is the 24/7 production login; **dev2..devN** are
test/development logins on one or many systems. A project's msg group number
comes from looking up the login's user name in the `addr.mem` group table, so
projects can message each other.


### Project list and lock (read these carefully)

`project.repos` is **plain text**, not JSON. One unit per line:

```text
# comments allowed
sys
map
sem	via=map
```

- No `via=` → a unit you asked for (`repo add NAME`).
- `via=` → written by fetch because other units require it; recomputed on fetch.
- **No URLs and no pinned versions in this file.** Public URLs come from the
  catalog JSON; private URLs from `private.units` (`<unit> <url>`).

`project.repos.lock` is written by every successful fetch. Format observed:

```text
<unit> <url> <version-or--> <git-rev>
```

When `project.repos` is **newer than** `project.repos.lock`, the root makefile
runs `repo fetch --no-update` (clone missing units, rewrite the lock). Then it
regenerates `units.mak`. GNU make **restarts** the same invocation when
`units.mak` changes, so the new `UNITS` list is used in that one `make`.

### Default plain `make`

With `REPO_AUTO` left at `yes` (default):

1. If `project.repos` is missing → `repo fetch --project NONE --list-only`
   (starter list from `$PROJECT_WORKER_URL`).
2. `repo add` each asked-for unit (and transitive `require`s).
3. When the lock is stale → `repo fetch --no-update`.
4. Write `units.mak`, restart make, then `header` / `bindings` / `library` / `product`
   (full rebuild if `.built` is missing or stale).

```sh
git clone https://github.com/smythereen/base.git myproject
cd myproject
export PROJECT_WORKER_URL=https://unit-catalog.dejavu-archive.workers.dev
export UNITS_CATALOG_URL=https://unit-catalog.dejavu-archive.workers.dev
HOME=$PWD make
```

Useful commands after `repo` is installed into `~/bin` (or call
`./repo/repo.sh …` before that):

```sh
./repo/repo.sh list
./repo/repo.sh order --present
./repo/repo.sh fetch
./repo/repo.sh status
HOME=$PWD make cleanup
HOME=$PWD make
HOME=$PWD make header library product UNITS="sys far"
```

### `CC` and `SYS_VARIANT`

- `CC` / `CXX` come from the environment (see `env.example`); `rules.mak` does
  not hard-code a compiler.
- Hardware/OS selection is **`SYS_VARIANT`**, default **`linux-x86_64`** in
  `rules.mak`. The host is **not** auto-detected. The public `sys` tree ships
  that Linux x86-64 variant only and errors on any other value. Future variants
  would be separate trees or layouts; none are published beyond
  `linux-x86_64` today.

```sh
HOME=$PWD make SYS_VARIANT=linux-x86_64
```

## Starter units (public)

| Unit | Repository | Role (from public sources) |
|---|---|---|
| [sys](https://github.com/smythereen/sys) | common types (`common.h`), logging helpers, portability | Linux x86-64 |
| [atomic](https://github.com/smythereen/atomic) | Header-only atomics (`atomic_32.h`, `cmpxchg.h`, …) | used by `sys` headers |
| [far](https://github.com/smythereen/far) | File Access Routines: files, dirs, sockets, `select` wait | links `-lsys` |
| [sem](https://github.com/smythereen/sem) | SysV-style semaphore helpers | links `-lsys` |
| [map](https://github.com/smythereen/map) | `mmap` file/memory mapping | links `-lsem -lsys` |
| [now](https://github.com/smythereen/now) | Microsecond time helpers | library stands alone; needs `sys` headers |
| [mio](https://github.com/smythereen/mio) | Structured memory print/parse (`mem_io.h` / `Mitem`) | no `-l` of its own; needs `now`/`sys` at fetch |
| [tp](https://github.com/smythereen/tp) | **Transactions Per** interval counters (sec/min/hour/day) | links mio/now/map/sem/far/sys |
| [tpi](https://github.com/smythereen/tpi) | Transactions Per Interval helper + utilities | links mio/map/sem/far/now/sys |

### Declared / link dependencies (verified in unit makefiles + `UNIT.deps`)

Direct arrows below mean a public compile/link or fetch requirement observed in
the current trees—not guessed `-l` lines.

| Unit | `UNIT.deps` require | `LIBRARIES` (link) | Notes |
|---|---|---|---|
| atomic | — | *(empty)* | headers only |
| sys | atomic | *(empty)* | direct header dep (`atomic_32.h` / `S32_*`); not link `-latomic` |
| far | sys | `-lsys` | |
| sem | sys | `-lsys` | e.g. `ErrorLog` / sys symbols |
| map | sem, sys | `-lsem -lsys` | |
| now | sys | *(empty)* | **header** only (`now.h` → `common.h`); does **not** include atomic |
| mio | now, sys | *(empty)* | `mem_in`/`mem_out` include `now.h`; dependents usually `-lnow` |
| tp | far, map, mio, now, sem, sys | `-lmio -lnow -lmap -lsem -lfar -lsys` | also `#include <atomic_32.h>` / `S32_*` in sources; **`UNIT.deps` omits `require atomic`** (header gap) |
| tpi | far, map, mio, now, sem, sys | `-lmio -lmap -lsem -lfar -lnow -lsys` | same: sources include `atomic_32.h`; **`UNIT.deps` omits `require atomic`** |

Fetch order observed on a fresh starter resolve (dependencies first):
`atomic → sys → now → sem → far → mio → map → tpi → tp`.

**Atomic:** `sys` **does** depend on unit `atomic` (`UNIT.deps` + `sysprt.c` uses
`S32_*`). `atomic` is intentionally a separate unit (provides `atomic_32.h`).
`now` does not pull atomic indirectly. `tp`/`tpi` use atomic headers in code but
their current public `UNIT.deps` do not yet list `require atomic`—fetch still
works when `atomic` is already present via `sys` / the starter list.

**Build note:** a tree that lacks `atomic` headers in `~/cmn` can fail `sys`
(and `tp`/`tpi` sources that include `atomic_32.h`) before tests are meaningful.
Always run the root **header** phase (or a plain `make`) so `atomic` exports
first. Exercised with `HOME=$PWD make` against the live catalog on Linux x86-64.

## Catalog vs project list

- Catalog `GET $UNITS_CATALOG_URL/units/sys` →
  `{"name":"sys","url":"https://github.com/smythereen/sys.git"}` (JSON).
- Project `GET $PROJECT_WORKER_URL/projects/NONE` → plain-text unit names
  (project.repos format). **Not** a JSON name→URL map on disk.

The project worker's starter list (`GET /projects/NONE`) stays the nine
core units. The catalog worker also lists the optional messaging units
`addr`, `msg` and `near` (same JSON shape). There is no public
create/delete/governance API documented in base.

---

## The `<unit>mem` provisioning and restart contract

This is the rule every unit's shared memory follows. New or updated tools
should follow it too.

**Server processes only map memory that was provisioned beforehand.** They do
not create or default their own configuration. A `<unit>mem` program (the
unit's name plus `mem`, built with the unit) provisions, prints and changes
that memory by field name. It uses the unit's **mio** descriptor table, an
`Mitem` list.

Order on a host: **build (`make`) → provision with `<unit>mem` → start the
servers.** Provisioning happens before the first start, not before the build.

| Rule | Meaning |
|---|---|
| One fixed place | The tool and the server use the same deterministic file name or path: for example `near_<BOX>.mem` under `$MEMORY_PATH` for `nearmem BOX`, or an absolute path. Relative names are resolved under `$MEMORY_PATH`, so be consistent or use absolute paths. |
| Tool creates, server maps | Only the `<unit>mem` tool (or an equivalent operator tool) may create or "force existence" of the file. The server maps the existing file. It exits non-zero when the file is missing, the wrong size or not valid, and the supervisor's start limit makes that visible. |
| Field names, not bytes | `<unit>mem FILE_OR_BOX [ C.Variable.Name [ Value ] ]`. With no name it prints every field; with a name it prints that field; with a name and value it sets the field and prints it. Names are the C member names in the descriptor table, and nested structs and arrays keep stable names. |
| Output is a script | Each printed line is a complete `<unit>mem …` command. A dump is therefore a reload script for backup, review, cloning a role, or a layout change (P10). |
| Persist, then unmap | After a change the tool flushes (`UpdateMap`/`msync`) before it unmaps and exits. |
| Fail loudly | A tool should exit non-zero on an unknown field or a value it cannot parse. Core mio's `Input_Memory_Item` returns `void` and reports no errors, so either the tool checks first or the operator re-reads the values. Not every existing tool does this yet. |
| Trusted input only | Scripts come from operators and stay in protected ops records. Never load them from the network or build them from untrusted text, and quote string values yourself. mio prints text fields; it is not a format for arbitrary binary data or secrets. |
| Layout changes | Never map an old file with a newer layout, because `MapFile2Mem` resizes the file to the new size. Dump with the old tool, create a new file with the new tool, load it, and verify (P10). |

Examples from the published sources:

- `nearmem BOX [ C.Variable.Name [ Value ] ]` (near unit) maps `near_BOX.mem`
  with `Near_Map(box, 1)` (force existence). It prints and sets the fields of
  `near_l`, such as `trace`, `name`, `state`, `box_adr` and the nested `path`
  connection structs. Run `nearmem BOX` to see the exact names your build
  prints. It needs `miomsg` (`MioMsgInit`), so it cannot be built from the
  published sources alone today.
- `tpmem tp.mem [ C.Variable.Name [ Value ] ]` and the other `tp`/`tpi`
  `*mem` tools use the same print/set form.
- `meridianmem FILE [ Name [ Value ] ]` and `meridianmem --create FILE` in
  Tutorial part 2 are a complete, tested example. That tool also rejects
  unknown names and bad numbers.

Redeploying, adding a spare host, or rebuilding from a source backup restores
**source and executables** only. The provisioned memory is separate: each host
gets it from its `<unit>mem` scripts, and base does not generate or copy it.

---

## Build your own custom high-performance real-time 24/7 server project

This section is a **practical project guide** using only public facilities.
It is not a claim that base alone is a finished HA product, and it includes
**no fabricated benchmarks**.

### 1. Start a project with only the units you use

```sh
git clone https://github.com/smythereen/base.git realtime-svc
cd realtime-svc
export PROJECT_WORKER_URL=https://unit-catalog.dejavu-archive.workers.dev
export UNITS_CATALOG_URL=https://unit-catalog.dejavu-archive.workers.dev

# Either take the full starter…
HOME=$PWD make                 # writes project.repos from NONE, fetches, builds

# …or start empty and add only what you need:
./repo/repo.sh add sys
./repo/repo.sh add far
./repo/repo.sh add map          # pulls sem (+ sys) via UNIT.deps
./repo/repo.sh add mio          # pulls now (+ sys)
# add tp / tpi only if you need Transactions-Per counters
HOME=$PWD make
```

Inspect what you actually have:

```sh
./repo/repo.sh list
./repo/repo.sh order --present
cat project.repos
cat project.repos.lock          # URL + checked-out version/rev per unit
```

Prefer the **smallest** set that matches your `#include` / link needs: `sys`+`far`
for sockets/files; add `map`/`sem` for shared mapped memory; add `mio`/`now` for
structured memory I/O; add `tp`/`tpi` only for Transactions-Per counters (they
link the mio/map/far/sem/sys stack).

### 2. Add your application as its own unit directory

Create a sibling unit (same rules as public units)—this is your project code,
not something published inside base:

```sh
mkdir -p mysvc
cat > mysvc/makefile <<'EOF'
include		../rules.mak
CHDRS =
LIBRARIES =	-lfar	-lmio	-lnow	-lmap	-lsem	-lsys
# adjust -l lines to what you truly call; drop unused libs
include		../targets.mak
include	.depend
EOF
printf '%s\n' 'base 1' 'require far' 'require map' 'require mio' 'require sys' > mysvc/UNIT.deps
# map and mio fetch sem/now for you; list only units you directly need.
# add mysvc/*.c with main(...) for programs; library .c without main
# private URL example (writes private.units):
#   ./repo/repo.sh add mysvc https://github.com/you/mysvc.git
# or keep mysvc local-only and build with UNITS including mysvc
HOME=$PWD make
```

Never put secrets in the tree (`.gitignore` already drops `.env`, keys, etc.).

### 3. What the public units give you (and what they do not)

**Available in public trees (examples you can run after `make product`):**

- `far` — file/dir/FIFO/socket helpers; `Listen4Host`; `File_Test_For_Read_Data`
  (`select` with timeout: `<0` wait forever, `0` non-waiting poll, `>0` ms wait)
- `map` — `Map` / `MapFile2Mem` / `UpdateMap`; exercise with `testmap`
- `sem` — `SemAllo` / `SemFree` / `SemTest`; tools `sem`, `semcmd`, `semsrv`
- `mio` — `Mitem` tables, `Input_Memory_Item` / `Output_Memory_Item` for
  structured memory (used heavily by `tp`/`tpi` `*mem` utilities)
- `tp` / `tpi` — **Transactions Per** counters and interval rollups (not an OS
  thread pool). Utilities: `tp`, `tps`, `tpm`, `tph`, `tpd`, `tpi`, `*mem`
- `atomic` — non-blocking 32-bit primitives for counters / flags
- `now` — `Micro_Now` and conversions for stamps

**Your application still owns (not provided by base / these units alone):**

- Full network **protocol** state machines, framing, and authentication
- Accept-loop policy, connection limits, and how you combine `far` wait/select
  with your own readiness logic
- Subscription / event demultiplexing beyond a single FD wait helper
- Hot-path **batching**, serialization ownership, and backpressure
- Process supervision (`systemd` / upstart / equivalent), watchdogs
- Multi-host redundancy, failover, durable storage, backups
- Metrics pipelines, log shipping, and alerting

Installing `mio`+`far` does **not** give you HA or a finished 24/7 product.
Those are operational layers you design and measure yourself.

### 4. Suggested skeleton workflow (repeatable clean builds)

```sh
# after units are fetched once
HOME=$PWD make cleanup
HOME=$PWD make                    # or: make header library product
grep -nE 'error:|\*\*\*|Error [0-9]' *.log || true

# exercise public tools that match what you linked
./bin/testmap /tmp/t.map          # map smoke (see map/testmap.c)
./bin/tp /path/to/tp.mem initialize
./bin/tp /path/to/tp.mem bump

# rebuild your unit alone while iterating
HOME=$PWD make -C mysvc
HOME=$PWD make -C mysvc cleanup
HOME=$PWD make -C mysvc
```

Keep `project.repos` and `project.repos.lock` so builds share the same revisions.
`repo update NAME` checks out the newest tag when one exists; switch that unit
to `main` first only if you deliberately want unreleased code. After an
intentional update, run `HOME=$PWD make cleanup && HOME=$PWD make` and test.
The root `make` calls `repo rebuilt` after a successful full build; do not clear
`.rebuild-needed` manually after a failed build.

### 5. Performance methodology (measure; do not invent numbers)

Use **your** traffic and **your** clocks:

1. Define a load (connections/s, messages/s, payload sizes) that matches the
   service.
2. Record latency histograms (p50/p95/p99) and error rates under that load with
   a tool you trust (`perf`, `bpftrace`, userspace timers around your hot path).
3. Compare against a previous `project.repos.lock` revision after staged
   updates—not against aspirational numbers.
4. Publish only measurements you actually took; this README ships none.

### 6. Staged updates without surprise cascades

1. Copy the lock file aside (`cp project.repos.lock project.repos.lock.good`).
2. Update one unit (`./repo/repo.sh update sys`, or edit the list and `./repo/repo.sh fetch`).
   The latest tag normally governs updates. A detached release must be switched
   to `main` explicitly if you intend to track unreleased development.
3. `HOME=$PWD make cleanup && HOME=$PWD make` and run **your** regression
   tests / smoke tools above.
4. If broken, restore the previous checkout from `.old/` backups or re-fetch
   using the saved lock information; fix locally before promoting.
5. Document the regression (unit, rev, symptom) in your project notes—not in
   base.

### 7. Far waits vs end of operation

`File_Test_For_Read_Data` is a **read-readiness wait** with an optional timeout,
not a general “end of business transaction” API. Treat end-of-operation,
commit points, and durable acknowledgements as **your** protocol. Use `tp`/`tpi`
bumps when you want interval rate accounting around those points you define.

---

## Tutorial: one project from an empty directory to a multi-server deployment

This is a complete worked example you can follow line by line. It builds a
small **UDP echo + counter server** in C (`echoctr`) and in C++
(`echoxx`, step 3b) on the public `sys`, `far` and
`now` units, runs it locally, runs a second local instance, then ships the
**same compiled binary** to several hosts behind a load balancer **you** own.

Every C call below is either a public unit API that was read in the unit
sources (`File_Test_For_Read_Data`, `Micro_Now`, `EventLog`, `Trace`,
`LocalName`, `TraceLevel`) or a plain POSIX/libc call (`socket`, `bind`,
`recvfrom`, `sendto`, `signal`). Every make/repo command was run against the
live catalog on Linux x86-64 while writing this section. Hosts are the
placeholders `host1`, `host2`; the deploy user is the placeholder `svc`.
Nothing here is a hosted or purchased service, and nothing gives you automatic
high availability: what the application must own is listed in step 12.

### 0. What you need on the build host and on each server

| Where | Needs |
|---|---|
| Build host | Linux x86-64, `bash`, **GNU make**, `gcc`, `ar`, `ranlib`, `git`, `curl`, `tsort`, `awk`, `sed`; HTTPS access to GitHub and to the catalog worker |
| Each server | the **same** as the build host (every machine holds and builds the identical project tree, step 8–9); `systemd` with user services (or just a shell, see 9b); an open UDP port. Unit libraries link statically (`ldd bin/echoctr` shows only libc) |
| C++ (optional) | a C++ compiler as `CXX` on every building host (`g++` is the conventional choice; this tutorial's run used a clang++ driver, step 3b) |
| Probing | `nc` (netcat with `-u`) **or** `python3`; both forms are shown |

Servers carry the full tree and toolchain because each one builds it (step 9).
If a server must not compile, copy the **whole** built tree to it instead
(step 9, alternative); never a lone binary.

### 1. Bootstrap the project from an empty directory

```sh
mkdir -p ~/src && cd ~/src                    # any empty place you like
git clone https://github.com/smythereen/base.git echoproj
cd echoproj
export PROJECT_WORKER_URL=https://unit-catalog.dejavu-archive.workers.dev
export UNITS_CATALOG_URL=https://unit-catalog.dejavu-archive.workers.dev
export CC=gcc CXX=g++
```

**The project directory is `HOME` for builds.** `rules.mak` finds `bin`,
`cmn`, `lib`, `run` through `~`, so either use a dedicated login whose home is
the project, or prefix every make with `HOME=$PWD` as this tutorial does. For
an interactive shell, copy the profile template and source it:

```sh
cp env.example .project_profile               # edit if needed; it holds no secrets
HOME=$PWD bash -c 'source ./.project_profile; env | grep -E "^(FILE|DATA|PIPE|MEMORY)_PATH|^ELOG_FILE|^UNITS"'
```

`env.example` sets `PATH=$HOME/bin:…`, `ELOG_FILE=$HOME/run/event.log`,
`FILE_PATH`/`DATA_PATH`/`MEMORY_PATH=$HOME/run/`, `PIPE_PATH=$HOME/run/pipes/`,
and reads `UNITS` from `units.mak`.

### 2. Choose units: `project.repos`

`echoctr` calls `far` (read wait), `now` (`Micro_Now`) and `sys`
(`EventLog`, `Trace`). Add only the two it asks for; `repo` resolves the rest:

```sh
./repo/repo.sh add far
./repo/repo.sh add now
cat project.repos
```

Result (written by the tool, do not hand-edit the `via=` lines):

```text
far
now
atomic	via=sys
sys	via=far,now
```

`project.repos.lock` now records `<unit> <url> <version> <git-rev>` for each
clone, for example `sys https://github.com/smythereen/sys.git v0.2.0 a2c40f7…`.
The tools also print `FULL REBUILD NEEDED` and leave `.rebuild-needed`; the
next plain `make` does that rebuild and clears it.

(Alternative: a plain `HOME=$PWD make` in a project with no `project.repos`
takes the whole starter list `sys atomic far map sem now mio tp tpi`. That
works too; this tutorial keeps the set minimal.)

### 3. Add the application unit `echoctr`

```sh
mkdir -p echoctr
cat > echoctr/makefile <<'EOF'
include		../rules.mak
CHDRS =
LIBRARIES =	-lfar	-lnow	-lsys
include		../targets.mak
include	.depend
EOF
printf '%s\n' 'base 1' 'require far' 'require now' 'require sys' > echoctr/UNIT.deps
```

- `rules.mak` turns every `.c` containing `main(` into a program and installs
  it into `~/bin` during `make product`; other `.c` files would go into
  `~/lib/libechoctr.a`.
- `LIBRARIES` must name **every** library you call, in dependency order:
  `far` needs `sys`, and `now`'s own `LIBRARIES` is empty, so the caller links
  `-lnow` and `-lsys` itself (same for `mio`, which needs `-lnow -lsys` from
  the caller).
- `UNIT.deps` is what `repo` reads to order and fetch; the makefile is what
  links. Keep them consistent.
- `echoctr` stays a **local** unit: `repo status` reports it as
  `NOT IN THE REPO LIST`, which is expected. When it has its own git remote,
  `./repo/repo.sh add echoctr <url>` records it in `private.units` instead.

Now the server, `echoctr/echoctr.c`:

```c
/* echoctr: UDP echo + counter server built on public sys/far/now.
 * Usage: echoctr SERVER_ID PORT
 * Request "ping"  -> "pong <id> <count>"
 * Request "stats" -> "id=<id> port=<port> count=<n> up_us=<us>"
 * Anything else   -> echoed back unchanged.
 */
#include	<common.h>
#include	<far.h>
#include	<now.h>
#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<signal.h>
#include	<unistd.h>
#include	<sys/socket.h>
#include	<netinet/in.h>

static volatile sig_atomic_t	stop_flag;

static void	on_signal( int sig )
{
	stop_flag = sig;
}

int	main( int argc, char ** argv )
{
	struct sockaddr_in	me, peer;
	socklen_t		plen;
	char			buf[ 512 ], out[ 600 ];
	u64			count = 0, started;
	ssize_t			n;
	int			fd, port, len, one = 1;
	char *			id;

	if( argc != 3 || ( port = atoi( argv[ 2 ] ) ) <= 0 || port > 65535 ) {
		fprintf( stderr, "usage: %s SERVER_ID PORT\n", argv[ 0 ] );
		return( 2 );
	}
	id = argv[ 1 ];
	LocalName = id;
	if( getenv( "ECHOCTR_TRACE" ) != NULL )
		TraceLevel = (u32)strtoul( getenv( "ECHOCTR_TRACE" ), NULL, 0 );

	signal( SIGTERM, on_signal );
	signal( SIGINT, on_signal );

	if( ( fd = socket( AF_INET, SOCK_DGRAM, 0 ) ) < 0 ) {
		perror( "socket" );
		return( 1 );
	}
	setsockopt( fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof( one ) );
	memset( &me, 0, sizeof( me ) );
	me.sin_family = AF_INET;
	me.sin_addr.s_addr = htonl( INADDR_ANY );
	me.sin_port = htons( (u16)port );
	if( bind( fd, (struct sockaddr *)&me, sizeof( me ) ) < 0 ) {
		perror( "bind" );
		return( 1 );
	}

	started = Micro_Now( );
	EventLog( "echoctr %s start port %d pid %d", id, port, (int)getpid( ) );
	Trace( 0, "echoctr %s listening on udp/%d\n", id, port );

	while( !stop_flag ) {
		/* far: wait up to 1000 ms so SIGTERM is noticed promptly */
		if( File_Test_For_Read_Data( fd, 1000 ) != fd ) continue;
		plen = sizeof( peer );
		n = recvfrom( fd, buf, sizeof( buf ) - 1, 0,
			      (struct sockaddr *)&peer, &plen );
		if( n < 0 ) continue;
		buf[ n ] = '\0';
		while( n > 0 && ( buf[ n - 1 ] == '\n' || buf[ n - 1 ] == '\r' ) )
			buf[ --n ] = '\0';
		count++;
		if( strcmp( buf, "ping" ) == 0 )
			len = snprintf( out, sizeof( out ), "pong %s %llu\n",
					id, (unsigned long long)count );
		else if( strcmp( buf, "stats" ) == 0 )
			len = snprintf( out, sizeof( out ),
					"id=%s port=%d count=%llu up_us=%llu\n",
					id, port, (unsigned long long)count,
					(unsigned long long)( Micro_Now( ) - started ) );
		else
			len = snprintf( out, sizeof( out ), "%s\n", buf );
		Trace( SYS_TRC_LVL, "req %llu: %s\n", (unsigned long long)count, buf );
		sendto( fd, out, (size_t)len, 0, (struct sockaddr *)&peer, plen );
	}

	EventLog( "echoctr %s stop signal %d count %llu",
		  id, (int)stop_flag, (unsigned long long)count );
	close( fd );
	return( 0 );
}
```

What each public call does here (from the unit sources):

| Call | Unit | Behavior relied on |
|---|---|---|
| `File_Test_For_Read_Data( fd, 1000 )` | far (`farsel.c`) | `select` for read; timeout in **milliseconds** (`<0` forever, `0` poll); returns `fd` when readable, `-2` on timeout, `-1` on error (EINTR is retried inside) |
| `Micro_Now( )` | now | `u64` microseconds; used for uptime |
| `EventLog( fmt, … )` | sys (`eventlog.c`) | appends a stamped line to `$ELOG_FILE`, or `./event.log` in the current directory when `ELOG_FILE` is unset |
| `Trace( level, … )` / `TraceLevel` / `LocalName` | sys (`common.h`, `sysprt.c`) | level `0` always prints to stderr; `SYS_TRC_LVL` (`0x80000000`) prints only when that bit is set |

Networking is plain POSIX on purpose: `far`'s `Listen4Host` is a TCP
accept loop and `InitUDP2Host` *connects* a UDP socket to one peer, so neither
is a UDP server bind. Use the unit APIs where they fit and libc where they
don't—never an invented wrapper.

### 3b. The same server in C++ (`echoxx`)

All public units are usable from C++. The exported headers wrap their
declarations in `#if defined( __cplusplus ) extern "C" { … }`: `common.h`,
`far.h`, `now.h`, `map.h`, `sem.h`, `mem_io.h`, `tp.h`, `tps.h`,
`tph.h`, `tpd.h`, `tpi.h`, `atomic_bump.h`, `cmpxchg.h`, `port.h`, `gf8.h`.
The headers without a guard (`atomic_32.h`, `bitops.h`, `gf.h`) contain only
`static inline` code and macros, so there is no symbol linkage to wrap. The
libraries stay plain C archives; C++ code calls them through those
`extern "C"` declarations, so **no wrapper header is needed** and the C ABI
is unchanged.

How the build differs (from `rules.mak`):

| | C unit | C++ unit |
|---|---|---|
| Source suffix | `.c` | `.cc` (`.cxx` also has rules) |
| Compiler | `$(CC)` (`export CC=gcc`) | `$(CXX)` (`export CXX=g++`) |
| Flags | `CFLAGS` (`-g -march=native -O0 -fPIC -I$(HDR) -Wno-implicit-int -Wno-address-of-packed-member -fcommon`) | `CXXFLAGS` (`-g -march=native -O0 -fPIC -I$(HDR) -Wno-write-strings -Wno-address-of-packed-member`) |
| Program rule | `.c` with `main(` → program in `~/bin` | `.cc` with `main(` → program in `~/bin`, **linked by `$(CXX)`** so the C++ runtime is added automatically |
| Unit makefile | identical: `LIBRARIES = -lfar -lnow -lsys` | identical |

So a C++ unit is the C unit with a `.cc` file. Release build with portable
flags for both languages (both variables on the master make command line):

```sh
HOME=$PWD make cleanup
HOME=$PWD make \
  'CFLAGS=-O2 -g -march=x86-64-v2 -fPIC -fcommon -I$(HDR) -Wno-implicit-int -Wno-address-of-packed-member' \
  'CXXFLAGS=-O2 -g -march=x86-64-v2 -fPIC -I$(HDR) -Wno-write-strings -Wno-address-of-packed-member'
```

```sh
mkdir -p echoxx
sed 's/echoctr/echoxx/' echoctr/makefile > echoxx/makefile    # same LIBRARIES line
cp echoctr/UNIT.deps echoxx/
```

`echoxx/echoxx.cc`:

```cpp
// echoxx: the echoctr server in C++ (same public sys/far/now C interfaces).
// Usage: echoxx SERVER_ID PORT
#include	<common.h>	// extern "C" guarded
#include	<far.h>		// extern "C" guarded
#include	<now.h>		// extern "C" guarded
#include	<csignal>
#include	<cstdio>
#include	<cstdlib>
#include	<cstring>
#include	<string>
#include	<unistd.h>
#include	<sys/socket.h>
#include	<netinet/in.h>

static volatile std::sig_atomic_t	stop_flag;

extern "C" void	on_signal( int sig ) { stop_flag = sig; }

int	main( int argc, char ** argv )
{
	int port;
	if( argc != 3 || ( port = std::atoi( argv[ 2 ] ) ) <= 0 || port > 65535 ) {
		std::fprintf( stderr, "usage: %s SERVER_ID PORT\n", argv[ 0 ] );
		return 2;
	}
	std::string	id = argv[ 1 ];
	LocalName = argv[ 1 ];		// char *: argv outlives the process body
	if( const char * t = std::getenv( "ECHOXX_TRACE" ) )
		TraceLevel = (u32)std::strtoul( t, nullptr, 0 );

	std::signal( SIGTERM, on_signal );
	std::signal( SIGINT, on_signal );

	int fd = socket( AF_INET, SOCK_DGRAM, 0 ), one = 1;
	if( fd < 0 ) { std::perror( "socket" ); return 1; }
	setsockopt( fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof( one ) );
	sockaddr_in	me{};
	me.sin_family = AF_INET;
	me.sin_addr.s_addr = htonl( INADDR_ANY );
	me.sin_port = htons( (u16)port );
	if( bind( fd, (sockaddr *)&me, sizeof( me ) ) < 0 ) { std::perror( "bind" ); return 1; }

	u64	count = 0, started = Micro_Now( );
	// EventLog/Trace are C varargs: pass C strings (.c_str()), never std::string
	EventLog( (char *)"echoxx %s start port %d pid %d", id.c_str( ), port, (int)getpid( ) );
	Trace( 0, (char *)"echoxx %s listening on udp/%d\n", id.c_str( ), port );

	while( !stop_flag ) {
		if( File_Test_For_Read_Data( fd, 1000 ) != fd ) continue;
		char		buf[ 512 ];
		sockaddr_in	peer{};
		socklen_t	plen = sizeof( peer );
		ssize_t n = recvfrom( fd, buf, sizeof( buf ) - 1, 0, (sockaddr *)&peer, &plen );
		if( n < 0 ) continue;
		std::string	req( buf, (size_t)n );
		while( !req.empty( ) && ( req.back( ) == '\n' || req.back( ) == '\r' ) ) req.pop_back( );
		++count;
		std::string	out;
		if( req == "ping" )
			out = "pong " + id + " " + std::to_string( count ) + "\n";
		else if( req == "stats" )
			out = "id=" + id + " port=" + std::to_string( port ) + " count=" +
			      std::to_string( count ) + " up_us=" +
			      std::to_string( Micro_Now( ) - started ) + "\n";
		else
			out = req + "\n";
		Trace( SYS_TRC_LVL, (char *)"req %llu: %s\n", (unsigned long long)count, req.c_str( ) );
		sendto( fd, out.data( ), out.size( ), 0, (sockaddr *)&peer, plen );
	}
	EventLog( (char *)"echoxx %s stop signal %d count %llu",
		  id.c_str( ), (int)stop_flag, (unsigned long long)count );
	close( fd );
	return 0;
}
```

Points where C++ use differs from C (the rest is the same API):

- Many public prototypes take `char *`, not `const char *` (for example
  `EventLog( char * fmt, … )`, `LocalName` is `char *`). C++ rejects a string
  literal there without a cast; the example casts the literal, and the default
  `CXXFLAGS` already carries `-Wno-write-strings`.
- `EventLog`, `Trace`/`SysPrt` are C varargs: pass `.c_str( )`, never a
  `std::string` object.
- Signal handlers that C code may install are declared `extern "C"`.
- Nothing here claims the C libraries are exception-safe, RAII-managed or
  thread-safe. Do not throw through a C callback (for example a `far`
  `Set_FD_Read_Function` handler); catch inside it. Treat globals such as
  `TraceLevel`, `LocalName` and far's `File_Table` as process-wide state.

Build and probe exactly like the C server (`HOME=$PWD make`, then
`./bin/echoxx node-x 7121` and `ping` / `stats`). Expected replies are the same
format: `pong node-x 1`, `id=node-x port=7121 count=3 up_us=…`.

**Runtime library:** a C++ program needs the C++ runtime of the compiler that
linked it; check `ldd bin/echoxx` on each host. Because every host builds the
same tree with the same toolchain (step 9), the runtime matches by
construction. Everything else in steps 5–12 is identical: `echoxx` is just
another executable in `bin/` that a role can start (see `server-cxx` in 8b).

*Proof note:* the build host used for this tutorial had no `g++`, so the C++
example was compiled through the **same** `rules.mak` `.cc` rule with a clang++
driver passed as `CXX=…` (tested; `g++` itself was **not** run), linked against the C archives `libfar.a`,
`libnow.a`, `libsys.a`, and probed (`pong cxx 1`, echo, `stats`, SIGTERM →
`stop signal 15 count 3` in `event.log`). The rule's command shape is
`$(CXX) -MD -o echoxx $(CXXFLAGS) echoxx.cc -L$(LIB) -lfar -lnow -lsys`.

### 4. Build: `make`, `units.mak`, restarts, logs

```sh
HOME=$PWD make
cat units.mak
ls bin/echoctr
grep -nE 'error:|\*\*\* |Error [0-9]' header.log library.log product.log || echo "no build errors"
```

What that one `make` did:

1. `project.repos` is newer than the lock (or the lock is missing) →
   `repo fetch --no-update` clones anything missing and rewrites the lock.
2. `units.mak` is regenerated from the unit directories that have a makefile,
   in dependency order. It is an included makefile, so **GNU make restarts
   itself** and uses the new list in the same run. Expected content:

   ```text
   UNITS := repo atomic sys now far echoctr
   ```

   `echoctr` is included because it is a directory with a makefile; its
   `UNIT.deps` places it after `far`. If make prints
   `UNITS changed, run: source ~/.bash_profile`, re-source your profile so
   the shell's `UNITS` matches.
3. No `.built` yet (or `.rebuild-needed` newer) → **full rebuild**:
   `cleanup`, then `header` (headers → `~/cmn`, `atomic` first), `bindings`, `library`
   (`~/lib/lib*.a`), `product` (`~/bin`). On success it writes `.built` and
   runs `repo rebuilt`.

The phases keep going after a failing unit and make exits 0, so **always
grep the logs**. The `warning: overriding recipe for target '.depend'` lines
are expected with the standard unit makefile layout.

`units.mak` is only regenerated when the lock is newer. If you add a new local
unit directory **after** the first build, force it with:

```sh
touch project.repos && HOME=$PWD make         # re-checks the list, rewrites lock + units.mak
```

### 5. First local server: start and probe

```sh
export ELOG_FILE=$PWD/run/event.log
./bin/echoctr node-a 7101 &
```

Probe it (pick one client):

```sh
# netcat
printf 'ping'  | nc -u -w1 127.0.0.1 7101
printf 'stats' | nc -u -w1 127.0.0.1 7101

# or python3 (no netcat needed)
udpq() { python3 -c 'import socket,sys;s=socket.socket(2,2);s.settimeout(2);s.sendto(sys.argv[3].encode(),(sys.argv[1],int(sys.argv[2])));print(s.recv(600).decode(),end="")' "$@"; }
udpq 127.0.0.1 7101 ping
udpq 127.0.0.1 7101 hello
udpq 127.0.0.1 7101 stats
```

Observed output:

```text
pong node-a 1
hello
id=node-a port=7101 count=3 up_us=1052914
```

stderr shows the level-0 trace line, e.g.
`26-11-05 22:11:50.057266> echoctr node-a listening on udp/7101`, and
`run/event.log` gets
`… (node-a) echoctr node-a start port 7101 pid …`.

Turn on the request trace bit without rebuilding:

```sh
ECHOCTR_TRACE=0x80000000 ./bin/echoctr node-t 7103 &   # prints "req N: ..." per request
```

### 6. A second instance on the same machine

The same binary, a different server ID and port:

```sh
./bin/echoctr node-b 7102 &
udpq 127.0.0.1 7102 ping          # -> pong node-b 1
udpq 127.0.0.1 7101 stats         # node-a's count is unaffected
```

Each process has its **own** counter in its own memory. Two instances on one
port fail with `bind: Address already in use`. Stop gracefully:

```sh
kill -TERM %1 %2                   # or kill -TERM <pid>
tail -n 4 run/event.log            # "... stop signal 15 count N"
```

The loop wakes at least once a second (the 1000 ms `far` wait), sees the flag
set by the signal handler, logs, closes the socket and exits 0.

> If you later want instances on **one host** to share a counter, the public
> path is a `map`-ed file with `S32_*` atomics (and `sem` if you need a lock).
> That mapping is a local file mmap: it is **not** shared across machines.
> Two hosts each have their own copy; nothing in base replicates it.

### 7. Development loop vs production build

| | Development | Production |
|---|---|---|
| Flags | `rules.mak` default: `-g -O0 -march=native -fPIC -fcommon …` | same flags with `-O2` and a **portable** `-march` (see below) |
| Rebuild | `HOME=$PWD make -C echoctr` (just your unit) or plain `make` (incremental) | clean: `make cleanup && make` from a recorded commit + lock |
| Restart | `kill -TERM` the process, re-run `./bin/echoctr …` | identical tree on every host from the recorded commit + lock; restart only that host's role instances, one host at a time |
| Units | newest revisions via `repo update` while you work | exactly the revisions in the saved `project.repos.lock` |

**`-march=native` is a deployment trap**: a binary built on a newer CPU can
die with `SIGILL` on an older server. `CFLAGS` given on the master make
command line propagates to every unit (checked: no `march=native` left in the
logs), so build the release like this:

```sh
HOME=$PWD make cleanup
HOME=$PWD make 'CFLAGS=-O2 -g -march=x86-64-v2 -fPIC -fcommon -I$(HDR) -Wno-implicit-int -Wno-address-of-packed-member'
grep -nE 'error:|\*\*\* |Error [0-9]' *.log || echo "no build errors"
ldd bin/echoctr                    # expect only linux-vdso, libc, ld-linux
```

Keep `-I$(HDR)` (single quotes so make, not the shell, expands it). Pick the
`-march` level that all your servers support.

### 8. Multi-server model: one identical project tree, different roles

In multi-server operation **every machine has the same project tree**: the
same base checkout, the same `project.repos` / `project.repos.lock`, the same
unit revisions, the same `units.mak`, the same build flags, and therefore the
same set of executables in `bin/`. What differs per machine is only **which
executables you start there** (its *role*). Nothing auto-starts: `make`
builds libraries and installs programs; a program runs only when you (or your
supervisor) launch it.

```text
 host1 (role server-1)          host2 (role server-2)          lbhost (role balancer)
 ~/echoproj  (identical)        ~/echoproj  (identical)        your LB software
   bin/echoctr  bin/echoxx        bin/echoctr  bin/echoxx        (+ the tree, optional)
   bin/start-role                 bin/start-role
 runs: echoctr server-1 7101    runs: echoctr server-2 7101
```

Rules that keep machines interchangeable:

- No per-machine source edits and no "lighter" machines missing executables.
  Any host can take any role by starting different programs.
- Same CPU/ISA baseline and same OS family on all hosts (public `sys` is
  `linux-x86_64` only), and a portable `-march` (step 7), so a binary built
  on one host would also run on the others.
- Same compiler versions on every build host if you compare binaries.
- A different OS/hardware variant would be a different `SYS_VARIANT` and a
  different tree build; do not mix variants inside one role group.

#### Side benefit: every node is a copy of the project source

Because each participating machine holds the complete tree (base, every unit
checkout, your application source, list and lock), the source is present on
every node. If the development machine is gone, any node can rebuild the
project or seed a new machine from its tree—given the same toolchain and
`SYS_VARIANT`.

Limits, stated plainly:

- base does **not** replicate anything. Trees are identical only because you
  keep them so (clone + pinned lock, `rsync`, or your own orchestration).
- A node has what was last synced: not uncommitted work, not branches or
  history that were never pushed. (Unit checkouts made by `repo fetch` are
  full clones; only its internal probe clones are shallow.) Keep your real git remote(s) and normal backups.
- Live service data (`run/`, `event.log`, mapped `.mem` files, databases) is
  **per node** and is not a backup of anything; back it up separately.
- Node-local settings (systemd instance names, `.profile.local` / `BOX` case edits,
  balancer config, secrets) are outside the synced source; exclude them from
  any sync and keep them in your ops records.
- Confirm the copies really match with the identity check in step 9
  (`git rev-parse HEAD`, `sha256sum project.repos.lock`, per-unit revs).

#### 8a. Put your project's own files under your own git

base ignores `project.repos`, `project.repos.lock`, `private.units` and build
state. Keep them in **your** repository, with your application unit. The
simplest layout is the `echoctr` unit as its own git repo that also carries
the project list files and the role script:

```text
echoctr/                  (your git repo, e.g. https://git.example.invalid/you/echoctr.git)
  makefile  UNIT.deps  echoctr.c  start-role.sh
  project/project.repos  project/project.repos.lock
```

(`echoxx` is the same pattern: its own unit directory, or its own repo.)
`project/` is a plain directory with no makefile, so the build ignores it;
it is just where you keep the list and lock under version control.
Register the unit in the project so every machine fetches it:

```sh
./repo/repo.sh add echoctr https://git.example.invalid/you/echoctr.git   # writes private.units
```

The URL is a placeholder: use your own remote.

#### 8b. The role script (installed by `make product`)

`rules.mak` installs every `*.sh` in a unit into `~/bin` without the suffix,
so `echoctr/start-role.sh` becomes `bin/start-role` on every host:

```bash
#!/usr/bin/env bash
# start-role ROLE : start the executables assigned to ROLE (foreground).
# Same script, same tree on every machine; only the ROLE argument differs.
# OPERATOR: fill in your own role names, IDs and ports below.
set -eu
cd "$HOME/run"
export ELOG_FILE="${ELOG_FILE:-$HOME/run/event.log}"
case "${1:-}" in
server-1)	exec "$HOME/bin/echoctr" server-1 7101 ;;
server-2)	exec "$HOME/bin/echoctr" server-2 7101 ;;
server-cxx)	exec "$HOME/bin/echoxx"  server-cxx 7121 ;;
*)		echo "usage: start-role server-1|server-2|server-cxx" >&2; exit 2 ;;
esac
```

```sh
chmod 755 echoctr/start-role.sh       # keep the execute bit in git
HOME=$PWD make
HOME=$PWD ./bin/start-role server-1 & # -> "pong server-1 1" on udp/7101
```

Role names are names **you** choose (`server-1`, not a real hostname). Which
host carries which role is an operator decision recorded wherever you keep
ops data (a systemd instance name, below, is enough). A role that needs
several programs starts each one as its own supervised instance (one
`start-role` case per program) rather than backgrounding them inside the
script. If you later add other units with executables (for example the
`tp` operator tools, or messaging units once you use them), they are built on
every host too and only appear in the roles that use them.

### 9. Set up each machine from the same commit (build on every host)

Preferred: every host builds its own identical tree from the same records.
On **host1, host2, …** as the service user `svc` (placeholders):

```sh
git clone https://github.com/smythereen/base.git ~/echoproj
cd ~/echoproj
git checkout <base-commit>                       # the base commit you recorded
export PROJECT_WORKER_URL=https://unit-catalog.dejavu-archive.workers.dev
export UNITS_CATALOG_URL=https://unit-catalog.dejavu-archive.workers.dev
export CC=gcc CXX=g++                            # same toolchain on every host
# your list, lock and private URLs (from your echoctr repo / ops repo):
git clone https://git.example.invalid/you/echoctr.git /tmp/echoctr-src
cp /tmp/echoctr-src/project/project.repos /tmp/echoctr-src/project/project.repos.lock .
printf 'echoctr\thttps://git.example.invalid/you/echoctr.git\n' > private.units
HOME=$PWD ./repo/repo.sh fetch
# pin every unit to the recorded revision (fetch alone takes the newest)
while read -r unit url ver rev; do
	[ -d "$unit/.git" ] && git -C "$unit" checkout -q "$rev"
done < /tmp/echoctr-src/project/project.repos.lock
cp /tmp/echoctr-src/project/project.repos.lock project.repos.lock
HOME=$PWD make cleanup
HOME=$PWD make \
  'CFLAGS=-O2 -g -march=x86-64-v2 -fPIC -fcommon -I$(HDR) -Wno-implicit-int -Wno-address-of-packed-member' \
  'CXXFLAGS=-O2 -g -march=x86-64-v2 -fPIC -I$(HDR) -Wno-write-strings -Wno-address-of-packed-member'
grep -nE 'error:|\*\*\* |Error [0-9]' *.log || echo "no build errors"
```

`project.repos.lock` lines are `<unit> <url> <version> <git-rev>`; the loop
checks each unit out at that rev. No global git checkout is involved: the
only clones are the project root (base) and its unit subdirectories.

Verify that hosts are identical **before** starting roles:

```sh
cd ~/echoproj
git rev-parse HEAD                                 # base commit
sha256sum project.repos.lock
for u in $(sed -n 's/^UNITS[[:space:]]*:=//p' units.mak); do
	printf '%-10s %s\n' "$u" "$(git -C "$u" rev-parse HEAD 2>/dev/null || echo base-unit)"
done
HOME=$PWD ./repo/repo.sh status
ls bin
```

Run that on every host (e.g. `ssh svc@host1 'cd ~/echoproj && …'`) and
compare: the base commit, lock checksum, unit revisions and `bin/` listing
must match exactly. `repo status` should show every unit `clean` at the same
`NOW` version. Binary checksums (`sha256sum bin/echoctr`) match only when
the toolchain and project path are also the same; the source revisions are
the authoritative check.

**Alternative: copy the complete tree.** If servers must not compile, build
once on a build host of the same ISA and copy the **whole project directory**
(not just one binary), so each host still has the identical durable tree:

```sh
rsync -a --delete --exclude='run/' --exclude='tmp/' ~/echoproj/ svc@host1:echoproj/
ssh svc@host1 'cd ~/echoproj && sha256sum project.repos.lock bin/*'
```

Compare those checksums with the build host. Same tree, same executables,
different roles—just as in the build-everywhere case.

#### 9a. Supervise roles with a user-owned systemd template

The instance name **is the role**; the tree is the same on every host:

```sh
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/echorole@.service <<'EOF'
[Unit]
Description=echoproj role %i
After=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
Environment=HOME=%h/echoproj
Environment=ELOG_FILE=%h/echoproj/run/event.log
WorkingDirectory=%h/echoproj/run
ExecStart=%h/echoproj/bin/start-role %i
KillSignal=SIGTERM
TimeoutStopSec=5
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now echorole@server-1     # on host1
# systemctl --user enable --now echorole@server-2   # on host2
systemctl --user status --no-pager echorole@server-1
```

User services stop at logout unless lingering is on for that account (one-time
admin action per host: `sudo loginctl enable-linger svc`).

```sh
systemctl --user stop    echorole@server-1   # SIGTERM -> "stop signal 15" in run/event.log
systemctl --user start   echorole@server-1
systemctl --user restart echorole@server-1
journalctl --user -u echorole@server-1 -n 20
tail -n 20 ~/echoproj/run/event.log
```

Moving a role to another host is `disable --now` on one and `enable --now`
on the other—no rebuild, because every host already has every executable.

#### 9c. Failure model: die and be respawned

This project assumes a **fail-fast** process model: when a server process hits
a fault it cannot fully recover from, it **exits** (non-zero), and the
supervisor—`systemd` here, or init/your equivalent—**starts it again**. It does
not limp on, hang, or try to repair itself in place.

What that means for the template above:

| Setting | Why |
|---|---|
| `Restart=always` | respawn after any exit, crash or signal death. A deliberate `systemctl --user stop`/`disable --now` is **not** restarted, so a clean operator stop stays stopped. (A stray `kill -TERM` outside systemctl *is* restarted—echoctr exits 0 on SIGTERM.) `Restart=on-failure` is the alternative if you want a clean exit 0 to mean "stay down"; this tutorial uses `always`. |
| `RestartSec=2` | short pause so a respawn loop does not spin |
| `StartLimitIntervalSec=60` + `StartLimitBurst=5` (in `[Unit]`) | more than 5 starts in 60 s → systemd gives up and marks the unit failed. A bad config, taken port or missing file then **stops** instead of restarting forever; that failed state is what your monitoring alerts on. Clear with `systemctl --user reset-failed echorole@server-1` after fixing. |
| `Type=simple` + `exec` in `start-role` | `exec` replaces the shell with the server, so systemd tracks the **real** server PID and `KillSignal=SIGTERM` reaches it directly. Without `exec`, the signal goes to a shell and the server can be orphaned or SIGKILLed. Keep one supervisor: do not also background or loop-restart inside the script. |
| `KillSignal=SIGTERM`, `TimeoutStopSec=5` | graceful stop; echoctr notices SIGTERM within ~1 s (its 1000 ms `far` wait), logs and exits. After 5 s systemd sends SIGKILL. |

Writing servers for this model:

- On an unrecoverable error, log it (`EventLog`, which appends a line to
  `$ELOG_FILE`) and **exit non-zero**—as `echoctr` does on a failed
  `socket`/`bind` (`return 1`). Do not swallow it (no catch-all that keeps a
  broken process running, in C or C++).
- Bound every wait. `File_Test_For_Read_Data` takes a timeout; use one, and
  treat "stuck for too long" as a fault that ends the process. Detecting a
  process that hangs without exiting needs a watchdog **you** add (for example
  systemd's `WatchdogSec=` with your own `sd_notify` calls, or an external
  health check that restarts the unit); nothing in the public units provides it.
- Expect to start fresh. Process memory is gone after a respawn. Rebuild state
  at startup from something durable you own (a file, a database, a `map`ped
  file on that host), and remember a mapped file may hold a half-finished
  update if the process died mid-write.
- Open the listening socket early and fail fast if it cannot bind; a restart
  then either serves within seconds or trips the start limit.

This is **process** recovery on the same host. A dead **machine** is a
different event, handled by moving the role (step 11a).

#### 9b. Foreground alternative (no systemd)

```sh
cd ~/echoproj && HOME=$PWD ./bin/start-role server-1
```

Run it under `tmux`/`screen` or your own supervisor (init, runit, s6, …).
The failure model in 9c assumes **some** supervisor respawns the process;
without one nothing restarts it after a fault or reboot.

### 10. Multi-server topology and the load balancer

```text
             clients
                │  udp/7100
                ▼
     ┌─────────────────────┐   load balancer: YOUR software, YOUR config,
     │  lbhost (balancer)  │   on its own host or co-located on host1
     └──────┬────────┬─────┘
            │        │ udp/7101
            ▼        ▼
       host1:7101  host2:7101     identical ~/echoproj on both,
       server-1    server-2       different role started
```

Check each node directly before putting a balancer in front:

```sh
for h in host1 host2; do printf 'ping' | nc -u -w1 $h 7101; done
# -> pong server-1 1 / pong server-2 1
```

The balancer is **not** a base unit or a project executable. Install and run
it yourself (open-source nginx `stream` shown; HAProxy, LVS/IPVS, DNS or a
client-side server list also work). A dedicated `lbhost` avoids competing with
a server role; co-locating it on host1 works but makes host1 a single point of
failure for both roles. Nothing here is a hosted or paid service.

```nginx
# /etc/nginx/nginx.conf (top level, outside the http{} block)
stream {
    upstream echoproj_udp {
        server host1:7101 max_fails=3 fail_timeout=10s;
        server host2:7101 max_fails=3 fail_timeout=10s;
    }
    server {
        listen 7100 udp;
        proxy_pass echoproj_udp;
        proxy_responses 1;     # one reply datagram per request
        proxy_timeout 2s;
    }
}
```

`nginx -t && nginx -s reload`, then `printf 'ping' | nc -u -w1 lbhost 7100`
several times: replies alternate between `server-1` and `server-2`.
Open-source nginx only marks a node bad **passively** (after failed
requests); active checks are your script (below) or another balancer.

Counters are **per process**: each role counts only what it received. A
cluster total means summing `stats` from every node yourself. A `map`ped file
lives on one machine; nothing replicates it.

### 11. Health monitoring and safe rolling updates

A health probe any monitor or cron job can call (exit 0 = healthy):

```sh
#!/usr/bin/env bash
# echoproj-check HOST PORT  -> prints the stats line, exits non-zero if no reply
set -u
reply=$(printf 'stats' | nc -u -w1 "$1" "$2") || true
[ -n "$reply" ] && { echo "$1:$2 $reply"; exit 0; }
echo "$1:$2 NO REPLY" >&2; exit 1
```

An update is: record a new base commit + lock in your repo, then on each host
in turn bring the **same** tree to those records, rebuild, verify, and restart
only that host's roles. One host at a time, stop at the first failure:

```sh
#!/usr/bin/env bash
# roll-out ROLEMAP : lines "host role port", e.g.
#   host1 server-1 7101
#   host2 server-2 7101
set -euo pipefail
while read -r h role port; do
	[ -z "$h" ] && continue
	echo "== $h ($role)"
	# 1. drain: remove $h from the LB upstream and reload the LB (your step)
	ssh -n "svc@$h" "set -e; cd ~/echoproj
		git -C /tmp/echoctr-src pull -q
		cp /tmp/echoctr-src/project/project.repos .
		HOME=\$PWD ./repo/repo.sh fetch
		while read -r u url v rev; do [ -d \$u/.git ] && git -C \$u checkout -q \$rev; done \
			< /tmp/echoctr-src/project/project.repos.lock
		cp /tmp/echoctr-src/project/project.repos.lock .
		HOME=\$PWD make cleanup >/dev/null
		HOME=\$PWD make >/dev/null    # plus the same CFLAGS/CXXFLAGS as step 9
		! grep -qE 'error:|\*\*\* |Error [0-9]' *.log
		sha256sum project.repos.lock
		systemctl --user restart echorole@$role
		sleep 1; systemctl --user is-active echorole@$role"
	./echoproj-check "$h" "$port" || { echo "== $h unhealthy: stop and roll back"; exit 1; }
	# 2. undrain: put $h back in the LB upstream and reload (your step)
done < rolemap.txt
```

Rollback is the same procedure with the previous recorded lock (keep it in
your repo history, e.g. `git -C /tmp/echoctr-src checkout <previous>`), or
the previous copied tree if you use the copy method. Facts during a roll:

- `restart` sends SIGTERM; `echoctr`/`echoxx` exit within about one second
  (their `far` wait timeout). Datagrams arriving in that gap are **lost**.
- The counter restarts at 0; persisting it is application design.
- While a roll is in progress, hosts briefly run different revisions. Keep the
  request/response format backward compatible across one release, or drain
  completely first. Re-run the step 9 identity check when the roll ends.
- Keep at least one healthy node in the balancer at all times.

### 11a. Machine failure and role takeover

**Yes, another machine can take over a failed machine's processing**—because
every host has the identical tree, any host can start any role
(`bin/start-role server-2` exists on host1 too). But **nothing does it for
you**: no public unit (`sys atomic far map sem now mio tp tpi`) detects a dead
machine, moves a role, moves an IP, or replicates data. A dead machine is
invisible at the unit library level—a library can only see its own process.
Detection and takeover are operator (or your own automation) steps.

Two different failures:

| Failure | Who handles it | What happens |
|---|---|---|
| The **process** dies (fault → exit, crash, kill) | `systemd` on the same host (`Restart=always`, step 9c) | respawned in place after `RestartSec=2`; same host, same port; gives up after 5 starts in 60 s |
| The **machine** dies (power, kernel, network) | **you** (or your own failover tooling) | start the same role on another host and point traffic there |

#### Plan the spare before you need it

- **Active-active:** host1 and host2 both serve behind the balancer. Losing one
  host leaves the other serving; takeover is only needed to restore capacity.
- **Active-standby / spare:** a `host3` with the identical tree (step 9) and
  the systemd template installed, but **no role enabled**. It is used only
  when a host fails.
- Choose ports so a role can run on the spare unchanged (here every
  `echoctr` role listens on `7101`), and make sure the spare's firewall allows
  that port.
- Keep `rolemap.txt` (host, role, port) as the record of who runs what.

#### Step by step: host2 (`server-2`) fails, `host3` takes over

All commands are examples to run by hand; replace host names and addresses
with yours.

1. **Detect.** Your monitor runs `echoproj-check` (step 11) and alerts:

   ```sh
   ./echoproj-check host2 7101 || echo "host2 server-2 down"
   ssh -o ConnectTimeout=5 svc@host2 true || echo "host2 unreachable"
   ```

   If ssh works and only the process is down, look at
   `systemctl --user status echorole@server-2` on host2 first; that is a
   process failure, not a machine failure.

2. **Fence the failed machine (prevent split brain).** Before another host
   serves `server-2`, make sure host2 cannot come back and serve it too. If
   host2 is reachable at all, stop and disable the role there:

   ```sh
   ssh svc@host2 'systemctl --user disable --now echorole@server-2'
   ```

   If it is **unreachable**, do not wait on it: power it off or isolate it
   through whatever you control (hypervisor/cloud console, PDU, switch port),
   and mark it "do not start" before it is ever rebooted. A rebooted host2
   with `echorole@server-2` still enabled would start the role again.

3. **Verify the spare is identical** (step 9 identity check) and healthy:

   ```sh
   ssh svc@host3 'cd ~/echoproj && git rev-parse HEAD && sha256sum project.repos.lock && ls bin/start-role'
   ```

   Compare with a healthy node (host1). Do not take over on a mismatched tree.

4. **Start the role on the spare:**

   ```sh
   ssh svc@host3 'systemctl --user enable --now echorole@server-2 &&
     systemctl --user is-active echorole@server-2'
   ./echoproj-check host3 7101          # -> id=server-2 port=7101 count=0...
   ```

   The role name and port are the same; only the host changed.

5. **Point traffic at the spare.** With the nginx example, replace host2 with
   host3 in the upstream on the balancer host and reload:

   ```nginx
   upstream echoproj_udp {
       server host1:7101 max_fails=3 fail_timeout=10s;
       server host3:7101 max_fails=3 fail_timeout=10s;   # was host2
   }
   ```

   ```sh
   sudo nginx -t && sudo nginx -s reload
   for i in 1 2 3 4; do printf 'ping' | nc -u -w1 lbhost 7100; done   # server-1 / server-2
   ```

   If clients reach host2 directly instead of through a balancer, you must
   move what they use: DNS name (TTL delays apply), or a service IP you move
   to host3 yourself (`ip addr add <service-ip>/<len> dev <if>` on host3 after
   host2 is fenced). base provides neither.

6. **Record it.** Update `rolemap.txt` (`host3 server-2 7101`) so the next
   roll-out (step 11) targets the right host.

7. **Later, repair host2** as a fresh spare: rebuild/verify the tree (step 9),
   leave `echorole@server-2` disabled until you deliberately move the role back
   (same steps, reversed).

#### What takeover does **not** give you

- **In-flight work is lost.** Datagrams sent to host2 while it was dying get no
  reply; `echoctr`'s counter starts again at 0 on host3. Anything kept in
  process memory or a `map`ped file on host2 stays on host2—mapped files are
  local, not shared across nodes.
- **Duplicates are possible.** A client that retries after a timeout may have
  had its request processed already. Making requests idempotent (request IDs,
  dedup) and keeping durable state in a transactional store or durable queue
  is application design.
- **A real smoke test is a real request.** `ping` proves the process answers;
  for a service with state or TCP sessions, test the actual operation and its
  acknowledgement after takeover, and expect clients to reconnect.
- **The balancer is its own single point of failure.** If `lbhost` dies,
  everything behind it is unreachable. Redundant balancers need your own
  shared-IP/VRRP setup or DNS failover.
- **Source copies are not data copies.** The identical trees (step 8) let any
  node rebuild and run any role; they do not hold the other nodes' live data.

The messaging units (`msg`, `addr`, `near`) do not add failover either: msg
is host-local FIFOs, and near only moves UDP datagrams (Tutorial part 2, P7).

### 12. What the application owns vs what base provides

| Concern | base + public units | Your application / operations |
|---|---|---|
| Fetching and building units | `repo`, `project.repos`, lock, `units.mak`, make phases | keeping list + lock in **your** repo; choosing when to update |
| Socket/file helpers, waits | `far` (`File_Test_For_Read_Data`, `Listen4Host`, …) | protocol, framing, auth, rate limits, backpressure |
| Time, logs, trace | `now`, `EventLog`, `Trace`/`TraceLevel` | log rotation and shipping, alerting |
| Shared state on **one** host | `map` (+`sem`, `atomic`) | anything shared **between** hosts: replication, consensus, a database |
| Process lifecycle | — | systemd/supervisor units, restart policy, lingering, resource limits |
| Load balancing | — | balancer software, its config, its own redundancy (one LB is a single point of failure) |
| Health and failover | systemd restarts a crashed process in place (your template) | detecting dead machines, fencing, starting the role on a spare, moving traffic (step 11a) |
| Disks, backups, capacity | — | disk-full handling for `event.log`/trace files, backups, monitoring |
| Network | — | firewalls, port allocation, DNS, TLS/auth if needed |
| Deployment | — | keeping trees identical (clone/rsync/your orchestration), role assignment, rolling procedure, rollback |

There is **no automatic HA, no clustering, no service discovery and no hosted
offering** in base or the public units. They give you fast, small building
blocks; the multi-server behavior above is code and config you own.

### 13. Tutorial checklist

```text
[ ] base cloned; PROJECT_WORKER_URL / UNITS_CATALOG_URL / CC exported
[ ] repo add far; repo add now          -> project.repos + lock
[ ] echoctr/{makefile,UNIT.deps,echoctr.c}
[ ] optional C++: echoxx/{makefile,UNIT.deps,echoxx.cc}; ldd shows libstdc++ plan
[ ] HOME=$PWD make; units.mak lists echoctr; logs have no errors
[ ] local ping/stats on two ports; SIGTERM logged in run/event.log
[ ] base commit + project.repos/lock + private.units recorded in your own repo
[ ] echoctr/start-role.sh with your role names -> bin/start-role
[ ] every host: same tree, same lock revs, same flags/toolchain; identity check matches
[ ] systemd echorole@<role> per host (only that host's roles), linger enabled
[ ] each node probed directly
[ ] LB config you own; alternating replies through the LB
[ ] health check + one-host-at-a-time roll-out + tested rollback
[ ] spare host verified; role takeover + fencing rehearsed (step 11a)
```

---

## Tutorial part 2: near → msg → execution, with restart and redeploy

Part 1 used plain sockets. Part 2 builds the same kind of service on the
messaging units: a **near** edge takes UDP requests, hands each one to an
**execution** process through **msg**, and returns the reply over UDP. It also
covers the restart rule this design assumes: **on start, a process maps its
shared memory and then resumes with the next message waiting in its msg FIFO.**

The `msg`, `addr` and `near` sources were read for this part. Their public
repositories (`github.com/smythereen/msg`, `…/addr`, `…/near`) are published
and listed in the catalog worker, so `./repo/repo.sh add msg` (and `addr` /
`near`) resolves without a private URL. The starter list
(`sys atomic far map sem now mio tp tpi`) does not change.

### P1. What was run, and what was not

Run on Linux x86-64 with gcc in a scratch project (results quoted below):
build and link of `mexec`/`medge`; ADD/GET over UDP; retry dedupe; frame
limits; bad input; fault injection (`abort`, `exit 3`); respawn with state
kept; messages queued in the FIFO while the executor was hung (SIGSTOP) and
then killed (SIGKILL) were processed after respawn; refusing a wrong-size or
foreign state file. The C sources also pass a C++ syntax check (clang++
driver) after one cast that is already in the code below.

**Not run:** systemd units, `msg` CLI stop, real power-off reboot, remote
hosts, the load balancer, the release/rollback commands. They are written to
the documented behaviour and are marked as untested where they appear.

### P2. Units, and the build gaps you must know about

| Unit | Used for | Build status from the published sources |
|---|---|---|
| `addr` | `u32` address `machine.group.program.subtask`; `Numbers_To_Address`, `Name_To_Address` | builds (library + `addr`, `addrmem` tools) |
| `msg` | `MsgInit`, `MsgSend`, `MsgRead`; per-address FIFO `XXXXXXXX.que` + mapped buffer file `XXXXXXXX.mem` | **library builds**; the `msg` **CLI does not** (needs `miomsg`, see P8) |
| `near` | `UDP_Open`, `UDP_Read_With_Timeout`, `UDP_Send` (IPv4 only) | **does not build** without `sig.h` from the unpublished `sig` unit; `near`'s own programs also need project SNMP and `miomsg` |

So with only published code today, `libnear.a` cannot be built. For the test
run here, `libnear.a` was compiled with an **empty test-only `sig.h`** on the
include path (the UDP routines do not use it). That is a lab workaround, not a
supported build. Supply the real `sig` unit before production use. If you
cannot, write the edge with plain sockets as in Part 1 and keep the rest.

`miomsg` is a separate unit (`MioMsgInit`, which registers the `MSGADDR`
field type with `MioRegisterHandler`). It is not part of these repos, and this
tutorial's programs do not use it.

None of these units has a `UNIT.deps` file yet, so `repo` cannot work out
their dependencies. Add the companions explicitly:

```sh
./repo/repo.sh add sys; ./repo/repo.sh add far; ./repo/repo.sh add map
./repo/repo.sh add mio; ./repo/repo.sh add now
./repo/repo.sh add addr
./repo/repo.sh add msg
./repo/repo.sh add near
```

### P3. Roles

| Role | Program | Notes |
|---|---|---|
| near edge | `medge BIND_IP PORT` | UDP in/out, strict request parsing, msg client |
| execution + state | `mexec` | owns the mapped state file, serves msg requests |
| msg "service" | — | **none**: msg is a library. Each receiving process owns its FIFO + buffer file under `$PIPE_PATH` |
| addr "service" | — | **none** needed here: addresses are numeric (`Numbers_To_Address`), so no `addr.mem` name table is used |
| balancer | your nginx/HAProxy | in front of the edges (Part 1, step 10) |
| supervisor | systemd (or init) | one supervisor for every role; respawns on exit |

msg here is **host-local**. It is not a network transport: `MsgSend` writes
to a FIFO on this machine. Every host runs its own `medge` + `mexec` pair with
the same addresses. Only the UDP side crosses the network.

### P4. The code

`meridian/meridian.h`:

```c
/* meridian.h - shared definitions for the meridian tutorial roles */
#ifndef	MERIDIAN_H
#define	MERIDIAN_H

#include	<common.h>
#include	<atomic_32.h>
#include	<msg.h>

/* msg addresses (addr layout machine.group.program.subtask), numeric so
 * no addr.mem name table is needed.  msg is host-local here: every host
 * uses the same numbers for its own local roles. */
#define	MER_MCH		1
#define	MER_GRP		1
#define	MER_EXEC_ADR	Numbers_To_Address( MER_MCH, MER_GRP, 1, 0 )
#define	MER_EDGE_ADR	Numbers_To_Address( MER_MCH, MER_GRP, 2, 0 )

/* application msg function codes (>= 0; negative codes are msg-internal) */
#define	MER_F_ADD	1
#define	MER_F_GET	2
#define	MER_F_CRASH	90
#define	MER_F_EXIT	91
#define	MER_F_REPLY	100

#define	MER_MAX_FRAME	256		/* largest accepted UDP request */

typedef	struct	{			/* request body (edge -> exec) */
	u32	reqid;
	s32	value;
}	MerReq_t;

typedef	struct	{			/* reply body (exec -> edge) */
	u32	reqid;
	s32	status;			/* 0 ok, else error code */
	s32	count;
	u32	generation;
}	MerRep_t;

/* persistent state, one mapped file per host, owned by mexec */
#define	MER_MAGIC	0x4D455231	/* "MER1" */
#define	MER_VERSION	1

typedef	struct	{
	u32	magic;
	u32	version;
	u32	generation;		/* +1 on every mexec start */
	u32	last_reqid;		/* last applied ADD (dedupe of a retry) */
	s32	last_count;
	atom_32	count;
}	MerState_t;

#endif
```

`meridian/mexec.c`. The startup order is the restart rule: map the state, then
`MsgInit`, then `MsgRead`:

```c
/* mexec: execution role.  Startup order:
 *   1. map the operator-provisioned state file (never create or resize it)
 *   2. validate magic/version, bump generation
 *   3. MsgInit: create/attach this role's msg FIFO + buffer file
 *   4. MsgRead loop: resume with the next message already queued
 */
#include	<meridian.h>
#include	<map.h>
#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<signal.h>
#include	<unistd.h>
#include	<sys/stat.h>
#include	<fcntl.h>
#include	<sys/mman.h>

static	volatile sig_atomic_t	stop_flag;
static	void	on_term( int s ) { stop_flag = s; }

static	MerState_t *	map_state( char * path )
{
	struct	stat	sb;
	MerState_t *	st;

	/* The state file is provisioned by the operator (meridianmem --create) before
	 * the first start.  mexec never creates or resizes it: a missing or
	 * wrong file is a fatal error, so the supervisor's start limit trips and
	 * someone looks, instead of the service starting from empty state. */
	if( path[ 0 ] != '/' )
		FatalError( "mexec: state path %s is not absolute", path );
	if( stat( path, &sb ) != 0 )
		FatalError( "mexec: %s: %s (provision it with meridianmem --create)",
			path, strerror( errno ) );
	if( sb.st_size != (off_t)sizeof( MerState_t ) )
		FatalError( "mexec: %s is %lld bytes, expected %u; refusing to resize",
			path, (long long)sb.st_size, (unsigned)sizeof( MerState_t ) );
	if( ( st = (MerState_t *)MapFile2Mem( path, sizeof( MerState_t ), PROT_WRITE ) ) == NULL )
		FatalError( "mexec: cannot map %s", path );
	if( st->magic != MER_MAGIC || st->version != MER_VERSION )
		FatalError( "mexec: %s has magic %08X version %u; not provisioned for this release",
			path, st->magic, st->version );
	st->generation++;
	msync( st, sizeof( *st ), MS_SYNC );
	return( st );
}

int	main( int argc, char ** argv )
{
	char		path[ 512 ];
	char *		dir;
	MerState_t *	st;
	Msg_t		m, r;
	MerReq_t	q;
	MerRep_t	a;
	s32		f;

	LocalName = "mexec";
	if( ( dir = getenv( "MERIDIAN_STATE" ) ) == NULL || *dir == 0 )
		FatalError( "mexec: MERIDIAN_STATE (state directory) not set" );
	snprintf( path, sizeof( path ), "%s/meridian.state", dir );

	st = map_state( path );				/* 1 + 2 */
	MsgInit( MER_EXEC_ADR, NULL, NULL );		/* 3 */
	umask( 077 );	/* msg/far set umask 0 while creating kill scripts */
	signal( SIGPIPE, SIG_IGN );	/* a dead reader gives EPIPE, not death */
	signal( SIGTERM, on_term );
	signal( SIGINT, on_term );
	EventLog( "mexec: up gen %u count %d", st->generation, S32_Read( &st->count ) );

	while( !stop_flag ) {				/* 4 */
		if( ( f = MsgRead( &m, 1 ) ) == MSG_TIMEOUT ) continue;
		if( m.head.length != sizeof( MsgHead_t ) + sizeof( MerReq_t ) ) {
			EventLog( "mexec: drop function %d length %u", f, m.head.length );
			continue;
		}
		memcpy( &q, m.body.data, sizeof( q ) );
		memset( &a, 0, sizeof( a ) );
		a.reqid = q.reqid;
		switch( f ) {
		case MER_F_ADD:
			if( q.reqid != 0 && q.reqid == st->last_reqid ) {
				a.count = st->last_count;	/* retry: do not apply twice */
				break;
			}
			a.count = S32_Add_Return( q.value, &st->count );
			st->last_count = a.count;
			st->last_reqid = q.reqid;
			break;
		case MER_F_GET:
			a.count = S32_Read( &st->count );
			break;
		case MER_F_CRASH:
			EventLog( "mexec: CRASH requested (reqid %u)", q.reqid );
			abort( );
		case MER_F_EXIT:
			EventLog( "mexec: EXIT %d requested (reqid %u)", q.value, q.reqid );
			exit( q.value );
		default:
			a.status = 1;
			break;
		}
		a.generation = st->generation;
		memset( &r, 0, sizeof( r ) );
		memcpy( r.body.data, &a, sizeof( a ) );
		MsgSend( m.head.source, MER_F_REPLY, &r,
			 sizeof( MsgHead_t ) + sizeof( a ), 0 );
	}
	msync( st, sizeof( *st ), MS_SYNC );
	EventLog( "mexec: stop signal %d count %d", (int)stop_flag, S32_Read( &st->count ) );
	return( 0 );
}
```

`meridian/medge.c`:

```c
/* medge: near edge role.  UDP request -> msg -> mexec -> msg -> UDP reply.
 * Usage: medge BIND_IP PORT      (e.g. medge 0.0.0.0 7300)
 * Request frames (ASCII, one datagram, <= 256 bytes, fixed tokens only):
 *   ADD <reqid> <value>   GET <reqid>   CRASH <reqid>   EXIT <reqid> <status>
 * Replies: "OK <reqid> <count> gen=<generation>" or "ERR <reason>".
 * CRASH/EXIT are refused unless MERIDIAN_FAULTS=1 (lab fault injection).
 */
#include	<meridian.h>
#include	<near.h>
#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<signal.h>
#include	<unistd.h>
#include	<sys/stat.h>

static	volatile sig_atomic_t	stop_flag;
static	void	on_term( int s ) { stop_flag = s; }

static	int	parse_u32( const char * s, u32 * out )
{
	char *		e;
	unsigned long	v;

	if( s == NULL || *s < '0' || *s > '9' ) return( -1 );
	errno = 0;
	v = strtoul( s, &e, 10 );
	if( errno || *e != 0 || v == 0 || v > 0xFFFFFFFFUL ) return( -1 );
	*out = (u32)v;
	return( 0 );
}

static	int	parse_s32( const char * s, s32 lo, s32 hi, s32 * out )
{
	char *	e;
	long	v;

	if( s == NULL || *s == 0 ) return( -1 );
	errno = 0;
	v = strtol( s, &e, 10 );
	if( errno || *e != 0 || v < lo || v > hi ) return( -1 );
	*out = (s32)v;
	return( 0 );
}

static	void	reply( int fd, char * text )
{
	UDP_Send( UDP_Read_IP, UDP_Read_Port, fd, text, (s_t)strlen( text ) );
}

int	main( int argc, char ** argv )
{
	char		frame[ MER_MAX_FRAME + 2 ], out[ 128 ];
	char *		tok[ 4 ];
	char *		save;
	int		fd, n, faults;
	s_t		len;
	s32		f, fn;
	Msg_t		m, r;
	MerReq_t	q;
	MerRep_t	a;

	if( argc != 3 ) {
		fprintf( stderr, "usage: %s BIND_IP PORT\n", argv[ 0 ] );
		return( 2 );
	}
	LocalName = "medge";
	faults = getenv( "MERIDIAN_FAULTS" ) != NULL &&
		 strcmp( getenv( "MERIDIAN_FAULTS" ), "1" ) == 0;

	MsgInit( MER_EDGE_ADR, NULL, NULL );	/* our FIFO for replies */
	umask( 077 );
	if( ( fd = UDP_Open( argv[ 1 ], argv[ 2 ], NULL, NULL ) ) < 0 )
		FatalError( "medge: UDP_Open %s:%s failed", argv[ 1 ], argv[ 2 ] );
	signal( SIGPIPE, SIG_IGN );	/* a dead reader gives EPIPE, not death */
	signal( SIGTERM, on_term );
	signal( SIGINT, on_term );
	EventLog( "medge: listening udp %s:%s fd %d", UDP_Open_IP, UDP_Open_Port, fd );

	while( !stop_flag ) {
		len = UDP_Read_With_Timeout( fd, frame, MER_MAX_FRAME + 1, 1000 );
		if( len == -2 ) continue;			/* timeout */
		if( len < 0 ) FatalError( "medge: UDP read error %s", strerror( errno ) );
		if( len == 0 ) continue;
		if( len > MER_MAX_FRAME ) { reply( fd, "ERR frame-too-long\n" ); continue; }
		frame[ len ] = 0;
		if( memchr( frame, 0, (size_t)len ) != NULL ) { reply( fd, "ERR nul\n" ); continue; }
		while( len > 0 && ( frame[ len - 1 ] == '\n' || frame[ len - 1 ] == '\r' ) )
			frame[ --len ] = 0;

		for( n = 0, save = NULL; n < 4; n++ )
			if( ( tok[ n ] = strtok_r( n ? NULL : frame, " ", &save ) ) == NULL ) break;
		if( n == 4 && strtok_r( NULL, " ", &save ) != NULL ) n = 5;

		memset( &q, 0, sizeof( q ) );
		fn = -1;
		if( n >= 2 && parse_u32( tok[ 1 ], &q.reqid ) == 0 ) {
			if( n == 3 && strcmp( tok[ 0 ], "ADD" ) == 0 &&
			    parse_s32( tok[ 2 ], -1000000, 1000000, &q.value ) == 0 )
				fn = MER_F_ADD;
			else if( n == 2 && strcmp( tok[ 0 ], "GET" ) == 0 )
				fn = MER_F_GET;
			else if( faults && n == 2 && strcmp( tok[ 0 ], "CRASH" ) == 0 )
				fn = MER_F_CRASH;
			else if( faults && n == 3 && strcmp( tok[ 0 ], "EXIT" ) == 0 &&
				 parse_s32( tok[ 2 ], 1, 125, &q.value ) == 0 )
				fn = MER_F_EXIT;
		}
		if( fn < 0 ) { reply( fd, "ERR bad-request\n" ); continue; }

		memset( &m, 0, sizeof( m ) );
		memcpy( m.body.data, &q, sizeof( q ) );
		MsgSend( MER_EXEC_ADR, fn, &m, sizeof( MsgHead_t ) + sizeof( q ), 0 );

		for( ;; ) {				/* bounded wait for our reply */
			f = MsgRead( &r, 2 );
			if( f == MSG_TIMEOUT ) { reply( fd, "ERR timeout\n" ); break; }
			if( f != MER_F_REPLY ||
			    r.head.length != sizeof( MsgHead_t ) + sizeof( MerRep_t ) ) continue;
			memcpy( &a, r.body.data, sizeof( a ) );
			if( a.reqid != q.reqid ) continue;	/* stale reply */
			if( a.status != 0 ) snprintf( out, sizeof( out ), "ERR status %d\n", a.status );
			else snprintf( out, sizeof( out ), "OK %u %d gen=%u\n",
					a.reqid, a.count, a.generation );
			reply( fd, out );
			break;
		}
	}
	EventLog( "medge: stop signal %d", (int)stop_flag );
	return( 0 );
}
```

`meridian/makefile` (the program rule passes `LIBRARIES` to make as
prerequisites, so do **not** put `-Wl,…` linker flags here):

```make
include		../rules.mak
CHDRS =		$(HDR)/meridian.h
LIBRARIES =	-lnear -lmsg -laddr -lmio -lmap -lsem -lfar -lnow -lsys
include		../targets.mak
include	.depend
```

Facts from the unit sources that this code depends on:

- `MsgInit(adr, quit, print)` with a non-zero address creates the FIFO
  `$PIPE_PATH/XXXXXXXX.que` and opens it read-write **on fd 0**. It maps the
  2100-slot buffer file `XXXXXXXX.mem` (1024-byte `Msg_t` each). The FIFO
  carries only 2-byte slot numbers; the message itself sits in the mapped file.
- `MsgRead(&m, seconds)` returns the function code, or `MSG_TIMEOUT` (`-1`).
  Negative codes are handled inside msg: `-2` trace, `-3` quit, `-4` stub,
  `-5` peer. Use codes `>= 0` for your own messages.
- `MsgSend(adr, func, msg, len, expire)` fills in `source`, `pid` and `sent`.
  With `expire != 0` a full buffer is a `FatalError`. If no process has the
  target FIFO open, the write fails with `EPIPE` and the message is dropped.
  That is why both programs ignore `SIGPIPE`.
- `FatalError` logs, runs the quit handlers, sleeps 1 s and calls `exit(1)`.
  That is the fail-fast path systemd then respawns.
- `MsgInit` calls `CreateKillScript`, which writes `$KILL_PATH/.K<name>` and
  sets the process **umask to 0**. msg then creates FIFOs and `.mem` files with
  mode `0666`. The programs reset `umask(077)` right after `MsgInit`. Keep the
  run directory itself mode `0700` so other users cannot reach the FIFOs.
- `MapFile2Mem(path, len, PROT_WRITE)` creates a missing file and
  **resizes an existing file to exactly `len`**. `mexec` therefore checks the
  size first and refuses a mismatch rather than truncating.
  - `mexec` never creates its state file: the operator provisions it with
    `meridianmem --create` (P5), which writes the file with plain `open`/`write`.
    Letting `Map` create the file at service start also hit a map cache problem
    on first creation that corrupted state in testing. The `map` source is not
    changed here.
  - `UpdateMap` reported "Map Segment Not Found" for this mapping, so the code
    calls POSIX `msync` directly.
- `UDP_Read` NUL-terminates only when fewer bytes than the buffer length
  arrived. `medge` reads `MAX+1` bytes into a `MAX+2` buffer, so a 257-byte
  frame is detected and rejected.
- `UDP_Open` sets `SO_REUSEADDR` (and `SO_BROADCAST`). A second `medge` on
  the same port may therefore bind without an error; do not rely on bind
  failing to stop duplicates.

### P5. Build and local test

```sh
HOME=$PWD make                     # units + meridian; check *.log for errors
mkdir -p run/pipes run/state && chmod 700 run
export PIPE_PATH=$PWD/run/pipes/ KILL_PATH=$PWD/run/ ELOG_FILE=$PWD/run/event.log
export MERIDIAN_STATE=$PWD/run/state
./bin/mexec                         # before provisioning: exits 1, "provision it with meridianmem --create"
./bin/meridianmem --create $MERIDIAN_STATE/meridian.state   # operator step, once per host
./bin/meridianmem $MERIDIAN_STATE/meridian.state            # review the provisioned values
./bin/mexec &
./bin/medge 127.0.0.1 7300 &
printf 'ADD 1 5' | nc -u -w2 127.0.0.1 7300     # OK 1 5 gen=1
printf 'GET 2'   | nc -u -w2 127.0.0.1 7300     # OK 2 5 gen=1
```

Results from the test run (requests sent from a small Python UDP client):

```text
ADD 1 5     -> OK 1 5 gen=1
ADD 1 5 (retry same reqid) -> OK 1 5 gen=1          # not applied twice
ADD 2 10    -> OK 2 15 gen=1
256-byte frame -> OK 4 15 gen=1
257-byte frame -> ERR frame-too-long
rm -rf /    -> ERR bad-request                      # fixed tokens only, nothing executed
ADD 5 99999999 -> ERR bad-request                   # value out of range
CRASH 6 (faults off) -> ERR bad-request
CRASH 7 (MERIDIAN_FAULTS=1) -> ERR timeout ; mexec exit: SIGABRT
GET 8 after respawn -> OK 8 15 gen=2                # state kept, generation +1
EXIT 9 3 -> ERR timeout ; mexec exit: 3
ADD 10 1 while mexec down -> ERR timeout ; later GET -> 15   # lost: EPIPE, no reader
mexec SIGSTOPped; ADD 21/22/23 -> ERR timeout (x3)
mexec SIGKILLed; respawned; GET 24 -> OK 24 18 gen=5          # the 3 queued ADDs ran
missing state file    -> exit 1, "provision it with meridianmem --create"
wrong-size state file -> exit 1, "refusing to resize", file left at 10 bytes
foreign state file    -> exit 1, "has magic … not ours"
SIGTERM -> both exit 0, "stop signal 15" in event.log
```

What the queue test shows, precisely:

- Messages **written while the executor still had its FIFO open** (busy or
  hung) stay in the kernel FIFO, because `medge` keeps its write end open.
  Their slots stay in the mapped `.mem` file. The respawned executor maps its
  state, calls `MsgInit`, and its first `MsgRead` continues with those
  messages.
- Messages sent while **no** process has the FIFO open are lost (`EPIPE`).
- Nothing survives a reboot or the edge closing the FIFO: a FIFO is not
  durable storage. msg also reclaims slots older than 2 s, but only when the
  buffer is full.
- The client got timeouts for work that was then done. Retrying with the
  **same** `reqid` is safe only for the most recent request (`last_reqid`).
  Full idempotency (a request-ID table, durable queue, transactions) is
  application design.

### P6. Supervision: one supervisor, every role

Add the roles to `start-role` (still `exec`, so systemd signals the real PID):

```bash
mexec)	exec "$HOME/bin/mexec" ;;
medge)	exec "$HOME/bin/medge" 0.0.0.0 7300 ;;
```

User-level template (`~/.config/systemd/user/meridian@.service`). It extends
part 1's template; the role-specific environment is set here, and nothing is
read from the network:

```ini
[Unit]
Description=meridian role %i
Wants=network-online.target
After=network-online.target local-fs.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
UMask=0077
StateDirectory=meridian
Environment=HOME=%h/meridian/current
Environment=MERIDIAN_STATE=%S/meridian
Environment=PIPE_PATH=%t/meridian/pipes/
Environment=KILL_PATH=%t/meridian/
Environment=ELOG_FILE=%S/meridian/event.log
ExecStartPre=/usr/bin/mkdir -p -m 0700 %t/meridian/pipes
ExecStart=%h/meridian/current/bin/start-role %i
KillSignal=SIGTERM
TimeoutStopSec=5
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
```

- `%S` is the user state directory (`~/.local/state`) and `%t` the runtime
  directory (`$XDG_RUNTIME_DIR`). `StateDirectory=meridian` creates
  `%S/meridian` for the persistent state file.
- The FIFOs go in `%t`, which is cleared at logout/reboot. This matches the
  fact that FIFO contents never survive a reboot anyway.
- `Type=simple`: the programs do not call `sd_notify`, so do **not** use
  `Type=notify` or `WatchdogSec=` with them. A watchdog would need
  `sd_notify` calls added (libsystemd, `pkg-config --libs libsystemd`). For
  now a hang is detected only by your external health check (a real `GET`, not
  a ping), which then runs `systemctl --user restart`.
- Provision first (once per host, as the service user):
  `meridianmem --create ~/.local/state/meridian/meridian.state`. Then enable each
  role: `systemctl --user enable --now meridian@mexec meridian@medge`.
- An unprovisioned host makes `mexec` exit 1 at once. After 5 tries in 60 s the
  unit is `failed`, which is your alert. That is intended: the service must not
  invent its own state. (`ConditionPathExists=%S/meridian/meridian.state`
  would instead *skip* the start silently; this tutorial prefers the visible
  failure.)

Optional clean stop through msg itself, instead of SIGTERM. The `msg` CLI's
`send` sub-command sends the internal quit (`-3`) message:

```ini
ExecStop=%h/meridian/current/bin/msg send 0x01010100 0 quit
```

- The address is `mexec`'s (`Numbers_To_Address(1,1,1,0)`); `0` is the
  expire argument. The command word is matched as a **case-sensitive prefix**
  (`strncmp`), so `quit` (or `q`) works and `QUIT` does not.
- On receipt, `MsgInternal` calls the registered quit handler (none here) and
  exits with status 0. Because this is a systemd-initiated stop, `Restart=always`
  does not restart it.
- **Untested here:** the `msg` CLI cannot be built without `miomsg` (it calls
  `MioMsgInit`). Without it, keep the default SIGTERM stop, which was tested.
- The quit message is local-FIFO only. Never expose it on the network.

Unit tests of the supervision behaviour you can run on a host (not run here):

```sh
systemctl --user kill -s SIGKILL meridian@mexec        # respawned after 2 s
systemctl --user kill -s SIGSTOP meridian@mexec        # hang: NOT respawned by itself
systemctl --user kill -s SIGCONT meridian@mexec        # queued requests are then served
for i in 1 2 3 4 5 6; do systemctl --user kill -s SIGKILL meridian@mexec; sleep 3; done
systemctl --user status meridian@mexec                 # "start-limit-hit" -> failed
systemctl --user reset-failed meridian@mexec && systemctl --user start meridian@mexec
systemctl --user stop meridian@mexec                   # stays stopped (deliberate stop)
```

**Snapshot vs power test.** Restoring a VM snapshot tests nothing about
restart: no process ever ran on the frozen image. Do a real power-off/boot:

1. Record `GET`.
2. Cut power (or hard reset).
3. After boot (lingering enabled), check that both roles are active, that
   `GET` returns the same count with `gen` + 1, and that `event.log` shows
   "up gen N".

Then label it a power-loss test in your records. Writes that were not yet
`msync`ed before the cut can be lost.

### P7. Multi-host: same tree, per-host state

```text
 clients ──udp/7300──> your LB ──> host1: medge ─msg─> mexec ─> %S/meridian/meridian.state
                                └─> host2: medge ─msg─> mexec ─> (its own state file)
```

- Every host has the identical tree (Part 1, steps 8–9) and runs
  `meridian@medge` + `meridian@mexec`.
- Each host's count is its own. The mapped state file and the msg FIFOs are
  local; nothing replicates them, and `mio` inspection of a mapped file
  only works for processes on that same machine.
- A **process** crash is handled by systemd in place (the queued messages
  resume as above).
- A **dead host** is handled by moving its roles (Part 1, step 11a). The new
  host has the source tree but **no state** until the operator provisions it
  (`meridianmem --create`, then load a reviewed script, e.g. the last dump kept in
  your ops records). It never gets the dead host's memory or file. If
  the counts must move, the application has to copy or rebuild them from a
  durable source. Assign roles from your trusted ops records only, never from
  data received over the network.

### P8. Full-tree releases and rolling redeploy (untested commands)

Deploy the **whole tree**, never a single unit or binary. One host at a time:

```text
/srv/meridian/releases/<VERSION>/    complete project tree (base + all units + meridian), built
/srv/meridian/current -> releases/<VERSION>    symlink switched last
~/.local/state/meridian/             runtime state (separate from any release)
```

(Here the user-unit paths `%h/meridian/current` become `/srv/meridian/current`;
an administrator creates `/srv/meridian` once, owned by the service user. The
service runs without root.)

```sh
V=2026.11.05-1                                  # your release name
R=/srv/meridian/releases/$V
git clone https://github.com/smythereen/base.git "$R" && cd "$R"
git checkout <recorded-base-commit>
cp <your-repo>/project/project.repos <your-repo>/project/project.repos.lock <your-repo>/project/private.units .
HOME=$PWD ./repo/repo.sh fetch
while read -r u url ver rev; do [ -d "$u/.git" ] && git -C "$u" checkout -q "$rev"; done < project.repos.lock
HOME=$PWD make cleanup
HOME=$PWD make 'CFLAGS=-O2 -g -march=x86-64-v2 -fPIC -fcommon -I$(HDR) -Wno-implicit-int -Wno-address-of-packed-member'
! grep -qE 'error:|\*\*\* |Error [0-9]' *.log
git rev-parse HEAD; sha256sum project.repos.lock; git -C meridian rev-parse HEAD
ln -sfn "$R" /srv/meridian/current.new && mv -T /srv/meridian/current.new /srv/meridian/current
systemctl --user restart meridian@mexec meridian@medge
printf 'GET 1' | nc -u -w2 127.0.0.1 7300        # must answer OK with the old count
```

- `mv -T` of a prepared symlink is the atomic switch.
- Record and compare the base commit, the lock checksum **and your own app
  revision** on every host.
- Keep the last N release directories for rollback: point the symlink back
  and restart.
- Use the same compiler, `-march` baseline and `SYS_VARIANT` everywhere.
- Back up your git remotes (full history; `repo fetch` makes full clones) and,
  separately, the state directory. A release directory is not a backup of the
  state.
- A new release that changes `MerState_t` must bump `MER_VERSION`, use a new
  state file name, and migrate the data with P10. The old binary refuses a
  file it does not recognise, and the new one refuses a wrong-size file;
  neither truncates it.

### P10. Changing the state layout: dump to a script, reload into a new file

A restart can reuse the mapped state file only if its layout is unchanged.
When the structure changes (a field added, moved, widened or removed), do
**not** map the old file with the new program: `MapFile2Mem` resizes an
existing file to the new size and the bytes are then read with the wrong
layout. Instead, **dump the old state by field name with the old tool, edit
that dump as a script, and load it with the new tool into a new file.**

The tool is `meridianmem`, a small mio program in the same unit (`rules.mak`
installs it as `bin/meridianmem`). Its output lines are themselves `meridianmem`
commands, which is what makes the dump a reload script.

`meridian/meridianmem.c`:

```c
/* meridianmem: the meridian unit's <unit>mem tool (see "The <unit>mem
 * provisioning and restart contract").  Print or set state fields by NAME.
 * Usage: meridianmem STATE_FILE [ Field.Name [ Value ] ]
 * Output lines are themselves meridianmem commands, so a dump is a reload script.
 *        meridianmem --create STATE_FILE   (new file with this layout's defaults)
 * Refuses a file whose size is not sizeof( MerState_t ): never resizes. */
#include	<meridian.h>
#include	<map.h>
#include	<mem_io.h>
#include	<stdio.h>
#include	<string.h>
#include	<sys/stat.h>
#include	<sys/mman.h>
#include	<fcntl.h>
#include	<unistd.h>

#define	STRUCT	MerState_t
static	Mitem	meridianmem_l[ ] = {
	ITEM( HEXADECIMAL, u32, magic,         "file magic",            0, 0 ),
	ITEM( UNSIGNED,    u32, version,       "layout version",        0, 0 ),
	ITEM( UNSIGNED,    u32, generation,    "starts of mexec",       0, 0 ),
	ITEM( UNSIGNED,    u32, last_reqid,    "last applied ADD id",   0, 0 ),
	ITEM( SIGNED,      s32, last_count,    "count after last ADD",  0, 0 ),
	{ SIGNED, 0, (u_t)&((STRUCT *)0)->count, sizeof( s32 ), 1,
	  "count", "counter (atom_32)", 0, 0 },
	{ 0 }
};
#undef	STRUCT

int	main( int ac, char ** av )
{
	struct	stat	sb;
	MerState_t *	st;
	char		prefix[ 600 ];

	if( ac == 3 && strcmp( av[ 1 ], "--create" ) == 0 ) {
		MerState_t	d;
		int		fd;
		if( av[ 2 ][ 0 ] != '/' ) return( 2 );
		memset( &d, 0, sizeof( d ) );
		d.magic = MER_MAGIC;
		d.version = MER_VERSION;
		if( ( fd = open( av[ 2 ], O_WRONLY | O_CREAT | O_EXCL, 0600 ) ) < 0 ||
		    write( fd, &d, sizeof( d ) ) != (ssize_t)sizeof( d ) || fsync( fd ) != 0 ) {
			perror( av[ 2 ] );	/* O_EXCL: an existing file is never touched */
			return( 1 );
		}
		close( fd );
		return( 0 );
	}
	if( ac < 2 || ac > 4 ) {
		fprintf( stderr, "usage: %s STATE_FILE [ Field.Name [ Value ] ]\n", av[ 0 ] );
		return( 2 );
	}
	LocalName = "meridianmem";
	if( av[ 1 ][ 0 ] != '/' ) {	/* map resolves relative names via MEMORY_PATH */
		fprintf( stderr, "%s: give an absolute path\n", av[ 0 ] );
		return( 2 );
	}
	if( stat( av[ 1 ], &sb ) != 0 || sb.st_size != (off_t)sizeof( MerState_t ) ) {
		fprintf( stderr, "%s: %s missing or not %u bytes; not touching it\n",
			 av[ 0 ], av[ 1 ], (unsigned)sizeof( MerState_t ) );
		return( 1 );
	}
	if( ( st = (MerState_t *)MapFile2Mem( av[ 1 ], sizeof( MerState_t ), PROT_WRITE ) ) == NULL )
		return( 1 );
	snprintf( prefix, sizeof( prefix ), "meridianmem %s", av[ 1 ] );
	if( ac == 4 ) {
		Mitem *	i;
		char *	e;
		for( i = meridianmem_l; i->name != NULL; i++ )
			if( strcmp( i->name, av[ 2 ] ) == 0 ) break;
		if( i->name == NULL ) {
			fprintf( stderr, "%s: unknown field %s\n", av[ 0 ], av[ 2 ] );
			return( 2 );
		}
		errno = 0;	/* mio stores 0 for bad text: validate first */
		if( i->type == HEXADECIMAL ) strtoull( av[ 3 ], &e, 16 );
		else strtoll( av[ 3 ][ 0 ] == '+' ? av[ 3 ] + 1 : av[ 3 ], &e, 10 );
		if( errno || e == av[ 3 ] || *e != 0 ) {
			fprintf( stderr, "%s: bad value %s for %s\n", av[ 0 ], av[ 3 ], av[ 2 ] );
			return( 2 );
		}
		Input_Memory_Item( st, meridianmem_l, av[ 2 ], av[ 3 ] );
		msync( st, sizeof( *st ), MS_SYNC );
	}
	Output_Memory_Item( st, meridianmem_l, ac >= 3 ? av[ 2 ] : NULL, prefix );
	UnmapAddress( st, 1 );
	return( 0 );
}
```

```text
$ meridianmem /home/svc/.local/state/meridian/meridian.state
meridianmem /home/svc/.local/state/meridian/meridian.state magic         0x4D455231
meridianmem /home/svc/.local/state/meridian/meridian.state version       1
meridianmem /home/svc/.local/state/meridian/meridian.state generation    5
meridianmem /home/svc/.local/state/meridian/meridian.state last_reqid    23
meridianmem /home/svc/.local/state/meridian/meridian.state last_count    +18
meridianmem /home/svc/.local/state/meridian/meridian.state count         +18
```

Things about mio and map, learned from the source and tests, that the
procedure guards against:

- **Use absolute paths.** `Map` resolves a name that does not start with `/`
  or `.` under `$MEMORY_PATH`. In testing, a relative name silently created a
  second, empty file elsewhere. `meridianmem` refuses relative paths.
- **No size or schema check in mio itself.** `meridianmem` checks the file size and
  never creates a file except with `--create` (`O_EXCL`).
- **`Input_Memory_Item` returns nothing and does not report bad input**, so
  `meridianmem` checks the name against its descriptor list and parses the
  number itself first, exiting 2 on an unknown field or a bad value. Without
  that check, an unknown field name
  prints nothing and the exit status is still 0. A non-numeric value stored
  **0**. So check every loaded value afterwards (step 6 below).
- Generic `*mem` tools in the units (`tpmem`, and `near`'s
  `nearmem BOX [ Name [ Value ] ]`, which maps `near_BOX.mem` with
  `Near_Map(box, 1)` = `MapFile2Mem`) **create or resize** the file to their
  own compiled size. Never point a newer-layout tool at an older file. The same
  dump-and-reload method applies to them (`nearmem BOX > dump`), but `nearmem`
  itself is not buildable from published sources today (see P2).

Example: release 2 moves `count`, widens `last_count` to `s64`, and adds
`u32 limit` (default 1000). `MER_VERSION` becomes 2, and its `meridianmem` lists
the new fields:

```c
typedef	struct	{
	u32	magic;
	u32	version;
	atom_32	count;			/* moved */
	u32	generation;
	s64	last_count;		/* widened from s32 */
	u32	last_reqid;
	u32	limit;			/* new in version 2 */
}	MerState_t;
/* meridianmem_l: ITEM( SIGNED, s64, last_count, … ), ITEM( UNSIGNED, u32, limit, … ) */
```

The mexec in release 2 must use a **new file name**, for example
`meridian.v2.state`, so it can never map the version 1 file.

Procedure (`OLD`/`NEW` are the old and new release trees, `S` the state
directory). This was tested with a version 2 build of `meridianmem`; the service
stop/start lines are the systemd commands from P6:

```sh
OLD=/srv/meridian/releases/<v1>; NEW=/srv/meridian/releases/<v2>; S=$HOME/.local/state/meridian
# 1. quiesce: stop the edge first (no new work), then the executor
systemctl --user stop meridian@medge meridian@mexec
# 2. keep the old file untouched, with a checksummed copy
cp -p $S/meridian.state $S/meridian.state.v1.bak && sha256sum $S/meridian.state*
# 3. dump with the OLD tool
$OLD/bin/meridianmem $S/meridian.state > $S/dump.v1
# 4. turn it into a v2 script: new tool, new file; drop magic/version (set by --create)
awk -v t="$NEW/bin/meridianmem" -v f="$S/meridian.v2.state" \
    '$3=="magic"||$3=="version"{next} {print t, f, $3, $4}' $S/dump.v1 > $S/load.v2
echo "$NEW/bin/meridianmem $S/meridian.v2.state limit 1000" >> $S/load.v2
#    review load.v2 by hand: every new field gets a value, every dropped field
#    is removed on purpose, every changed meaning gets a converted value
# 5. create the new file and load it
$NEW/bin/meridianmem --create $S/meridian.v2.state
bash $S/load.v2 > /dev/null
# 6. verify each line was really applied (re-read every field)
while read -r tool file name value; do
	got=$($NEW/bin/meridianmem "$file" "$name" | awk '{print $4}')
	[ "$got" = "$value" ] || echo "MISMATCH $name: want $value got $got"
done < $S/load.v2
# 7. switch the release symlink (P8) and start: executor first, then the edge
systemctl --user start meridian@mexec meridian@medge
```

Test result: the dump `generation 5, last_reqid 23, last_count +18,
count +18` loaded into the v2 file with `limit 1000`, and all five lines
checked `ok`. A value of 3000000000 then fitted in the widened `last_count`.
An earlier run where the tool was not on `PATH` printed five `MISMATCH`
lines, which is exactly what step 6 is for. The v2 tool refused the v1 file
("not 32 bytes"), and the v1 file's checksum was unchanged.

Rules that keep this safe:

- **Rollback** is the old release plus the untouched `meridian.state` (and
  its `.bak`). Never delete or overwrite the old file during the upgrade.
- **Field names, not offsets**, carry the data, so moving fields is safe. A
  widened type is safe; a narrowed one needs a range check you do by hand. A
  field whose meaning changed needs a converted value, not a copy.
- **Arrays:** mio prints array elements, and their count is fixed by the
  struct. Changing an array size needs the same manual review.
- **msg queues:** do not upgrade while messages are queued. Step 1 stops the
  edge before the executor so nothing new arrives. The msg buffer file
  (`.mem`, 2100 slots of 1024 bytes) is msg's own layout and is not migrated by
  this procedure.
- **Portability:** a mapped file is raw memory of one ABI (here `linux-x86_64`,
  little-endian, the same compiler packing). Do not copy state files between
  different architectures. Use the text dump to move state, and only between
  matching field sets. C and C++ programs share the layout because both call
  the same C library and headers.
- There is no automatic migration tool in base or the units. The field list,
  defaults and conversions are your application's decisions.

### P9. Security limits of this example

- UDP with **no authentication or encryption**: lab or trusted network only.
  For anything public you need an authenticated protocol of your own design and
  firewall rules (allow 7300/udp from the balancer only).
- The edge accepts only fixed tokens with bounded numbers. It never runs a
  shell, never evaluates input, and copies only fixed-size structs into msg
  bodies (no pointers cross processes).
- Fault commands are refused unless `MERIDIAN_FAULTS=1`; never set it in
  production.
- Services run as an unprivileged user with `UMask=0077` and private run/state
  directories; msg's own `0666` file modes are contained by those directories.
- SSH between hosts uses keys you provisioned yourself, with normal host-key
  checking. Do not disable it or accept unknown host keys automatically.
- Nothing here is a performance or availability claim. Measure your own load.

---

## How the units work together

Individual unit READMEs describe one library. A live service is a **stack**:
shared state, inspectors, I/O waits, optional messaging, and your application
on top. This section is the integrated story.

### Public starter stack (what `make` fetches for project `NONE`)

```text
                    ┌─────────────────────────┐
                    │   your application      │
                    │   (protocol, policy,    │
                    │    supervision, HA…)    │
                    └───────────┬─────────────┘
          rate / intervals      │      files / sockets / select
               ┌────────────────┼────────────────┐
               ▼                ▼                ▼
            tp / tpi          far              map ──► shared .mem files
               │                │                │
               └──────┬─────────┴───────┬────────┘
                      ▼                 ▼
                     mio               sem
                      │                 │
                      ▼                 ▼
                     now               sys ◄── atomic (headers)
```

| Layer | Units | How they cooperate |
|---|---|---|
| Foundations | `sys`, `atomic` | `sys` gives types (`common.h`), process helpers, `EventLog` / print paths. `atomic` supplies `atomic_32.h` / `S32_*` for lock-prefixed counters. `sys` **requires** `atomic` (headers). |
| Time | `now` | Microsecond clocks/stamps. Needs `sys` **headers** only (`common.h`); does not include atomic itself. |
| Shared memory | `map`, `sem` | `map` mmaps files into the process (`Map`, `MapFile2Mem`, `UpdateMap`). `sem` is optional SysV-style mutual exclusion when several processes touch the same region—use it when you need those helpers, not by default for every map. `map` links `-lsem -lsys`. |
| Structured fields | `mio` | `Mitem` tables describe struct fields; `Input_Memory_Item` / `Output_Memory_Item` parse and print them. Works on **any** memory you point at—commonly a `map` region. Fetch needs `now`+`sys`; library `LIBRARIES` is empty (callers link `-lnow` when needed). **mio is not a message bus.** |
| File / socket I/O | `far` | **File Access Routines** (not “far calls”): open/read/write, dirs, FIFOs, sockets (`Listen4Host`), and `File_Test_For_Read_Data` (`select` with timeout). Links `-lsys`. |
| Rate accounting | `tp`, `tpi` | **Transactions Per** / **Transactions Per Interval** counters over mapped memory, with `mio` field tables for operator tools (`tp`, `*mem`, `tpi`, …). Link mio/map/far/sem/now/sys. Sources also use `atomic_32.h` even though current `UNIT.deps` omit `require atomic`. |

#### Concrete path: map + mio (live shared state you can inspect)

1. Define a C struct for control/data plane state (counters, flags, config).
2. Build an `Mitem[]` table (as `tp`/`tpi` do) naming each field for `mio`.
3. Persist the struct in a file and `MapFile2Mem` it (`map`) so every process
   sees the same bytes.
4. Operators run a small `*mem`-style tool: `Output_Memory_Item` to print live
   fields, `Input_Memory_Item` to patch a value, then `UpdateMap` if required.
5. **No automatic lock:** `map`+`mio` do not serialize writers. Add `sem` (or
   your own protocol) when concurrent mutation must be safe.
6. Minimum public units for this pattern: `map`, `mio`, `sys`, `now` (and
   `sem` if you lock). `tp` builds on the same idea with interval arrays.

#### Concrete path: far wait + your accept loop

`far` can listen (`Listen4Host`) and wait for readability
(`File_Test_For_Read_Data`: timeout `<0` forever, `0` poll, `>0` milliseconds).
Your code still owns framing, authentication, backpressure, and what “done”
means for a request. Pair with `map`/`mio` for shared control blocks and
`tp`/`tpi` if you bump per-interval rates around work you define.

#### Concrete path: atomic counters across processes

Put `atom_32` / `S32_*` fields inside a `map` region so workers share counters
without a full message round-trip. `sys` already uses this pattern internally
(e.g. print stamp). `tp`/`tpi` bump paths use the same primitives on mapped
interval state.

---

### Extended messaging stack (`addr` + `msg` + `near`)

John’s larger real-time servers often add three **extra** units that cooperate
as a messaging plane. They are **not** on the public starter list
(`sys atomic far map sem now mio tp tpi`). They **are** in the public catalog
worker, so `./repo/repo.sh add msg` (and `addr` / `near`) resolves their URLs
without `private.units`. They are still opt-in: a plain starter project does
not fetch them until you add them.

Their sources are published as public units (`github.com/smythereen/msg`,
`…/addr`, `…/near`); see **Tutorial part 2** for a working example with the
real APIs and the current build gaps (`near` needs the unpublished `sig`
header; the `msg` CLI needs `miomsg`).

| Unit | Role (architecture) |
|---|---|
| **addr** | Endpoint identity: a compact address (machine / group / program / subtask) and **name ↔ number** tables (often in mapped `addr.mem`) so humans and tools speak readable names while the wire uses numbers. |
| **msg** | In-process / inter-process **message** allocation and passing: a header (sync, source, target, function/type, length, timing fields) plus body; send/receive toward an address. Builds on addressing; typically sits on `map`/`far`/`sys` style foundations. |
| **near** | **Network Enhanced Access Routines**: UDP / UNIX-domain (and related) helpers so messages **traverse machines**—the transport edge of the messaging plane. |

#### Choose the chain (application → transport → message → address)

Think in layers when you design a multi-process or multi-host service:

```text
  Your application logic
        │  decides what happened / what to ask
        ▼
  near   ── network path between machines (when the peer is remote)
        │
        ▼
  msg    ── message in flight (header + body, source/target, function)
        │
        ▼
  addr   ── who is “target” / “source” (stable endpoint id ↔ name)
```

- **Local workers on one host:** application ↔ `msg` (and `addr` for names),
  often with `map` shared control; `near` may be unused or only for local
  UNIX sockets depending on deployment.
- **Remote route:** application → `near` (get bytes to the other machine) →
  peer `msg` stack → `addr` to interpret who the message is for.
- **Code roles:** `addr` does not carry payloads; `msg` does not replace your
  protocol semantics (it carries *your* function codes); `near` does not
  decide business logic—it moves datagrams/streams you hand it.

#### How this relates to the public `mio` / `map` plane

| Concern | Public units | Extended messaging |
|---|---|---|
| Shared struct fields operators can print/patch | `map` + `mio` (+ `sys`/`now`) | optional alongside messaging |
| Request/event between programs or hosts | *(you write it, or use extended stack)* | `msg` + `addr` (+ `near` off-box) |
| “Is mio messaging?” | **No.** mio = memory field representation | `msg` = message passing |

**Registration (exact public API, not a message bus):** core `mio` exposes

`MioRegisterHandler(Mtyp_t type, MioItemHandler input, MioItemHandler output)`

(`mem_core.c` / `mem_io.h`). The `Mtyp_t` enum includes `MSGADDR`, but **MSGADDR
has no built-in handler** in core mio—the header states you link a separate
helper and call `MioMsgInit()` for message-address fields. That helper
(`miomsg`) registers with
`MioRegisterHandler(MSGADDR, in_msgaddr, out_msgaddr)`. There is **no**
`mem_io_message_set` (or similar) API. Public starter `mio` is field print/parse
plus this registration hook; wiring `MSGADDR` and the `msg`/`addr`/`near` plane
remains an extended/private project choice via your own unit list.

#### Obtaining `msg` / `addr` / `near`

They are **not** returned by `GET /projects/NONE` (the starter list is
unchanged). They are in the catalog, so `./repo/repo.sh add msg` (and the same
for `addr` and `near`) is enough. Pass an explicit URL only when you need a
private fork or a non-catalog location (that writes **`private.units`**). See
Tutorial part 2 (P2) for what builds today.

---

### Picking a stack for a 24/7 service (summary)

1. **Always (public):** `base` → fetch `sys`+`atomic`; add `far` for I/O waits.
2. **Shared live state:** `map` (+ `sem` if you need those locks) + `mio`/`now`
   for operator-visible fields; `tp`/`tpi` if you want interval rates.
3. **Multi-program messaging (opt-in):** add `addr`+`msg`, and `near` when
   hosts must talk—from the public catalog (`repo add`), or via **your**
   `private.units` for a private fork. Not part of the starter list.
4. **Still your job:** protocol, accept-loop policy, batching, backpressure,
   systemd/watchdogs, multi-host failover, durable storage, metrics/alerting.



## `sys` types (`common.h`) and the Trace system

These facilities live in public `sys` (`common.h`, `sysprt.c`, `eventlog.c`) and
are the shared vocabulary almost every unit includes. They are **not** C bit-field
widths; the `u8`/`s32`/… names are **typedef aliases** for fixed-size integer
modes (and floats), selected with GCC `__attribute__((__mode__(…)))`.

### Fixed-width and host-size aliases

From `common.h`:

| Alias | Meaning in this tree |
|---|---|
| `u8` / `s8` | 8-bit unsigned / signed (`xN(8,Q)`) |
| `u16` / `s16` | 16-bit |
| `u32` / `s32` | 32-bit |
| `u64` / `s64` | 64-bit |
| `u128` / `s128` | 128-bit integer modes (`xN(128,T)`) when the compiler provides them |
| `uchar` | `u_int8_t` |
| `u_t` / `s_t` | `uintptr_t` / `intptr_t` — pointer-sized host aliases |
| `f32` / `f64` | 32- / 64-bit binary floats (`fN`) |
| `f80` | x87 extended (`long double` when `LDBL_MANT_DIG == 64` on i386/x86_64) |
| `f128` | IEEE quad when available (`long double` or `__float128`) |
| `f_t` | **Largest float actually present**: `f128`, else `f80`, else `f64` |
| `stamp_t` | `struct timeval` |

`F80_MANT_DIG` / `F128_MANT_DIG` / `F_T_MANT_DIG` are defined only when that
type exists. Do not assume every host has `f80` or `f128`.

**Word size / endian:** public `sys` for `SYS_VARIANT=linux-x86_64` is a
little-endian 64-bit Linux tree. `common.h` does **not** define `htonl` /
`ntohl` (or similar) helpers—network byte-order conversion is **not** a
built-in `sys` API in the public headers. Code that needs wire order must use
the usual libc converters or its own protocol unit. This variant is **not**
claimed portable to other endianness or ILP32-only targets; `atomic` headers
operate on `s32` counters (`atomic_32.h`) and assume the matching CPU atomics.

Linking `sys` does not require a separate `-latomic` for the inline `S32_*`
helpers—those are header inline asm once `atomic` headers are in `~/cmn`.

### Trace vs EventLog

| Mechanism | Role |
|---|---|
| **Trace / SysPrt** | Diagnostic print path, gated by bit flags in `TraceLevel` (or `*TracePointer`) |
| **EventLog** | Operational event lines appended to a log file (`ELOG_FILE` or `event.log`) |

They are different. Trace is for developer/ops diagnostics you can turn down.
EventLog is for durable-ish event records. A 24/7 service should **not** leave
high-volume Trace bits on unbounded; rotate or redirect print files
(`Initialize_Print` / `PrintDays`) and treat EventLog as the operational trail.
This README does not invent telemetry buffers or a metrics API.

### How Trace gating works (exact macros)

Globals in `sysprt.c` / `common.h`:

- `u32 TraceLevel` — per-process flag word (default 0 until you set it)
- `u32 *TracePointer` — if **non-NULL**, `Is_Trace_Level` reads `*TracePointer`
  instead (shared mapped flag word is a **convention** you wire; there is no
  built-in “mio Trace API”)
- `LocalName`, `PrintName`, `PrintPID`, `PrintStamp`, `PrintDays`, `PrintStdOut`

```c
/* common.h — simplified */
static inline int Is_Trace_Level( u32 x )
{
	return ( x ) == 0
	    || ( ( x ) & ( TracePointer != 0 ? *TracePointer : TraceLevel ) ) != 0;
}
#define If_Trace_Level( x )	if( Is_Trace_Level( x ) )
#define Trace( level, ... )	{ If_Trace_Level( level ) SysPrt( __VA_ARGS__ ); }
```

So `Trace(FLAG, "…%d", expr)` **does not evaluate** `expr` / call `SysPrt`
unless the level matches (or `FLAG == 0`, which always prints). Prefer `Trace`
over bare `printf` when you want that gating. Plain `printf` always runs.

`SysPrt` writes to **fd 2** (`write(2, …)`). Optional stamp/name/pid prefixes
use `PrintStamp` (atomic nest count), `PrintName`, `PrintPID`.
`Initialize_Print(path)` redirects stderr (and optionally stdout) to a trace
file; **`Initialize_Print(NULL)` fails (−1)**—for ordinary stderr you simply
do not call it. `Reset_Print` / `PrintDays` rotate `*.trc` style files when
configured.

### Public unit flag bits (from headers)

Use hex with `printf("%#x", …)` when documenting:

| Symbol | Value | Header |
|---|---|---|
| `SYS_TRC_LVL` | `0x80000000` | `common.h` |
| `FAR_TRC_LVL` | `0x40000000` | `far.h` |
| `MAP_TRC_LVL` | `0x08000000` | `map.h` |
| `SEM_TRC_LVL` | `0x08000000` | `sem.h` (same bit as map in current trees) |
| `BIT_TRC_LVL` | `0x04000000` | `bitops.h` |

There is **no** public `MIO_TRC_LVL` define. `now.h` has a commented
`NOW_TRC_LVL`. `tp.c` / `tpi.c` contain commented assignments to
`TP_TRC_LVL` / `TPI_TRC_LVL`, but those macros are **not** defined in the
current public headers—do not invent values.

Enable in `main` (or early init), for example:

```c
#include <common.h>
#include <map.h>

int main( void )
{
	LocalName = "mysvc";
	TraceLevel = SYS_TRC_LVL | MAP_TRC_LVL;	/* or TracePointer = &shared_flags; */
	Trace( MAP_TRC_LVL, "map path ready %#x\n", TraceLevel );
	/* … */
	return 0;
}
```

Build/link the smallest public path: `#include <common.h>`, link `-lsys`
(after `make header` so `atomic_32.h` is in `~/cmn`). Units often set
`TraceLevel = MAP_TRC_LVL` (etc.) locally inside a tool’s `main`.

## Portability limits

GNU make + Unix `cc`/`ar`/`ranlib` on **Linux**. Public `sys` is
`SYS_VARIANT=linux-x86_64` only. No Windows port is provided.

## File map (this repository)

Tracked essentials: `BASE`, `LICENSE`, `LICENSES/`, `README.md`, `UNITS.md`,
`.profile`, `.bash_profile`, `.bashrc`, `base.units`, `makefile`, the empty web directories (`www`, `html`, `html_sh`, `cgi-bin`, `styles`, `images`), `rules.mak`, `targets.mak`, `env.example`,
`project.repos.example`, `private.units.example`, `repo/*`, empty
`bin`/`cmn`/`hlp`/`lib`/`run`/`tmp` placeholders, `.gitignore`.

Gitignored project state (created locally): `project.repos`,
`project.repos.lock`, `private.units`, `units.mak`, `.built`,
`.rebuild-needed`, build logs and objects.
