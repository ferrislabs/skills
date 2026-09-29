---
name: rust-dev
description: Binding Rust rules for Ferrislabs - dispatch order (static generics > enum > dyn), no async-trait, memory discipline (Cow, fewer clones, borrowed data), hexagonal boundaries, type-driven invariants, error handling, imports. Consult before writing, modifying, reviewing or designing any Rust code, and when answering Rust architecture questions. Not needed for merely reading or summarizing Rust.
---

# Rust development

Binding on top of `dev-methodology`. Details and examples in `references/`, loaded on demand.

## 1. Dispatch order

Choose in this order. Move down only with a reason.

1. **Static dispatch** (generics, `impl Trait`). Default.
2. **Enum dispatch.** Closed set of implementations known at compile time, or chosen at runtime from config.
3. **`dyn Trait`.** Only for: open sets (plugins), heterogeneous runtime collections, composition roots, or a measured compile-time/binary-size problem.

A `dyn` in a diff needs its reason in the PR description. Examples and trade-offs: `references/dispatch.md`.

## 2. No `async-trait`

Never add the `async-trait` crate. Use native `async fn` in traits, or `fn f(&self) -> impl Future<Output = T> + Send` when the future must be `Send` (multi-threaded tokio).

Consequence: such traits are not dyn-compatible. That is intended. It pushes toward rules 1 and 2. If you truly need `dyn` over async, use an enum, or box at the boundary by hand and say why.

An existing dependency on `async-trait` (third-party trait you must implement) is allowed. Do not spread it.

## 3. Memory

Measure before micro-optimizing (criterion, dhat). But these habits cost nothing and are default:

- Take `&str`, `&[T]`, `&Path`, not `String`, `Vec<T>`, `PathBuf`, unless you store it.
- Return `Cow<'a, str>` when you sometimes allocate and sometimes borrow.
- No `.clone()` to silence the borrow checker. First try: borrow, restructure, `Arc`, `mem::take`, `mem::replace`.
- Clone `Arc`/`Rc` with `Arc::clone(&x)` so cost is visible.
- Shared immutable text: `Arc<str>` or `Box<str>`, not `String`. Shared byte buffers: `bytes::Bytes`.
- Iterators over intermediate `Vec`. `collect()` only at the end.
- `Vec::with_capacity` when size is known or bounded.
- Deserialize borrowed data (`#[serde(borrow)]`, `&'de str`, `Cow`) on hot paths.

Full list, with code and lints: `references/memory.md`.

## 4. Hexagonal boundaries

- Domain imports nothing from infrastructure: no SQL, HTTP or framework types in entities or use cases.
- Ports are traits defined by the domain. Adapters implement them. Dependencies point inward.
- Convert at the boundary with `TryFrom`/`From` between DTO and domain types. No scattered validation.
- One adapter per external concern. Swapping one never touches the domain.
- Repository traits live in the domain. `sqlx` types never cross a port.
- Wire ports with generics or an enum (rule 1). The composition root is the only place that picks concrete types.
- Layout, conversions, violations table: `architecture/references/hexagonal.md`. No comments in code: see `architecture`.

## 5. Types carry invariants

- Newtypes for identifiers and secrets. Exhaustive enums for state machines. `NonZero*` / `Option` instead of sentinel values.
- Parse, do not validate: a `TryFrom` that returns a type proving validity.
- `#[must_use]` on types and functions whose dropped result is a bug.
- Secrets: `zeroize` on drop, no `Debug`/`Display` derive, never logged.
- Never ignore a `Result`. `unwrap`/`expect` only in tests, examples, provably infallible cases.

## 6. Errors

- Domain and libraries: `thiserror` enums, one per module boundary. No `anyhow` through ports.
- Binaries, top level only: `anyhow` or `eyre`.
- Add context at boundary crossings, not deep inside.

## 7. Imports

- `use` the item, call it bare: `use tokio::time::Instant;` then `Instant::now()`.
- Collision or vague name (`Error`, `Config`, `Handle`): import the parent module and qualify (`io::Error`).
- No glob imports except in test modules and preludes.

## 8. Before claiming done

Run, scoped to the crate: `cargo fmt --check`, `cargo clippy -p <crate> --all-targets -- -D warnings`, `cargo test -p <crate>`. Full workspace once at the end. Testing rules: `rust-testing`.

## Checklist for review

1. Any `dyn` without a reason?
2. Any `async-trait`?
3. Any `.clone()` that a borrow would replace? Any `String` param that could be `&str`?
4. Any infrastructure type inside the domain?
5. Any sentinel value, stringly-typed id, or `unwrap` in non-test code?
