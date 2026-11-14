# Sub-Agent Orchestration, L annex

Read this once per session, only for L work, after `orchestration.md`. It holds what a single-PR (M) feature never needs: generated-artifact handling, the parallelism ceiling, the completeness pass, and the workstream state artifact.

### Generated artifacts are not convergence points

A file that a command can reproduce from other files is not something to partition, hand-edit, or merge. It is something to **regenerate**.

The test is one question: *can this file be rebuilt by running something?* Generated API clients, schema caches, lockfiles, derived type definitions, compiled assets — if yes, no sub-agent touches it, and neither does the orchestrator by hand. Regenerate it from the integrated state, once, after each integration.

The two species sit side by side and are easy to confuse. `Cargo.toml` is hand-written, so a sub-agent reports the line it needs; `Cargo.lock` is derived, so nobody reports anything and the orchestrator rebuilds it. Applying the reporting rule to a generated file produces nonsense the moment the file is large: asking three sub-agents to report "the exact line" they need in a thousand-line generated client is a request none of them can honestly answer.

Two failure modes make this worth a rule rather than a habit:

- **Concurrent regeneration silently produces a wrong file.** Each agent regenerates from its own partial state, so each output is correct for one workstream and missing the others. The last write wins, the result compiles, and nothing announces that two workstreams' worth of definitions just vanished.
- **Generated diffs bury the reviewed change.** A regenerated client can move a thousand lines beside twenty lines of actual work. A pull request that cannot be read is not reviewed, whatever its approval says.

Declare these in the workstream state artifact as a third category, next to the owned files and the orchestrator-owned list: **regenerated at integration**, with the exact command that rebuilds each one.
## Raising the parallelism ceiling

Parallelism is capped by three separate things: how the work decomposes, how it is scheduled, and what the toolchain permits. A decomposition that only attacks the first leaves the other two on the table.

### Schedule as a pipeline, not a barrier

Do not wait for every workstream to finish stage N before starting stage N+1. Each flows through its own chain independently, so wall-clock becomes the slowest single chain rather than the sum of per-stage maxima. If the slowest workstream takes three times the fastest, a barrier discards two thirds of the fast ones' time.

A barrier is correct only when the next stage genuinely needs the whole previous set at once — deduplicating across all findings, or exiting early because the total came back empty. "I need to flatten the results first" is not a barrier: do the transform inside the chain.

### Remove toolchain contention before blaming the decomposition

A perfect file partition buys nothing if the tooling serializes anyway. Check this before concluding that work is not parallelizable:

- `cargo` holds a lock on the target directory — concurrent builds in one checkout block at the toolchain level, however well the sources are partitioned. Give each agent its own `CARGO_TARGET_DIR`, or keep builds off the concurrent path.
- A shared test database serializes integration tests. Give each agent its own database name or schema.
- Fixed ports collide. Allocate them dynamically.

This creates no new parallelism; it stops discarding the parallelism the decomposition already earned. One-time infrastructure work that pays on every subsequent L feature.

### Parallelize the exit, not just the entrance

Implementation is often legitimately serial. Verification never is — once a workstream is integrated, its checks are mutually independent and read-only, so they carry no conflict risk at all. Judgment checks run as one sub-agent per lens: correctness, security, performance, conformance to the mini-spec. One lens per agent beats one agent asked to check everything — a brief carrying a single question produces a sharper answer than a checklist.

Mechanical checks (typecheck, lint, tests) are batched commands rather than sub-agents; see "Testing and verification" in the core methodology, and mind the toolchain contention above.

## The completeness pass

Before declaring an L feature integrated, run one final check — yourself or a dedicated sub-agent — asking only: *what is missing?* Verifications never run, workstreams marked done but never re-tested after a sibling merged, acceptance criteria from the mini-spec nobody checked. What it finds becomes the next round of work, not a footnote.

## Workstream state (survives sessions and context compaction)

For any L feature, maintain one tracking artifact — the parent chantier issue body (preferred when issues were opted in at kickoff) or `docs/chantiers/<name>.md`:

- The decomposition: workstream list with one-line missions, and what each depends on.
- Status per workstream: pending / in-flight / integrated.
- Frozen contracts, verbatim.
- The file partition, in three categories: files owned per workstream, orchestrator-owned convergence points, and artifacts regenerated at integration with the command that rebuilds each.
- Per-workstream environment where the toolchain would otherwise serialize: database name, build directory, port range.
- Decision log: non-obvious choices with the rejected alternative.

Update it at every integration, not at the end. This artifact is what makes the orchestration resumable by a future session with zero shared memory — write it for that reader.
