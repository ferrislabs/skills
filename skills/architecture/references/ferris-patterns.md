# Ferrislabs reference patterns

Two real codebases set the house style. Read them before adding a module. Paths: `/opt/ferrislabs/mestier` and `/opt/aether`. Verify a path still exists before citing it.

Note: those repos contain comments. The near-zero-comments rule applies to code you write. Do not strip existing comments.

## Two layouts

### A. Crate per layer (aether)

```
libs/
  aether-domain/       entities, commands, ports, domain services. Per context: mod.rs commands.rs ports.rs service.rs
  aether-persistence/  shared DB plumbing (SharedTx, executors). No business types.
  aether-postgres/     driven adapters, one dir per context, implements domain ports
  aether-core/         application layer: use cases wired to the adapters. Re-exports domain
  aether-api/          driving adapter (HTTP DTOs, routes)
  aether-macros/       #[repository], #[transactional]
  aether-auth/ aether-permission/ ...   cross-cutting crates
apps/
  control-plane/ operator/ ...          thin binaries
```

The compiler enforces direction: `aether-domain` cannot import `sqlx` because its `Cargo.toml` does not list it.

### B. One core crate, layers as directories (mestier)

```
libs/
  core/                domain/ → application/ → infrastructure/, one dir per bounded context in each layer
  events/              DomainEvent trait, envelope, catalogue. Depends on nothing in core
  macros/              #[transactional], #[repository]
  handlers/            AppState + shared error type
  handlers-<area>/     HTTP handlers, one crate per area (not per context), split by aggregate
  common/ auth/ authz/ pagination/ rate-limit/ ...
apps/
  api/                 assembles router + OpenAPI. No business logic
```

Boundary enforced by convention and review, not by the compiler. Choose B when contexts share many types. Choose A when you want the compiler to guard the domain.

### Picking

| Situation | Layout |
|-----------|--------|
| New service, clear domain boundary worth guarding | A |
| Many bounded contexts sharing ids and errors | B |
| Small tool | One crate, modules, same direction rules |

## Context layout

```
domain/<context>/
  mod.rs        entity, value objects, id newtypes
  commands.rs   input structs to the service
  ports.rs      driven traits
  service.rs    domain service, generic over ports
application/<context>/
  mod.rs        use cases on the shared use-case struct
  tests.rs
infrastructure/<context>/postgres/
  model.rs      Row types, TryFrom to domain
  repository.rs #[repository] adapter
```

## Port style

- Trait defined in the domain.
- Native async: `-> impl Future<Output = Result<T, CoreError>> + Send`. No `async-trait`.
- Methods take `&mut self` when the adapter holds a shared transaction.
- Bound `Send` on the trait.
- `#[cfg_attr(any(test, feature = "mock"), mockall::automock)]` for unit-testing services with generated doubles.

```rust
#[cfg_attr(any(test, feature = "mock"), mockall::automock)]
pub trait CustomerContactRepository: Send {
    fn find_by_id(
        &mut self,
        id: CustomerContactId,
    ) -> impl Future<Output = Result<Option<CustomerContact>, CoreError>> + Send;
}
```

## Domain service: generic over ports

```rust
pub struct CustomerContactService<R, C, A>
where
    R: CustomerContactRepository,
    C: CustomerRepository,
    A: Authorizer,
{
    repo: R,
    customer_repository: C,
    authz: A,
}
```

Static dispatch. The service never learns a transaction exists. Unit tests build it with mocks or in-memory repos.

## Repository injection: marker types, not dyn

Three parts:

1. **Domain markers** and **backend marker**, zero-sized, in `registry.rs`.
2. `RepoFor<D>` resolves a domain to a concrete repo per backend, and one alias selects the active backend.
3. `#[repository(domain = X, backend = Postgres)]` on the adapter generates the `RepoFor` impl.

```rust
pub mod domain { pub struct Customer; pub struct Role; }
pub mod backend { pub struct Postgres; }
pub type Backend = backend::Postgres;

pub trait RepoFor<D> {
    type Repo<'tx>;
    fn build<'tx>(tx: &SharedTx<'tx>) -> Self::Repo<'tx>;
}
```

```rust
#[repository(domain = Customer, backend = Postgres)]
pub struct PgCustomerRepository<'tx> { tx: SharedTx<'tx> }

impl<'tx> PgCustomerRepository<'tx> {
    pub fn new(tx: &SharedTx<'tx>) -> Self { Self { tx: tx.clone() } }
}
```

Result: zero vtables, exhaustive at compile time, and switching backend means changing one alias plus providing `RepoFor` impls. This is the house form of "static dispatch first".

## Use case: `#[transactional]`

A use case is a method on one long-lived use-case struct. The macro opens the transaction, builds the listed repositories, binds them as `{name}_repository`, commits or rolls back.

```rust
impl MestierUseCase {
    #[transactional(customer_contact, customer, authz)]
    pub async fn create_customer_contact(
        &self,
        command: CreateCustomerContactCommand,
    ) -> Result<CustomerContact, CoreError> {
        let mut service = CustomerContactService::new(
            customer_contact_repository,
            customer_repository,
            authz,
        );
        service.create_customer_contact(command).await
    }
}
```

Rules:

1. Use case body: build the service, call it, return. Business rules live in the service.
2. List only the repositories the use case needs.
3. Never hold request-scoped state on the use-case struct. It is long-lived and cloned per request. A shared buffer there once leaked events across tenants.
4. Events are persisted inside the transaction before commit. An event exists if and only if its transaction committed.
5. Multi-tenant: every query scoped by tenant id. Migrations reversible, `.down.sql` tested.

## Adding a context (checklist)

1. Domain: `mod.rs`, `commands.rs`, `ports.rs`, `service.rs`. Marker in `registry.rs`.
2. Adapter: `Row` + `TryFrom`, `#[repository(...)]` struct, port impl.
3. Use cases: `#[transactional(...)]` methods.
4. Handlers: new aggregate module in the area crate (`pub mod` + `.merge(...)`), route + OpenAPI tag in the app.
5. Migration up and down.
6. Tests: service unit tests, adapter integration test against real Postgres, scenario per acceptance line.
7. Entry document updated if a registration point moved.

## Where things register

Adding a module edits a registry, never a `match`: workspace `Cargo.toml` (members and dependencies), `registry.rs` marker, router and OpenAPI files. Keep this list in the repo's `CLAUDE.md`.

## Thin binaries

`apps/*` parse config, build the pool and use case, mount routes, start the server. No business logic, no SQL.

## Handlers

Parse and validate DTO into a command, call the use case, map the result or error to HTTP. One place maps domain errors to status codes.

## Events crate

`DomainEvent` trait and catalogue live in their own crate that depends on nothing from core, so any layer can name an event without a cycle.
