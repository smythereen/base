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
| Each server | Linux x86-64 with glibc (the program links the unit `.a` libraries statically; `ldd` shows only libc), `systemd` with user services (or just a shell, see 9b), an open UDP port |
| C++ (optional) | `g++` on the build host; on servers, a compatible `libstdc++` **or** a static C++ runtime (step 3b) |
| Probing | `nc` (netcat with `-u`) **or** `python3`; both forms are shown |

The servers do **not** need make, gcc, git or the unit sources. They run the
artifact you built once.

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

**Runtime library:** a program linked by `g++` depends on the shared
`libstdc++.so.6` (and `libgcc_s`) unless you link it statically. Check with
`ldd bin/echoxx` before shipping. Either make sure every server has a
`libstdc++` at least as new as the build host's, or add
`-static-libstdc++ -static-libgcc` to the link (for example put them in the
unit's `LIBRARIES` after `-lsys`). Everything else in steps 5–12
(instances, systemd template, load balancer, rolling deploy) is identical:
replace `echoctr` with `echoxx` in the paths and the template name.

*Proof note:* the build host used for this tutorial had no `g++`, so the C++
example was compiled through the **same** `rules.mak` `.cc` rule with a clang
C++ driver passed as `CXX=…`, linked against the C archives `libfar.a`,
`libnow.a`, `libsys.a`, and probed (`pong cxx 1`, echo, `stats`, SIGTERM →
`stop signal 15 count 3` in `event.log`). With `g++` the command is the one
`rules.mak` prints: `g++ -MD -o echoxx $(CXXFLAGS) echoxx.cc -L$(LIB) -lfar -lnow -lsys`.

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
   `cleanup`, then `header` (headers → `~/cmn`, `atomic` first), `library`
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
| Restart | `kill -TERM` the process, re-run `./bin/echoctr …` | build **once**, copy the artifact, restart service units one host at a time |
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

### 8. Make a reproducible release artifact

base `.gitignore` ignores `project.repos`, `project.repos.lock`, `units.mak`
and build state, so **keep your project in its own git repository** (your
`echoctr` unit plus a copy of the list and lock). Record what produced the
binary and ship that record with it:

```sh
REL=echoctr-$(git -C echoctr rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
mkdir -p tmp/$REL/bin
cp -p bin/echoctr tmp/$REL/bin/
cp -p project.repos project.repos.lock tmp/$REL/
( cd tmp/$REL && sha256sum bin/echoctr > SHA256SUMS )
tar -C tmp -czf tmp/$REL.tar.gz $REL
sha256sum tmp/$REL.tar.gz
```

To rebuild the **same** unit revisions later on another build host, clone base,
put back `project.repos` and the lock, fetch, then pin each unit to the
recorded rev:

```sh
HOME=$PWD ./repo/repo.sh fetch
while read -r unit url ver rev; do
	[ -d "$unit/.git" ] && git -C "$unit" checkout -q "$rev"
done < project.repos.lock
HOME=$PWD ./repo/repo.sh status
```

(`repo fetch`/`update` otherwise move to the newest version.) The safest rule
is simpler: **build once, deploy that tarball everywhere, and compare
`sha256sum` on every host.**

### 9. Install on one server

Copy and unpack under the service user's own home (no root, nothing global):

```sh
REL=echoctr-abc1234                # your release name from step 8
scp tmp/$REL.tar.gz svc@host1:
ssh svc@host1 "mkdir -p ~/echoctr/releases ~/echoctr/run &&
  tar -C ~/echoctr/releases -xzf ~/$REL.tar.gz &&
  cd ~/echoctr/releases/$REL && sha256sum -c SHA256SUMS &&
  ln -sfn ~/echoctr/releases/$REL ~/echoctr/current"
```

#### 9a. User-owned systemd template unit

One template, one small environment file per instance (explicit server ID and
port; nothing hidden):

```sh
ssh svc@host1 'mkdir -p ~/.config/systemd/user ~/.config/echoctr'
ssh svc@host1 'cat > ~/.config/systemd/user/echoctr@.service' <<'EOF'
[Unit]
Description=echoctr UDP echo/counter instance %i
After=network-online.target

[Service]
Type=simple
EnvironmentFile=%h/.config/echoctr/%i.env
Environment=ELOG_FILE=%h/echoctr/run/event.log
WorkingDirectory=%h/echoctr/run
ExecStart=%h/echoctr/current/bin/echoctr ${SERVER_ID} ${PORT}
KillSignal=SIGTERM
TimeoutStopSec=5
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF
ssh svc@host1 'printf "SERVER_ID=host1-a\nPORT=7101\n" > ~/.config/echoctr/a.env'
ssh svc@host1 'systemctl --user daemon-reload &&
  systemctl --user enable --now echoctr@a &&
  systemctl --user status --no-pager echoctr@a'
```

User services stop at logout unless lingering is enabled for that account. That
is a one-time admin action on each host: `sudo loginctl enable-linger svc`.

Day-to-day control:

```sh
systemctl --user stop    echoctr@a     # SIGTERM -> "stop signal 15" in event.log
systemctl --user start   echoctr@a
systemctl --user restart echoctr@a
journalctl --user -u echoctr@a -n 20   # stderr trace lines
tail -n 20 ~/echoctr/run/event.log     # EventLog lines
```

A second instance on the same host is just another env file:
`printf "SERVER_ID=host1-b\nPORT=7102\n" > ~/.config/echoctr/b.env` then
`systemctl --user enable --now echoctr@b`.

#### 9b. Foreground alternative (no systemd)

```sh
cd ~/echoctr/run
ELOG_FILE=$PWD/event.log exec ~/echoctr/current/bin/echoctr host1-a 7101
```

Run it under `tmux`/`screen` or your own supervisor. Without a supervisor
nothing restarts it after a crash or reboot—that is your decision to make.

### 10. Multi-server topology

```text
             clients
                │  udp/7100
                ▼
     ┌─────────────────────┐   load balancer: YOUR process, YOUR config
     │  lb host (nginx)     │   (not provided by base or any unit)
     └──────┬────────┬─────┘
            │        │ udp/7101
            ▼        ▼
       host1:7101  host2:7101     same tarball, same sha256,
       echoctr@a   echoctr@a      different SERVER_ID per node
```

Repeat step 9 on `host2` with `SERVER_ID=host2-a`. Then verify each node
directly before putting a balancer in front:

```sh
for h in host1 host2; do
	ssh svc@$h 'sha256sum ~/echoctr/current/bin/echoctr; readlink ~/echoctr/current'
	printf 'ping' | nc -u -w1 $h 7101       # or: udpq $h 7101 ping
done
```

The `sha256sum` values must be identical; the `pong` replies must name
different server IDs.

Example balancer, **open-source nginx `stream` module** (one option; HAProxy,
LVS/IPVS, DNS or client-side lists also work). You install, run and pay for
it yourself—nothing here is deployed for you:

```nginx
# /etc/nginx/nginx.conf (top level, outside the http{} block)
stream {
    upstream echoctr_udp {
        server host1:7101 max_fails=3 fail_timeout=10s;
        server host2:7101 max_fails=3 fail_timeout=10s;
    }
    server {
        listen 7100 udp;
        proxy_pass echoctr_udp;
        proxy_responses 1;     # one reply datagram per request
        proxy_timeout 2s;
    }
}
```

`nginx -t && nginx -s reload`, then `printf 'ping' | nc -u -w1 lbhost 7100`
several times: replies alternate between `host1-a` and `host2-a`.
Open-source nginx only marks a node bad **passively** (after failed
requests); it does not actively probe. Active checks are your script (below)
or another balancer.

Counters are **per process**: each node counts only what it received. A
"cluster total" means summing `stats` from every node yourself. The `map`
module cannot fix that—an mmapped file lives on one machine.

### 11. Health monitoring and safe rolling deployment

A health probe that any monitor or cron job can call (exit 0 = healthy):

```sh
#!/usr/bin/env bash
# echoctr-check HOST PORT  -> prints the stats line, exits non-zero if no reply
set -u
reply=$(printf 'stats' | nc -u -w1 "$1" "$2") || true
[ -n "$reply" ] && { echo "$1:$2 $reply"; exit 0; }
echo "$1:$2 NO REPLY" >&2; exit 1
```

Rolling deployment, one host at a time, stopping at the first failure. Draining
a node from the balancer is shown as a comment because how you do it depends on
your balancer (edit the upstream and reload, mark it `down`, etc.):

```sh
#!/usr/bin/env bash
# roll-out REL host1 host2 ...   (REL = release name from step 8)
set -euo pipefail
REL=$1; shift
for h in "$@"; do
	echo "== $h"
	# 1. drain: remove $h from the LB upstream and reload the LB (your step)
	scp "tmp/$REL.tar.gz" "svc@$h:"
	ssh "svc@$h" "set -e
		mkdir -p ~/echoctr/releases
		tar -C ~/echoctr/releases -xzf ~/$REL.tar.gz
		cd ~/echoctr/releases/$REL && sha256sum -c SHA256SUMS
		ln -sfn ~/echoctr/releases/$REL ~/echoctr/current
		systemctl --user restart echoctr@a
		sleep 1
		systemctl --user is-active echoctr@a"
	./echoctr-check "$h" 7101 || { echo "== $h unhealthy: stop and roll back"; exit 1; }
	# 2. undrain: put $h back in the LB upstream and reload (your step)
done
echo "== all hosts on $REL"
```

Rollback is the same switch pointed at the previous release directory:

```sh
ssh svc@host1 'ln -sfn ~/echoctr/releases/<previous> ~/echoctr/current &&
  systemctl --user restart echoctr@a'
```

Facts that matter during a roll:

- `restart` sends SIGTERM; `echoctr` exits within about one second (its `far`
  wait timeout). Datagrams arriving during that gap are **lost**—UDP has no
  retry unless your client adds one.
- The counter restarts at 0 on every restart. If it must survive, persist it
  (a `map`ed file on that host, or your own storage) — that is application
  design.
- Mixed versions run side by side during a roll. Keep the request/response
  format backward compatible across one release, or drain completely first.
- Keep at least one healthy node in the balancer at all times; roll one node,
  check it, then the next.

### 12. What the application owns vs what base provides

| Concern | base + public units | Your application / operations |
|---|---|---|
| Fetching and building units | `repo`, `project.repos`, lock, `units.mak`, make phases | keeping list + lock in **your** repo; choosing when to update |
| Socket/file helpers, waits | `far` (`File_Test_For_Read_Data`, `Listen4Host`, …) | protocol, framing, auth, rate limits, backpressure |
| Time, logs, trace | `now`, `EventLog`, `Trace`/`TraceLevel` | log rotation and shipping, alerting |
| Shared state on **one** host | `map` (+`sem`, `atomic`) | anything shared **between** hosts: replication, consensus, a database |
| Process lifecycle | — | systemd/supervisor units, restart policy, lingering, resource limits |
| Load balancing | — | balancer software, its config, its own redundancy (one LB is a single point of failure) |
| Health and failover | — | probes, removing dead nodes, paging a human |
| Disks, backups, capacity | — | disk-full handling for `event.log`/trace files, backups, monitoring |
| Network | — | firewalls, port allocation, DNS, TLS/auth if needed |
| Deployment | — | artifact build, checksum, rolling procedure, rollback |

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
[ ] release build with portable -march; tarball + SHA256SUMS + lock
[ ] systemd user template per host, explicit SERVER_ID/PORT, linger enabled
[ ] each node probed directly; identical sha256 on every host
[ ] LB config you own; alternating replies through the LB
[ ] health check + one-host-at-a-time roll-out + tested rollback
```

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
`base.units`, `makefile`, `rules.mak`, `targets.mak`, `env.example`,
`project.repos.example`, `private.units.example`, `repo/*`, empty
`bin`/`cmn`/`hlp`/`lib`/`run`/`tmp` placeholders, `.gitignore`.

Gitignored project state (created locally): `project.repos`,
`project.repos.lock`, `private.units`, `units.mak`, `.built`,
`.rebuild-needed`, build logs and objects.
