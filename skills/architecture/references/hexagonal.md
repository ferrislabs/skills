# Hexagonal architecture (ports and adapters)

## Layers and what they may import

| Layer | Contains | May import |
|-------|----------|------------|
| Domain | Entities, value objects, domain services, domain errors | `std`, tiny pure crates (`thiserror`, `uuid`) |
| Application | Use cases, driven port traits | Domain |
| Adapters | HTTP, CLI, DB, queue, clients, DTOs | Application, Domain, frameworks |
| Composition root | `main`, config, wiring | Everything |

Enforce with crates when the boundary matters. A domain crate that does not list `sqlx` in `Cargo.toml` cannot import it.

## Driven port (owned by the application)

```rust
pub trait UserRepo {
    fn find(&self, id: UserId) -> impl Future<Output = Result<Option<User>, RepoError>> + Send;
    fn save(&self, user: &User) -> impl Future<Output = Result<(), RepoError>> + Send;
}
```

`RepoError` is a domain-level enum (`NotFound`, `Conflict`, `Unavailable`), never `sqlx::Error`. The adapter maps its own errors into it.

## Use case

```rust
pub struct SignIn<R: UserRepo, C: Clock> {
    repo: R,
    clock: C,
}

impl<R: UserRepo, C: Clock> SignIn<R, C> {
    pub async fn run(&self, cmd: SignInCommand) -> Result<Session, SignInError> {
        let user = self.repo.find(cmd.user_id).await?.ok_or(SignInError::UnknownUser)?;
        user.open_session(self.clock.now(), &cmd.password)
    }
}
```

Generics for wiring. Enum at the composition root when the adapter is chosen from config. See `rust-dev/references/dispatch.md`.

## Driving adapter (HTTP)

```rust
async fn sign_in_handler(State(uc): State<Arc<SignInUseCase>>, Json(body): Json<SignInBody>) -> Result<Json<SessionDto>, ApiError> {
    let cmd = SignInCommand::try_from(body)?;
    let session = uc.run(cmd).await?;
    Ok(Json(SessionDto::from(session)))
}
```

Handler: parse, call, map. No business rule inside. `ApiError` maps domain errors to status codes in one place.

## Driven adapter (Postgres)

- Implements the port. Holds the pool.
- Row types (`UserRow`) live in the adapter. `TryFrom<UserRow> for User` converts.
- `sqlx` macros checked at compile time. Migrations versioned and reversible.
- Contract test suite shared with the in-memory adapter (`rust-testing`).

## In-memory adapter

Every port gets one. It is the test double and the dev fallback. It passes the same contract tests as the real adapter.

## Conversions

| From | To | Where |
|------|----|-------|
| Request DTO | Command (domain types) | driving adapter, `TryFrom` |
| Domain type | Response DTO | driving adapter, `From` |
| Row | Domain type | driven adapter, `TryFrom` |
| Domain type | Row | driven adapter, `From` |

Validation happens in the `TryFrom`. Once you hold a domain type, it is valid.

## Composition root

```rust
fn main() -> anyhow::Result<()> {
    let cfg = Config::load()?;
    let repo = match cfg.store {
        StoreCfg::Postgres(url) => Store::Postgres(PgStore::connect(&url)?),
        StoreCfg::Memory => Store::Memory(MemStore::default()),
    };
    let sign_in = SignIn::new(repo, SystemClock);
    serve(sign_in)
}
```

Only place with concrete names. `anyhow` allowed here.

## Common violations

| Violation | Fix |
|-----------|-----|
| Domain struct derives `sqlx::FromRow` | Row type in adapter + `TryFrom` |
| Domain struct derives `Serialize` for the API shape | Response DTO in adapter |
| Use case takes `axum::extract::*` | Command struct |
| Port trait declared in the adapter crate | Move to application |
| Port returns `sqlx::Error` or `anyhow::Error` | Port-level error enum |
| Handler contains `if user.age < 18` | Move to domain method |
| Use case calls `SystemTime::now()` | `Clock` port |
| Adapter calls another adapter | Go through a use case |
| Shared `models` crate used by all layers | Split: domain types, DTOs, rows |

## When to skip the ceremony

Script, one-off tool, thin CLI wrapper: no ports. Rule of three applies to ports too. Add a port when there is a second implementation (real or test double) or a real boundary to protect.
