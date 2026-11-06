# base

Project bootstrap for John R. Smythe Jr.'s public C **unit** system.

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

Each unit builds with its own makefile. The root makefile runs phases across
selected units: **header → library → product**. For each unit it runs
`make -C <unit> -S <target>` and keeps going to the next unit so one pass shows
good and bad units. Logs land in `header.log`, `library.log`, `product.log`.

`UNITS.md` is the longer make-system guide shipped in this repo.

## What base does

Base is only the **project shell**:

| Path | Purpose |
|---|---|
| `BASE` | Marker (`base-format: 1`); tools refuse trees without it |
| `makefile` | Master build + project populate/fetch/units.mak restart |
| `rules.mak` / `targets.mak` | Shared compile/install rules |
| `base.units` | Units that ship inside base (**only `repo`**) |
| `repo/` | Shell tools: `repo.sh`, `fetch-units.sh`, add/remove/list/… |
| `bin/` `cmn/` `lib/` `hlp/` `run/` `tmp/` | Empty install dirs (`.gitkeep`) |
| `project.repos.example` / `private.units.example` / `env.example` | Templates |

`sys` and `atomic` are **not** in base; they are on the starter list and are
fetched before compile.

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
4. Write `units.mak`, restart make, then `header` / `library` / `product`
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

Public catalog today is fixed read-only starter coverage. There is no public
create/delete/governance API documented in base.

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
printf '%s\n' 'base 1' 'require far' 'require mio' > mysvc/UNIT.deps
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

Keep `project.repos.lock` so builds share the same revisions. After intentional
updates: `repo update`, then `make cleanup && make`, then `repo rebuilt`.

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
2. Update one unit (`repo update sys` or edit list + fetch).
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

### Extended messaging stack (`addr` + `msg` + `near`) — conceptual

John’s larger real-time servers often add three **extra** units that cooperate
as a messaging plane. They are **not** on the public starter list
(`sys atomic far map sem now mio tp tpi`), **not** in the public catalog worker
used by default, and **`make` / `repo fetch` will not download them** unless
**you** supply URLs (for example via `private.units` in your own project).

This README describes their **roles and how they fit architecturally**, from
local project experience. It does **not** publish private source, secret APIs,
or fetch endpoints.

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

Optional message-oriented hooks inside some memory tooling are a **private /
extended** concern. The public `mio` unit is the structured memory printer and
parser.

#### Obtaining `msg` / `addr` / `near`

They are **not** returned by `GET /projects/NONE` and are **not** looked up in
the public catalog used with the published starter. In John’s extended or
private projects they are ordinary units: list them in `project.repos` and put
their git URLs in **`private.units`** (or another catalog you run yourself).
Public base does not document private cloud fetch URLs. If you only clone
public GitHub starter units, you will not get `msg`/`addr`/`near`.

---

### Picking a stack for a 24/7 service (summary)

1. **Always (public):** `base` → fetch `sys`+`atomic`; add `far` for I/O waits.
2. **Shared live state:** `map` (+ `sem` if you need those locks) + `mio`/`now`
   for operator-visible fields; `tp`/`tpi` if you want interval rates.
3. **Multi-program messaging on your private tree:** add `addr`+`msg`, and
   `near` when hosts must talk—via **your** `private.units`, not the public
   starter catalog.
4. **Still your job:** protocol, accept-loop policy, batching, backpressure,
   systemd/watchdogs, multi-host failover, durable storage, metrics/alerting.


## Portability limits

GNU make + Unix `cc`/`ar`/`ranlib` on **Linux**. Public `sys` is
`SYS_VARIANT=linux-x86_64` only. No Windows port is provided.

## File map (this repository)

Tracked essentials: `BASE`, `LICENSE`, `LICENSES/`, `README.md`, `UNITS.md`,
`base.units`, `makefile`, `rules.mak`, `targets.mak`, `env.example`,
`project.repos.example`, `private.units.example`, `repo/*`, empty
`bin`/`cmn`/`hlp`/`lib`/`run`/`tmp` placeholders, `.gitignore`.

Gitignored project state (created locally): `project.repos`,
`project.repos.lock`, `private.units`, `units.mak`, `.built`,
`.rebuild-needed`, build logs and objects.
