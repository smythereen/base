# Rust in the unit makefiles

Rust follows the "Adding a language" rule in `README.md`. It mirrors the C
implementation rule for rule, and a standalone `foo.rs` with `fn main`
dropped into any unit builds and installs with plain `make`, just like
`foo.c`.

| C | Rust | File |
|---|---|---|
| `CC`, `CFLAGS` | `RUSTC`, `RSFLAGS` (`-g --edition=2021`) | rules.mak |
| `.c:` suffix rule (no deps; links `$(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES)`, fixes `.d`, `.depend`, `$(BIN)/x.old`, copies to `$(BIN)`) | `.rs:`, the same lines, with rustc | rules.mak |
| `.c.o` (`$(CC) -o $*.o -c -MD ...`, then `cat *.d > .depend`) | `.rs.o`: `$(RUSTC) -o $*.o $(RS_CFLAGS) --emit=obj,dep-info=$*.d ...`, then `cat *.d > .depend`. The object is for C to link (see below) | rules.mak |
| `.c.a` (compile, `ar` into `$@`) | `.rs.a`: a staticlib `foo.a` with the Rust runtime inside, so C links it like any `.a` and needs nothing extra. It is a whole archive, not one added member | rules.mak |
| `.c.s` (`-S`) | `.rs.s` (`--emit=asm`) | rules.mak |
| `.c.i` (`-P`, preprocess) | none: the Rust equivalent (`-Zunpretty=expanded`) works only on nightly rustc | |
| none | `.rs.ll` (`--emit=llvm-ir`), and `.rs.so` (a cdylib `foo.so` with the runtime inside, for C) | rules.mak |
| a handwritten `foo.h` | `.rs.h`: `$(CBINDGEN) $(CBINDGEN_FLAGS)` (`--lang c --cpp-compat`) writes the C header of `foo.rs`. A real suffix rule: a newer `foo.rs` remakes `foo.h` wherever `foo.h` is a prerequisite (see "C header from Rust") | rules.mak |
| `C_SRCS` (`main(`), `L_C_SRCS` | `RS_SRCS` (`fn main`), `L_RS_SRCS` | rules.mak |
| `ifneq L_OBJS` → `LIBRARY := $(LIB)/lib$(UNIT).a`, `.PRECIOUS` | `ifneq L_RS_SRCS` → `RS_LIBRARY := $(LIB)/lib$(RS_CRATE).rlib`, `.PRECIOUS` | rules.mak |
| `$(OBJS:.o=)` in `EXECUTABLES`, `PRODUCTS`; sources in `SOURCE` | `$(RS_SRCS:.rs=)`, the same lists | rules.mak |
| `LDEPS` (Follow-Up Variables) | `RS_LDEPS` (the `RS_EXTERN` rlibs) | targets.mak |
| `$(LIBRARY): $(L_OBJS)` `ar` rule, `.old` copy | `$(RS_LIBRARY): $(L_RS_SRCS)` rlib rule, `.old` copy | targets.mak |
| `% : %.c $(LIBRARY)` in 3 branches (`-l$(UNIT)` / `$(LIBRARY)` / no library), `.d` fix-up with `LDEPS` | `% : %.rs $(LIBRARY) $(RS_LIBRARY)`, the same 3 branches and fix-up, plus `RS_LDEPS` | targets.mak |
| `$(BIN)/% : %` install, `clean` | the same rule; `clean` also removes `$(RS_SRCS:.rs=)` and `.lib.rs` and moves `$(RS_LIBRARY)` to `.old` | targets.mak |

Everything can be overridden between `include ../rules.mak` and
`include ../targets.mak`, as for C. For example,
`L_RS_SRCS := $(filter-out wip.rs,$(L_RS_SRCS))`,
`$(RS_LIBRARY): version.txt`, or removing a program from `PRODUCTS` and
`EXECUTABLES`.

## What Rust adds that C does not have, and why

- **`RS_CRATE`** (`$(UNIT)` with `-` changed to `_`): a crate name must be a
  Rust identifier.
- **`RS_EXTERN`, `RS_EXTERN_ARGS`, `RS_LDEPS`**: the Rust counterpart of
  `LIBRARIES` and `LDEPS`. An rlib is passed with `--extern name=path`
  instead of `-l`. `RS_EXTERN := otherunit` lets programs use `otherunit::...`
  and relinks them when `~/lib/libotherunit.rlib` changes. The unit rlib also
  rebuilds then, because an rlib built against an old dependency fails to
  link.
- **`.lib.rs`**: a crate needs a root file. The rlib rule writes one
  `#[path = "foo.rs"] pub mod foo;` per library file. Library files refer to
  each other as `crate::foo`, and programs use them as `<unit>::foo`.
- **`-L$(LIB)` passed to rustc**: rustc looks there for the rlibs that
  `RS_EXTERN` crates depend on. The linker gets `LDFLAGS` as usual.
- **`-C link-args="..."`**: rustc passes this string to the linker. It is
  quoted, so the shell expands values such as `` `pkg-config --libs ...` ``
  in `LIBRARIES` just as it does on the gcc line.
- **`RS_CFLAGS`** (`--crate-type=lib -C panic=abort`) is used by `.rs.o`,
  `.rs.s` and `.rs.ll`. `panic=abort` keeps a Rust panic from unwinding into
  C. `.rs.a` and `.rs.so` use the same panic setting.
- **`RS_STD_LIBS`** (`~/lib/librs_std.a` plus the native libraries) is the
  Rust standard library for C links. `librs_std.a` is built once by a
  no-dependency rule in `rules.mak`. The C and C++ link rules in
  `targets.mak` append it (as `$(RS_STD)`) only when the unit links a Rust
  object, meaning a `foo.o` that has a `foo.rs` appears in `L_OBJS`, `OBJS`
  or `LIBRARIES`. Other units are unchanged.
- **Bindings** (`make bindings`, after `header`): each exported
  `~/cmn/foo.h` gets `~/cmn/foo.rs` from `bindgen`.
  - The `$(HDR)/%.rs : $(HDR)/%.h` rule is in `rules.mak`. The list
    (`RS_BINDINGS`, built from `CHDRS`) and `bindings::` are in `targets.mak`.
  - bindgen's depfile (`~/cmn/foo.rs.d`) makes an edit to `foo.h` or to an
    included `.def` X-macro regenerate `foo.rs`.
  - A `foo.rs` without the `foo.rs.bindgen` marker is handwritten, so make
    never overwrites it and `clean` never deletes it.
  - If bindgen is missing, bindings are skipped. `RS_BINDGEN=required` makes
    that an error, and `BINDGEN=` turns bindings off. `BINDGEN_FLAGS` and
    `RS_BINDGEN_CFLAGS` add options (C++ headers need `-x c++`).
  - Use a binding with `include!(concat!(env!("HOME"), "/cmn/foo.rs"));`.

## Linking a Rust object into C

All of these rules are opt-in. `make foo.o` (or `foo.a`, `foo.so`, `foo.s`,
`foo.ll`) runs them, and so does a unit that lists the file. Default discovery
doesn't change: a `foo.rs` without `fn main` still goes into the unit rlib.

```rust
// foo.rs: every function C calls is #[no_mangle] pub extern "C"
#[no_mangle]
pub extern "C" fn foo_add(a: i32, b: i32) -> i32 { a + b }
```

- **Into the unit's C library**, the same as a `.c` without `main`: put
  `L_OBJS += foo.o` between the includes. `.rs.o` builds `foo.o`, the `ar`
  rule adds it to `lib<unit>.a`, and C programs link it. Editing `foo.rs`
  rebuilds `foo.o` (through `.depend`), then the library, then the programs.
  If the unit has no C library sources, also set
  `LIBRARY := $(LIB)/lib$(UNIT).a`.
- **Straight into one program**: `LIBRARIES += foo.o` and `prog: foo.o`.
- **Using `std`**: nothing more is needed. `RS_STD_LIBS` is added
  automatically.
- **`#![no_std]` with a `#[panic_handler]`**: the object links into C with
  nothing extra, so set `RS_STD_LIBS =`. Keep the file out of the unit rlib
  with `L_RS_SRCS := $(filter-out foo.rs,$(L_RS_SRCS))`, and add
  `RS_LIBRARY :=` if that empties the list (as `tali` does with
  `LIBRARY =`).
- **The whole runtime in one file**: `make foo.a` (link it like any `.a`) or
  `make foo.so`.
- **Reading `foo.s`**: rustc writes DWARF 5 `.file` lines, so assemble it
  with `as --gdwarf-5` or `gcc -c -Wa,--gdwarf-5`.

## C header from Rust

The `.rs.h` suffix rule runs cbindgen on `foo.rs` and writes `foo.h`, with a
`FOO_H` include guard, `extern "C"` for C++ (`--cpp-compat`), the
`#[repr(C)]` structs and enums, and every `#[no_mangle] pub extern "C"`
function, plus a `foo.h.cbindgen` marker that says the header is generated.

- **It fires like any suffix rule** (`.y.c` from yacc is the model). Once
  `foo.h` is a prerequisite, a plain `make` after editing `foo.rs` remakes
  `foo.h`, then the C objects and programs that include it (gcc's `.d`
  files put `foo.h` in `.depend`), and `foo.o` from `.rs.o`. For an
  exported header (`$(HDR)/foo.h` in `CHDRS`) the header phase remakes
  `foo.h` and installs it, bindings remakes `~/cmn/foo.rs`, and the units
  that include `~/cmn/foo.h` rebuild. A second `make` does nothing.
- **The first time**, run `make foo.h` (no `.depend` names it yet), or list
  `$(HDR)/foo.h` in `CHDRS`. A deleted `foo.h` that `.depend` or `CHDRS`
  still names is remade.
- **Handwritten headers are never touched.** A `foo.h` without
  `foo.h.cbindgen` is handwritten. If a `foo.rs` of the same name is newer,
  a build prints `note: foo.h is handwritten (no foo.h.cbindgen), not made
  from foo.rs`, leaves `foo.h` as it is, and goes on (the C objects are not
  rebuilt, since `foo.h` did not change). An error here would break the
  unit's build over an unrelated Rust file. `make foo.h` named on the
  command line stops with an error instead. To silence the note, rename one
  of the two files or `touch foo.h`. To hand a header over to cbindgen,
  `touch foo.h.cbindgen`.
- **No loop with bindgen.** bindgen makes `~/cmn/foo.rs` from
  `~/cmn/foo.h`, so `.rs.h` must never make `~/cmn/foo.h` from it.
  targets.mak gives every installed `~/cmn/*.h` that is not this unit's
  (not in `CHDRS`, no local `foo.h`) an explicit empty rule (`OTHER_HDRS`),
  and each `CHDRS` header names its local `foo.h`
  (`$(HDR)/%.h : %.h`), so `.rs.h` is never chosen for a `~/cmn` header and
  make prints no circular-dependency warning. The rule also skips any `.rs`
  with a `.bindgen` marker.
- **cbindgen** comes from `cargo install cbindgen` (`~/.cargo/bin`). It is
  needed only when a header is actually written: with no cbindgen, the
  handwritten and bindgen cases above and an up to date `foo.h` cost
  nothing, and only a `foo.h` that must be remade stops with
  `error: cbindgen not found`.
- Commit `foo.h` and `foo.h.cbindgen` with `foo.rs`, so a box without
  cbindgen builds from the committed header. bindgen then makes
  `~/cmn/foo.rs` from an exported `foo.h` like any other header (on a box
  whose libclang lacks its own headers, run
  `make RS_BINDGEN_CFLAGS=-I$(gcc -print-file-name=include)` for `stdarg.h`).
- Two units with a header of the same name collide in `~/cmn` as for C.

Rust can call only the C ABI. To use C++ code, export `extern "C"` wrappers
from the C++ side and add `SYS_LIBS += -lstdc++`.
