# Memory discipline

Rule zero: measure before heroics. Tools: `criterion` (time), `dhat` or `heaptrack` (allocations), `cargo bloat` (size). Habits below are free and default. Anything that hurts readability needs a measurement.

## Borrow in parameters

```rust
fn greet(name: &str) {}          // not String
fn sum(xs: &[u32]) -> u32 {}     // not Vec<u32>
fn open(p: &Path) {}             // not PathBuf
```

Take ownership only when you store the value. For flexible callers on cold paths: `impl Into<String>` or `impl AsRef<str>`. On hot paths prefer `&str`.

## `Cow`: borrow unless you must change

```rust
use std::borrow::Cow;

fn normalize(input: &str) -> Cow<'_, str> {
    if input.contains('\t') {
        Cow::Owned(input.replace('\t', "    "))
    } else {
        Cow::Borrowed(input)
    }
}
```

Good fits: sanitizers, normalizers, escapers, error messages that are usually static, struct fields that are usually `'static`:

```rust
pub struct Label(Cow<'static, str>);   // Label(Cow::Borrowed("admin")) allocates nothing
```

`String::from_utf8_lossy` already returns `Cow<str>`. Do not `.to_string()` it early.

Do not use `Cow` when you always allocate, or when it forces lifetimes through five layers.

## Clones

Before writing `.clone()`, in order:

1. Borrow (`&T`).
2. Restructure so the borrow ends earlier (split a struct, scope a block).
3. Move it (`mem::take`, `mem::replace`, `Option::take`).
4. Share it (`Arc<T>`), and write `Arc::clone(&x)`.
5. Only then clone, when it is real ownership.

Common avoidable clones:

- Cloning to pass into a function that only reads. Change its parameter to a reference.
- `.iter().cloned().collect()` then reading. Iterate references.
- `x.clone()` inside a loop. Hoist it, or use `clone_from` to reuse an allocation.
- `.to_string()` / `.to_owned()` on a value that is already owned.
- Cloning a `Vec` to sort it. Sort in place, or `sort` a `Vec<&T>`.

Lints to enable in CI: `clippy::redundant_clone` (nursery), `clippy::clone_on_ref_ptr`, `clippy::needless_pass_by_value`, `clippy::implicit_clone`, `clippy::inefficient_to_string`.

## Cheap shared data

| Need | Use |
|------|-----|
| Shared immutable string | `Arc<str>` (or `Box<str>` if not shared) |
| Shared byte buffer, slicing without copy | `bytes::Bytes` |
| Small strings, most under ~23 bytes | `compact_str` / `smol_str` (only if measured) |
| Small vectors, usually 1 to 4 items | `smallvec` / `arrayvec` (only if measured) |
| Interned identifiers | a `Symbol(u32)` newtype + interner |

## Allocation

- `Vec::with_capacity(n)` when `n` is known or bounded. `String::with_capacity` too.
- Reuse buffers in loops: `buf.clear()` instead of a new `String` each iteration.
- `write!(buf, ...)` into an existing `String` instead of `format!` then push.
- Keep iterator chains lazy. `collect()` at the end, not between adapters.
- `Box<[T]>` / `Box<str>` for fixed data: drops the capacity field.
- Small enum variants: a huge variant inflates every value. `clippy::large_enum_variant` flags it. Box the big variant.

## Serde and parsing

```rust
#[derive(Deserialize)]
struct Event<'a> {
    #[serde(borrow)]
    kind: Cow<'a, str>,
    #[serde(borrow)]
    payload: &'a str,
}
```

`&'a str` fields fail on escaped strings; `Cow<'a, str>` with `#[serde(borrow)]` handles both. Parse from `&[u8]` / `&str` you already hold. Do not `read_to_string` then copy again.

## Async and tasks

- Do not clone large data into `tokio::spawn`. Move it in, or share `Arc`.
- Hold no lock across `.await`.
- Prefer bounded channels of small messages. Send `Arc<T>` or `Bytes`, not deep copies.
