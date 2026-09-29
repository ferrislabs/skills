---
name: rust-testing
description: Testing rules for Rust at Ferrislabs - unit tests on the domain, integration tests on adapters, Gherkin scenario tests (cucumber-rs), property tests, and deterministic simulation tests when the system is concurrent, distributed or time-dependent. Consult before writing or reviewing any Rust test, when choosing a test level, or when a spec's acceptance criteria must become executable.
---

# Rust testing

Extends `dev-methodology` (TDD, reproduce before fixing) and `rust-dev`.

## Pick the level

| Level | Target | Real I/O | Tooling |
|-------|--------|----------|---------|
| Unit | Domain, pure logic | none | `#[test]`, `proptest` |
| Integration | One adapter against its real backend | yes | `testcontainers`, CI services, `tests/` dir |
| Scenario (Gherkin) | A use case, end to end through ports | in-memory adapters | `cucumber` |
| Simulation | Concurrency, time, network faults | simulated | `tokio` paused time, `turmoil`, `shuttle`, `loom` |
| End to end | Critical paths only | full stack | few, slow |

Shape: many unit, some integration, a scenario per acceptance criterion, simulation where it pays, very few e2e.

## Unit tests

- No I/O. No tokio runtime where possible.
- Test behavior and invariants, not implementation. A test that breaks on a legal refactor is a liability.
- Types first: if a type can make the state impossible, do that instead of testing it.
- Property tests (`proptest`) for parsers, converters, `TryFrom`, state machines, round-trips (`decode(encode(x)) == x`).
- Bug fix: write the failing regression test first. If it passes before the fix, the bug is not found.
- Layout: unit tests in `#[cfg(test)] mod tests` beside the code.

## Integration tests

- Live in `tests/`. Use the crate's public API only.
- Real backend, not a mock of the driver: `testcontainers` for Postgres, Redis, etc.
- Each test owns its data: unique database or schema name, dynamic ports. Tests must not depend on order.
- Run the same **contract test suite** against every adapter of a port (in-memory and real). One generic function, `fn contract<R: UserRepo>(repo: R)`, called from each adapter's test file. This keeps the in-memory fake honest.

## Scenario tests (Gherkin)

Every `Acceptance` line in a spec becomes a scenario. Rules, layout and full example: `references/gherkin.md`.

## Simulation tests

Use when the code has concurrency, retries, timeouts, leases, consensus, or network calls. Skip for pure CRUD and say so. Techniques and setup: `references/simulation.md`.

## Rules for all levels

1. A failing test prints enough to diagnose: input, expected, actual. Print the seed for anything random.
2. No `sleep`. Use paused time or a fake `Clock`.
3. No global state shared between tests.
4. Flaky test = bug. Fix it or delete it. Never `#[ignore]` without a linked issue.
5. Inject time, randomness and I/O through ports (`Clock`, `Rng`), passed as generics (see `rust-dev` dispatch order).
6. Prefer `cargo nextest run` when installed. Doc tests still need `cargo test --doc`.

## Exit block

```
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo nextest run --workspace     # or: cargo test --workspace
cargo test --doc --workspace
```

Loop (scoped): `cargo test -p <crate> <module>::`.
