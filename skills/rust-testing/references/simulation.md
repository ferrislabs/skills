# Simulation tests

Goal: run the system under controlled time, randomness, scheduling and faults, deterministically, so a failure replays from a seed.

## When it pays

Use when the code has any of: concurrency with shared state, retries and backoff, timeouts, leases, caches with expiry, distributed protocols, network calls, queues. Skip for pure CRUD and pure functions. Say "pas de simulation, raison : X" when skipped.

## Ladder (stop at the lowest rung that catches the bug)

### 1. Inject the environment

Time, randomness and I/O are ports, passed as generics.

```rust
pub trait Clock {
    fn now(&self) -> Instant;
    fn sleep(&self, d: Duration) -> impl Future<Output = ()> + Send;
}

pub trait Rng {
    fn next_u64(&mut self) -> u64;
}
```

Production impl uses the real thing. Test impl is fully controlled: `FakeClock` advanced manually, `SeededRng(u64)`.

### 2. Paused tokio time

Feature `test-util` on tokio (dev-dependency).

```rust
#[tokio::test(start_paused = true)]
async fn retries_with_backoff() {
    // tokio::time::sleep auto-advances when all tasks are idle
}
```

Good for timeouts, backoff, debounce. No real waiting, no flakiness.

### 3. Fault-injecting adapters

A wrapper adapter implementing the same port that fails on demand.

```rust
pub struct Flaky<S> {
    inner: S,
    fail_every: u32,
    calls: AtomicU32,
}
```

Use it in scenarios: "the store fails on the second write".

### 4. Model-based property tests

`proptest` + `proptest-state-machine`: generate sequences of operations, apply to the real system and a simple model, compare after each step. Finds ordering bugs unit tests miss.

### 5. Deterministic concurrency

- `loom`: exhaustively explores thread interleavings of small, synchronization-heavy code (atomics, locks, lock-free structures). Use loom types behind `cfg(loom)`.
- `shuttle`: randomized scheduler, scales to larger async/thread code, replayable from a seed.

### 6. Network and full-system

- `turmoil`: simulates hosts and a network (partitions, latency, drops) for tokio code in one process, deterministic.
- `madsim`: deterministic runtime replacing tokio and time for whole-system simulation. Heavier to adopt: needs cfg switches on dependencies. Only for distributed cores.

Check each crate's docs for the current API and version before writing code. Do not guess signatures.

## Rules

1. Every random test prints its seed. A failure message contains the command to replay it.
2. Same seed, same result. If not, the simulation leaks real time, real threads or real I/O. Find the leak first.
3. Assert invariants, not traces: "no two holders of the lease", "balance never negative", "every accepted write is eventually readable".
4. Keep a regression list: each seed that once failed becomes a fixed test.
5. Run a small fixed seed set in CI (fast). Run many seeds nightly.
6. Simulation complements scenario tests. It does not replace them.

## Checklist before adding simulation

1. Which invariant could break under concurrency, time or faults?
2. Are time, randomness and I/O behind ports already? If not, do that first.
3. Which rung catches it with the least machinery?
