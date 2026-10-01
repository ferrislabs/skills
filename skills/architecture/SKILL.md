---
name: architecture
description: Architecture and clean-code rules for Ferrislabs, any language, Rust first - hexagonal (ports and adapters), dependency direction, module depth, naming, function size, error design, and the near-zero-comments rule. Consult before designing a module or crate boundary, adding a port or adapter, refactoring, reviewing structure, or writing any code where the question "should this comment exist" or "where does this live" arises.
---

# Architecture and clean code

Pairs with `spec-driven` (decisions, ADRs) and `rust-dev` (Rust specifics). Details in `references/`.

## Comments: near zero

Default state of a file: no comments. The code says what. The commit, PR or ADR says why.

1. Do not write comments. Not `//`, not `///`, not `//!`, not block comments.
2. Do not put prose in `expect("...")`, `assert!` messages, log lines or long identifiers. Same narration, higher cost.
3. Do not add comments to code you did not write. Do not delete existing ones unless asked or the code they describe is gone.
4. No commented-out code. Delete it. Git remembers.
5. Explain by naming: a named `const`, a named local, a small function, a type.
6. Allowed, one line each, only when a check demands it:
   - `// SAFETY: <reason>` when `clippy::undocumented_unsafe_blocks` is on.
   - `///` one line on public items when `missing_docs` is on.
   - `// TODO(#123): <what>` with an issue number.
7. Ask once per session, at the first task that writes code: `Commentaires dans le code ou pas ?` One closed line, before writing. The answer holds for the whole session, every file, every sub-agent. No answer, or no occasion to ask: zero comments. Difficulty of the code is not a request.
8. The why goes to: commit message, PR description, ADR.

## Dependency direction

```
adapters (infra)  →  application (use cases)  →  domain
```

Arrows point inward. Domain imports nothing from the other two. Application imports domain only. Adapters import both. The composition root (binary crate) is the only place that names concrete adapters.

Check: `cargo tree -p <domain-crate>` shows no `sqlx`, `axum`, `reqwest`, `tokio` (unless the domain needs async traits only, then just `std`).

## Hexagonal in one page

- **Domain:** entities, value objects, domain services, domain errors. Pure.
- **Application:** use cases. Orchestrate domain through ports. Own the port traits (driven side).
- **Ports:** driving (called by the outside: use case interface) and driven (called by the application: repository, clock, mailer).
- **Adapters:** driving (HTTP, CLI, queue consumer) and driven (Postgres, S3, SMTP). One per external concern.
- **DTOs** stay in adapters. `TryFrom` converts to domain types at the edge.

## House patterns (read before adding a module)

Modeled on `/opt/aether` and `/opt/ferrislabs/mestier`. Full guide with code: `references/ferris-patterns.md`.

- **Split into crates.** Aether: `*-domain`, `*-persistence`, `*-postgres`, `*-core` (use cases), `*-api`, `*-macros`, thin `apps/*`. Mestier: one `core` crate with `domain/ → application/ → infrastructure/` directories, plus `events`, `macros`, `handlers-<area>`, thin `apps/api`. A crate boundary lets the compiler forbid the wrong import.
- **Repository injection by macro, not by `dyn`.** `#[repository(domain = X, backend = Postgres)]` on the adapter, `RepoFor<D>` trait plus one `Backend` alias resolve the concrete type at compile time.
- **Use case = `#[transactional(repo_a, repo_b, authz)]` method.** The macro opens the transaction and injects the listed repositories. The body builds the domain service and calls it.
- **Domain service generic over ports.** Ports use native `-> impl Future + Send`, `&mut self`, and `mockall::automock` behind `cfg`.
- **Registries, not `match`.** Adding a context edits a marker list and a router, nothing else.
- **Thin binaries.** Config, wiring, server start.

Small project: modules in one crate, same direction rules. Generic guide: `references/hexagonal.md`.

## Clean code, the short list

1. **Names carry meaning.** Intention-revealing. Domain glossary terms verbatim. No `Manager`, `Helper`, `Util`, `Data`, `Info`.
2. **Small functions, one level of abstraction.** Around 20 lines is a prompt to look, not a law. If you need a comment to separate sections, extract functions.
3. **Few parameters.** More than 4: introduce a struct or builder. Boolean flag parameters: split the function or use an enum.
4. **No hidden effects.** A function named `get_*` does not write. Side effects live at the edges.
5. **Early return.** Guard clauses over nesting beyond 2 levels.
6. **Make invalid states unrepresentable.** Types over checks.
7. **Errors are values with meaning.** One enum per boundary. No stringly-typed errors.
8. **Duplication is cheaper than the wrong abstraction.** Abstract on the third occurrence.
9. **Depth over count.** A module hides a lot behind a small interface. Delete shallow wrappers.
10. **Delete dead code.** Unused function, unused parameter, unused feature flag.
11. **Cohesion.** Things that change together live together. A file that changes for unrelated reasons is two files.
12. **Tell, do not ask.** Put behavior on the type that owns the data, not in a service that pulls fields out.

Smells and refactors: `references/clean-code.md`.

## Review checklist

1. Any import pointing outward from domain or application?
2. Any port defined in an adapter?
3. Any DTO or ORM type inside a use case?
4. Any comment added? Remove it, move the why to the commit.
5. Any function or file with two reasons to change?
6. Any abstraction with fewer than three users?
7. Any `Manager`/`Helper`/`Util`?

## When architecture changes

Write an ADR (`spec-driven/references/adr-template.md`). Update the entry document (`CLAUDE.md`) in the same change if a path, layer or command moved.
