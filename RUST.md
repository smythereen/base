# Rust support in rules.mak / targets.mak

Helpers live in the `bin/` unit and install as `~/bin/bindgen-header` and
`~/bin/rust-unit-lib-root` (from the matching `*.sh` sources). See also
`~/RUST.md` after clone (this file) and `bin/profile_add` for a project login.

The shared unit make files can build Rust crate roots alongside C/C++.
Nested `mod` files are dependencies via `rustc --emit=dep-info`; they are
not treated as separate crate roots.

## Unit makefile variables

Far-style (recommended for programs): drop `anyname.rs` with `fn main` in the
unit directory and run `make` — no `RS_EXES` entry required.

```make
include		../rules.mak
CHDRS =
LIBRARIES :=	-lsys
include		../targets.mak
include		.depend
```

Optional overrides (set **after** `include ../rules.mak`, **before**
`include ../targets.mak`):

```make
# Auto-exe is on by default (RS_AUTO_EXES=yes): top-level *.rs matching a
# simple fixed-string `fn main` text heuristic (also matches async fn main) become executables.
# This is NOT a Rust parser — same spirit as the C main( grep.
RS_AUTO_EXES  := yes                 # set to no to disable discovery
RS_NO_EXES    :=                     # extra .rs files to exclude from auto-exe
RS_EXES       :=                     # optional explicit extras / only list if auto off
RS_STATICLIBS := add.rs              # -> libadd.a (C ABI staticlib)
RS_RLIBS      := rthelper.rs         # -> librthelper.rlib
RS_CDYLIBS    :=                     # -> libNAME.so
RS_OBJS       := objdemo.rs          # -> NAME.o (see limits)
RS_EXTRA_SRCS := nested.rs           # sibling modules (also excluded from auto-exe)

RSFLAGS       :=
RS_SYS_LIBS   := -lstdc++
LIBRARIES     := -lsys
```

Sibling `mod` files without `fn main` are not executables; rustc still
rebuilds them via `--emit=dep-info` when the crate root includes them.
Generated `~/cmn/*.rs` bindgen outputs live outside the unit dir and are
never auto crate roots. Same basename as a C/C++ `main` program in the
same unit is a hard make error (rename or `RS_NO_EXES` / `RS_AUTO_EXES=no`).

## Toolchain

- `RUSTC` defaults to `rustc`. Override if needed: `make RUSTC=/path/rustc`.
- If any `RS_*` crate-root list is non-empty and `rustc` is missing, the
  Rust recipes error clearly. Units with empty `RS_*` lists never invoke
  `rustc`, so ordinary C/C++ builds are unchanged.

## Linking Rust to existing C/C++ unit libraries

`LDFLAGS`, `LIBRARIES`, `SYS_LIBS`, and `RS_SYS_LIBS` are passed to rustc
as `-C link-arg=...` (order preserved). Typical form:

```make
LIBRARIES := -lmap -lfar -lsys
# rustc ... -C link-arg=-L/home/dev3/lib -C link-arg=-lsys ...
```

Full archive paths in `LIBRARIES` also work.

### C ABI requirement

Rust **cannot** call arbitrary C++ ABI symbols. From C++ (or C) export a
wrapper:

```c++
extern "C" int cxx_triple(int x) { return x * 3; }
```

Declare it in Rust:

```rust
extern "C" { fn cxx_triple(x: i32) -> i32; }
```

These rules do **not** run bindgen and add no new dependencies.

### C++ standard library

When a Rust program links a C++ unit library, add the platform C++ runtime
on Linux/g++:

```make
RS_SYS_LIBS := -lstdc++
```

(On systems that use libc++, use `-lc++` instead.)

## Library types

| Variable        | rustc crate type | Output        | Use |
|-----------------|------------------|---------------|-----|
| RS_STATICLIBS   | staticlib        | libNAME.a     | C/C++ or Rust consumers; C needs `RS_NATIVE_LIBS` |
| RS_RLIBS        | rlib             | libNAME.rlib  | Rust-only `extern crate` / `--extern` |
| RS_CDYLIBS      | cdylib           | libNAME.so    | Dynamic C ABI |
| RS_OBJS         | lib + emit=obj   | NAME.o        | Intermediate; **do not** `ar` into libUNIT.a without Rust runtime link info |

Rust `.o` files are **not** mixed into the unit's existing `lib$(UNIT).a`
by these rules. Prefer `RS_STATICLIBS` / `RS_CDYLIBS` for interoperability.

### C program linking a Rust staticlib

```make
$(CC) -o consumer consumer.c -L$(LIB) -ladd $(RS_NATIVE_LIBS)
```

Or inspect what this toolchain needs:

```bash
rustc --crate-type=staticlib add.rs --print=native-static-libs
```

### Linking a Rust object

Prefer `rustc` as the final linker so libstd and natives are pulled in:

```bash
rustc -o prog -C link-arg=objdemo.o -C link-arg=driver.o ...
```

## Dependency files

Unit makefiles must keep the usual trailing:

```make
include	.depend
```

## Dependency files

Recipes use `rustc --emit=dep-info` (with `link` or explicit `dep-info=`).
Generated `*.d` files are aggregated into `.depend` like the C/C++ rules.
Touching a nested module listed in the dep-info rebuilds the crate root.

## Example (far-style)

```make
include		../rules.mak
CHDRS =
LIBRARIES :=	-lsys
# anyname.rs with fn main is auto-built; nested.rs (no main) is a mod only
include		../targets.mak
include		.depend
```

```bash
cd ~/someunit && make product
```



## Automatic unit library (`lib<crate>.rlib`)

Like C sources without `main` going into `lib$(UNIT).a`, non-executable
top-level `*.rs` files (no `fn main` heuristic match) become modules of
**one** unit crate installed as `~/lib/lib<crate>.rlib` on `make library`.

- Default on: `RS_AUTO_LIB=yes`
- Crate name: unit directory name with `-`→`_`, non-alnum→`_`, leading digit prefixed `u_`
- Output is **rlib only** (does not replace or collide with native `lib$(UNIT).a`)
- Handwritten `lib.rs` is authoritative and is **never** overwritten; otherwise
  make generates `.rs_unit_lib.rs` with `pub mod …` for each root member
- Files already referenced as `mod name` from another library source are omitted
  from that generated root (fixed-string grep heuristic — not a Rust parser;
  macros/cfg/comments can false-positive; use `RS_NO_LIB` to exclude)
- Submodules of a library file `foo.rs` must use Rust's normal layout
  (`foo/bar.rs` or `foo/bar/mod.rs`), because `foo.rs` is a module of the
  unit crate root — not a crate root itself. Top-level sibling `bar.rs` is
  for binary crate roots or for a separate `pub mod bar` member.
- Explicit `RS_STATICLIBS` / `RS_RLIBS` / `RS_CDYLIBS` / `RS_OBJS` / `RS_NO_LIB`
  are excluded from auto membership; set `RS_AUTO_LIB=no` to disable

Same-unit executables automatically get:

```text
--extern <crate>=~/lib/lib<crate>.rlib
```

Cross-unit dependency (minimal makefile setting, not per-file targets):

```make
RS_EXTERN := otherunit
# -> --extern otherunit=~/lib/libotherunit.rlib
```

Import in Rust: `use otherunit::some_mod::fn_name;` (crate name = sanitized unit name).

### Far-style unit library example

```make
include		../rules.mak
CHDRS =
LIBRARIES :=
include		../targets.mak
include		.depend
```

With `alpha.rs` / `beta.rs` (no `main`) and `use_it.rs` (`fn main` + `use rs_libdemo::alpha::…`),
`make library product` builds `~/lib/librs_libdemo.rlib` and the executable.

## Per-header bindgen (separate `bindings` phase)

One binding file per **installed public header**, not per unit.

Root build order:

```text
make all  =>  header → bindings → library → product
```

Root logging (see master `makefile`): combined `~/header.log` / `~/bindings.log` / …
plus per-unit `~/log/<phase>/<unit>.log`. `log/` is a standard project dir
(`make dir`). Phases always continue and exit 0; grep logs for failures.

- `make header` **only** installs C/C++ headers into `~/cmn` (no bindgen)
- `make bindings` generates `~/cmn/foo.rs` from installed `~/cmn/foo.h`
- Root `make bindings` depends on `header` first so `common.h` and friends exist
  before any unit runs bindgen
- Unit `make header` stays header-only; unit `make bindings` generates that
  unit's CHDRS bindings (needs deps such as `common.h` already in `~/cmn`)
- `*.def` files in `CHDRS` are **type fragments** (X-macro enum/struct field
  lists) included by headers — they are installed to `~/cmn` but are **not**
  bindgen roots. Bindgen parses the owning `.h` with `-I~/cmn -I.` so those
  fragments expand like the C compile; `*.rs.d` records `.def` dependencies.


### C vs C++ headers (per-unit)

- Default bindgen parse is **C** (`BINDGEN_CFLAGS` / `RS_BINDGEN_CFLAGS`).
- C++ units (codec family) set `RS_BINDGEN_CFLAGS += -x c++` and
  `BINDGEN_FLAGS` with `--blocklist-file=.*/c++/.*`, `std::` / `__gnu_cxx::`
  blocklists, and `--no-layout-tests`. libclang uses the platform C++ standard
  library (clang 23 / libstdc++ from GCC 16 on guardian).
- Generated C++ **class** bindings include vtable pointers and mangled
  constructors/methods. That is **not** a full safe Rust method-call API;
  layout tests are off because virtual C++ layouts are not ABI-guaranteed in
  the Rust representation. Prefer POD/C APIs for FFI.
- (Private trees may need header fixes, e.g.) `sync.h` includes `<msg.h>` for `Msg_t`. `bitops.h` optionally includes
  `<linux/config.h>` via `__has_include` (absent on modern userspace; no
  `CONFIG_*` used) and `<common.h>` for `u32`. `vh.h` includes `<math.h>` for
  `sqrt`; `VH_Distance` is `static inline` and is **not** emitted without
  `--wrap-static-fns` (+ wrapper .c), which is out of current scope.

### Knobs

| Variable | Default | Meaning |
|----------|---------|---------|
| `RS_BINDGEN` | `auto` | `auto`: generate if `bindgen` exists; C-only units still succeed if it does not. `off`: never generate. `required`: fail if bindgen missing or generation fails. |
| `BINDGEN` | `$(PATH)` / `~/.cargo/bin/bindgen` | bindgen executable |
| `BINDGEN_FLAGS` | empty | extra bindgen flags (allowlists, formatter, …) |
| `BINDGEN_CFLAGS` | `$(INCLUDES) $(RS_BINDGEN_CFLAGS)` | clang args after `--` |
| `RS_BINDGEN_CFLAGS` | empty | unit-extra clang args |
| `BINDGEN_HEADER` | `~/bin/bindgen-header` | atomic helper |

Install tool (user-local, already used on guardian):

```bash
cargo install bindgen-cli
# ensure PATH contains ~/.cargo/bin
```

### Regeneration

Bindings rebuild when:

- the installed `~/cmn/foo.h` changes
- a transitive include changes (bindgen `--depfile` → `~/cmn/foo.rs.d`, included by make)
- bindgen options text changes (`~/cmn/.bindgen.options` stamp)

Unchanged headers do **not** regenerate every make.

Generation is atomic: write temp → success `mv`; on failure the previous `foo.rs` is kept. With `RS_BINDGEN=auto`, bindgen failures leave the old binding and do not fail the header target; with `required`, the target fails nonempty.

### Ownership / handwritten files

Generated files create a sidecar `~/cmn/foo.rs.bindgen`. If `foo.rs` exists **without** that sidecar, make refuses to overwrite (collision error). Do not hand-edit generated bindings without removing/renaming them and the sidecar.

Generated `~/cmn/*.rs` are **not** crate roots. Import them from a real crate root, e.g. `include!(concat!(env!("HOME"), "/cmn/foo.rs"));` or copy/symlink into the unit carefully (duplicate type risk below).

### Duplicate types across headers

Each header is bound independently. Shared types from includes such as `common.h` may be **emitted in every** `foo.rs` / `bar.rs`. Combining multiple generated files in one Rust crate can therefore redefine the same types. Realistic approaches:

- use one generated header module per crate, or
- add allowlists via `BINDGEN_FLAGS` (e.g. `--allowlist-file`), or
- wrap calls behind a single curated FFI module

This make integration does **not** provide a cross-header deduplicating binding framework.

### C ABI only

bindgen here targets C headers / `extern "C"` APIs. It does **not** invent C++ wrappers or bind arbitrary C++ ABI.

### Cleanup

Unit `make clean` removes that unit's `$(CHDRS)` and corresponding generated `$(CHDRS:.h=.rs)` plus sidecars/depfiles listed from `CHDRS`. It does not wipe unrelated `~/cmn/*.rs`.
