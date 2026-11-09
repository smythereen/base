# Rust in the unit makefiles

Rust follows the C/C++ model. The compile rules are in `rules.mak` and the
unit targets (`header`, `bindings`, `library`, `product`, `clean`) are in
`targets.mak`. A unit makefile doesn't list any Rust files.

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
