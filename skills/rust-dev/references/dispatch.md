# Dispatch: static > enum > dyn

## 1. Static dispatch (default)

```rust
pub trait UserRepo {
    fn find(&self, id: UserId) -> impl Future<Output = Result<Option<User>, RepoError>> + Send;
}

pub struct SignIn<R: UserRepo> {
    repo: R,
}

impl<R: UserRepo> SignIn<R> {
    pub fn new(repo: R) -> Self {
        Self { repo }
    }

    pub async fn run(&self, id: UserId) -> Result<User, SignInError> {
        self.repo.find(id).await?.ok_or(SignInError::UnknownUser)
    }
}
```

Implementers may write `async fn find(...)`. It satisfies the `impl Future + Send` signature if the body is `Send`.

Cost: monomorphization (compile time, binary size). Mitigate hot generic functions with a non-generic inner function:

```rust
pub fn load<P: AsRef<Path>>(path: P) -> io::Result<Vec<u8>> {
    fn inner(path: &Path) -> io::Result<Vec<u8>> {
        std::fs::read(path)
    }
    inner(path.as_ref())
}
```

Too many generic parameters spreading through every struct is a smell. Group them in one trait (an "environment" trait with associated types) or move to enum dispatch.

## 2. Enum dispatch

Use when the set is closed and known at compile time, or picked at runtime from config (`postgres` or `memory`).

```rust
pub enum Store {
    Postgres(PgStore),
    Memory(MemStore),
}

impl UserRepo for Store {
    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
        match self {
            Self::Postgres(s) => s.find(id).await,
            Self::Memory(s) => s.find(id).await,
        }
    }
}
```

Benefits: exhaustive `match` (adding a variant breaks the build until handled), no vtable, no boxing, no `dyn`-compatibility limit, works with native async traits.

Cost: boilerplate per trait method. A declarative macro is acceptable if there are more than ~5 methods. Do not reach for a proc-macro crate before checking it is maintained.

The enum lives at the composition root or in the adapter layer, never in the domain.

## 3. `dyn Trait`

Legitimate:

- Open set: plugins, user-provided handlers, sets that grow without recompiling the core.
- Heterogeneous collection at runtime: `Vec<Box<dyn Middleware>>`.
- Composition root, one call site, cold path.
- Measured problem: compile time or binary size dominated by monomorphization, shown by `cargo build --timings` or `cargo bloat`.

Not legitimate: "it is easier", "I did not want generics in the signature", "mockability" (a test double is just another type parameter or enum variant).

Requirements for a `dyn` port: trait is dyn-compatible (no generic methods, no `-> impl Trait`, no native `async fn`). If it needs async, that is the signal to use rule 1 or 2.

## 4. Type-level resolution (house pattern)

When a repository set must follow one process-wide backend, resolve types with marker types and an associated type instead of values:

```rust
pub trait RepoFor<D> {
    type Repo<'tx>;
    fn build<'tx>(tx: &SharedTx<'tx>) -> Self::Repo<'tx>;
}
pub type Backend = backend::Postgres;
```

A `#[repository]` macro implements `RepoFor` for each adapter, and `#[transactional]` picks `<Backend as RepoFor<domain::Customer>>::Repo`. It is fully static and needs no enum and no `dyn`. Changing backend is one alias. Full example: `architecture/references/ferris-patterns.md`.

## Decision table

| Situation | Choice |
|-----------|--------|
| One impl in prod, one fake in tests | Generics |
| 2 to 5 impls, all in this workspace | Enum |
| Impl chosen by config at startup, closed set | Enum |
| Third parties add impls | `dyn` |
| Runtime list of mixed handlers | `dyn` |
| Generic parameters leak through 4+ layers | Enum at that boundary |
