# Clean code: smells and refactors

Refactor only under green tests. One refactor per commit. Behavior does not change.

| Smell | Refactor |
|-------|----------|
| Comment explains a block | Extract function named after the comment, delete the comment |
| Comment explains a magic value | Named `const` |
| Comment explains a condition | Named boolean local or method (`is_expired`) |
| Function over ~20 lines, several levels of abstraction | Extract till each reads at one level |
| Nesting deeper than 2 | Guard clauses, early return, `?` |
| Boolean parameter | Two functions, or an enum |
| More than 4 parameters | Parameter struct or builder |
| Primitive obsession (`String` id, `u64` amount) | Newtype |
| Same `match` on a type in many places | Move behavior onto the type |
| `Option` that must not be `None` | Change the type so it cannot |
| Stringly-typed state | Enum |
| Struct with getters and no behavior, logic elsewhere | Move logic onto the struct |
| Long chain `a.b().c().d()` reaching into internals | Method on `a` that hides the path |
| Shotgun surgery (one change touches many files) | Group what changes together |
| Divergent change (one file, many reasons) | Split by reason |
| Feature flag never read | Delete |
| Unused code, parameter, import | Delete |
| Copy-pasted 3 times | Extract. Twice: leave |
| Wrapper that only forwards | Inline it |
| `Manager`, `Helper`, `Util`, `Service` with no domain meaning | Rename after what it does, or split |
| Error is `String` | Enum with `thiserror` |
| Swallowed `Result` | Handle or propagate |

## Naming

- Functions: verb for effects (`open_session`), noun or predicate for queries (`expiry`, `is_expired`).
- Types: domain nouns from the glossary.
- Booleans read as a question: `is_`, `has_`, `can_`.
- Length matches scope: short in a 3-line closure, descriptive at module level.
- No abbreviations that the glossary does not define.
- Rename freely. A rename is cheaper than a comment.

## Function shape

```rust
fn open_session(&self, now: Instant, password: &Password) -> Result<Session, SignInError> {
    if self.is_revoked() {
        return Err(SignInError::Revoked);
    }
    if !self.credentials.matches(password) {
        return Err(SignInError::BadPassword);
    }
    Ok(Session::start(self.id, now))
}
```

Guards first, happy path last, no comments needed.

## Module shape

- Public surface small. `pub(crate)` by default. `pub` is a promise.
- File cohesive: types plus the impls that belong to them.
- No `utils.rs`, no `common.rs`, no `helpers.rs`. Name after content.
- `mod.rs` or `lib.rs` re-exports the public API, holds no logic.

## Refactor protocol

1. Tests green. If no tests cover it, write characterization tests first.
2. One smell, one refactor, one commit: `refactor(scope): extract x`.
3. Tests green after each commit.
4. Do not mix refactor and behavior change in one commit.
5. Large restructure: spec it (`spec-driven`), ADR if a boundary moves.
