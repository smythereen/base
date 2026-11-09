# Rust in the unit makefiles

Rust follows the C/C++ model and the same split between the two include files.
A unit makefile doesn't list any Rust files.

- `rules.mak` has the defaults (`RUSTC`, `RSFLAGS`, `RS_EXTERN`, bindgen), the
  per-header bindgen rule, and the default lists `RS_SRCS`, `L_RS_SRCS`,
  `RS_EXES`, `RS_CRATE` and `RS_LIBRARY` (next to `C_SRCS`, `L_OBJS`,
  `LIBRARY`). The lists are added to `EXECUTABLES`, `PRODUCTS` and `SOURCE`
  there, the same way the C lists are.
- `targets.mak` has the rules built from those lists, next to the C ones: the
  unit rlib into `~/lib` (the counterpart of the `ar` rule), the program link
  `$(RS_EXES): % : %.rs $(RS_LIBRARY) ...`, the `RS_EXTERN` dependencies, and
  the `.c`/`.rs` name check.

So between `include ../rules.mak` and `include ../targets.mak` a unit can
change the Rust lists, add dependencies, or add rules, exactly as it does for
C. For example, `L_RS_SRCS := $(filter-out wip.rs,$(L_RS_SRCS))` or
`$(RS_LIBRARY): version.txt`. As with C, if a unit changes `RS_EXES`, it
should change `PRODUCTS` and `EXECUTABLES` to match.

| C/C++ | Rust |
|---|---|
| `*.c`/`*.cc` containing `main(` → program, installed in `~/bin` | top-level `*.rs` containing `fn main` → program, installed in `~/bin` |
| other `*.c`/`*.cc` → `~/lib/lib<unit>.a` | other top-level `*.rs` → `~/lib/lib<unit>.rlib` (crate `<unit>`, `-` becomes `_`) |
| `LIBRARIES`, `SYS_LIBS` | also passed to the Rust link (`-C link-arg=`), with the unit's own `lib<unit>.a` |
| `-MD` → `.depend` | `rustc --emit=dep-info` → `.depend` |

The unit crate's root is `lib.rs` when the unit has one. Otherwise make
writes `.lib.rs` with `#[path = "foo.rs"] pub mod foo;` for each library
file. Library files refer to each other as `crate::foo`, and the unit's
programs use them as `<unit>::foo`.

Units can set two variables, between `include ../rules.mak` and
`include ../targets.mak`:

```make
RS_EXTERN :=	otherunit	# link ~/lib/libotherunit.rlib (use otherunit::...)
RSFLAGS +=	-O		# default: -g --edition=2021
```

A program and its unit crate relink when the `~/lib/lib<extern>.rlib` they
use changes. A `.c` and a `.rs` program with the same name in one unit is an
error.

Rust can call only the C ABI. When a Rust program needs C++ code, export
`extern "C"` wrappers from the C++ side and add `SYS_LIBS += -lstdc++`.

## Bindings (`make bindings`, after `header`)

Each exported `~/cmn/foo.h` (in `CHDRS`) gets a `~/cmn/foo.rs` from `bindgen`.
`*.def` X-macro fragments are installed by `header` and expanded by clang
inside the headers that include them. bindgen's `--depfile` output
(`~/cmn/foo.rs.d`) makes an edit to `foo.h` or any `.def`/`.h` it includes
regenerate `foo.rs`.

- If bindgen isn't installed (`cargo install bindgen-cli`, which needs
  libclang), bindings are skipped. `RS_BINDGEN=required` makes that an
  error, and `BINDGEN=` turns bindings off.
- `BINDGEN_FLAGS` adds bindgen options, and `RS_BINDGEN_CFLAGS` adds clang
  options. C++ headers need `-x c++`.
- A generated file has a `foo.rs.bindgen` marker. A `foo.rs` without the
  marker is handwritten, so make never overwrites it and `clean` never
  deletes it.
- When bindgen fails, the old `foo.rs` stays and make reports
  `bindgen failed`. That failure is an error only when `RS_BINDGEN=required`.
- Generated files aren't crate roots. Bring one in with
  `include!(concat!(env!("HOME"), "/cmn/foo.rs"));`. Each header is bound by
  itself, so common types can repeat across files. Include one binding per
  module.
