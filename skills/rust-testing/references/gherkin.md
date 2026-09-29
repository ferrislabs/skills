# Gherkin scenarios with cucumber-rs

Crate: `cucumber`. Verify the current version on crates.io before pinning.

## Setup

`Cargo.toml`:

```toml
[dev-dependencies]
cucumber = "<current>"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }

[[test]]
name = "bdd"
harness = false
```

`harness = false` is required: cucumber provides its own runner.

Layout:

```
tests/
  bdd.rs
  features/
    sign_in.feature
```

## Feature file

Declarative, business language, one behavior per scenario.

```gherkin
Feature: Sign in

  Scenario: A registered user signs in
    Given a registered user "alice"
    When "alice" signs in with the right password
    Then a session is opened for "alice"

  Scenario: A revoked user cannot sign in
    Given a registered user "bob"
    And "bob" is revoked
    When "bob" signs in with the right password
    Then sign in is refused with reason "revoked"
```

Rules:

1. Declarative, not imperative. Write "signs in", not "types 'alice' in the field and clicks Submit".
2. One `When` per scenario. Several `Then` are fine if they describe one outcome.
3. Use the project glossary words. Same term in the spec, the feature and the code.
4. Use `Scenario Outline` + `Examples` for the same behavior over many inputs.
5. `Background` only for setup every scenario needs. Keep it short.
6. Tags: `@wip` (skipped in CI), `@slow`, `@integration` (uses real backend). Filter with `.filter_run`.
7. Each scenario links to a spec `Acceptance` line. Put the spec id in a tag: `@spec-auth-3`.

## Step definitions

Steps stay thin. They call the use case through the public API. No logic in steps.

```rust
use cucumber::{given, then, when, World};

#[derive(Debug, Default, World)]
struct AuthWorld {
    app: TestApp,                 // use cases wired to in-memory adapters
    last: Option<Result<Session, SignInError>>,
}

#[given(expr = "a registered user {string}")]
async fn registered(w: &mut AuthWorld, name: String) {
    w.app.register(&name).await;
}

#[when(expr = "{string} signs in with the right password")]
async fn signs_in(w: &mut AuthWorld, name: String) {
    w.last = Some(w.app.sign_in(&name, TestApp::PASSWORD).await);
}

#[then(expr = "a session is opened for {string}")]
async fn session_opened(w: &mut AuthWorld, name: String) {
    let session = w.last.take().expect("no result").expect("sign in failed");
    assert_eq!(session.user_name(), name);
}

#[tokio::main]
async fn main() {
    AuthWorld::run("tests/features").await;
}
```

Notes:

- `World` is created fresh per scenario, so scenarios do not share state.
- `TestApp` is the composition of use cases with in-memory adapters and a fake `Clock`. Static dispatch: `TestApp` is a concrete type, no `dyn`.
- Run scenarios against real adapters by tagging them `@integration` and building a second `World` wired to `testcontainers`.
- `expect` in test code is fine.

## When not to use Gherkin

- Pure functions and parsers: unit or property tests are shorter and clearer.
- Low-level adapter details: integration tests.
- Anything a non-technical reader will never read. Gherkin pays when the feature file is the shared document between spec and code.

## Run

```
cargo test --test bdd
cargo test --test bdd -- --tags '@spec-auth-3'
```

Check the flag syntax against the installed cucumber version (`--help`) before relying on it.
