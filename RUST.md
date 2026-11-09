# Rust in the unit makefiles

Rust follows the "Adding a language" rule in `README.md`. It mirrors the C
implementation rule for rule, and a standalone `foo.rs` with `fn main`
dropped into any unit builds and installs with plain `make`, just like
`foo.c`.

| C | Rust | File |
|---|---|---|
| `CC`, `CFLAGS` | `RUSTC`, `RSFLAGS` (`-g --edition=2021`) | rules.mak |
| `.c:` suffix rule (no deps; links `$(LDFLAGS) $(LIBRARY2) -l$(UNIT) $(LIBRARIES)`, fixes `.d`, `.depend`, `$(BIN)/x.old`, copies to `$(BIN)`) | `.rs:`, the same lines, with rustc | rules.mak |
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
- **No compile-only suffix rule** (C's `.c.o`, `.c.a`): Rust compiles a whole
  crate at once, not one object per file. The rlib rule next to the `ar` rule
  does it.
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

Rust can call only the C ABI. To use C++ code, export `extern "C"` wrappers
from the C++ side and add `SYS_LIBS += -lstdc++`.
