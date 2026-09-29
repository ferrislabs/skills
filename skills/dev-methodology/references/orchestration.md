# Sub-Agent Orchestration

Load this file once per session: before decomposing an L feature, and in any case before its first sub-agent dispatch. Re-read it if it was edited since, or if context was compacted and you cannot tell whether it is still in play. Not for S/M work, and not for a single delegated lookup — those are scheduling, not orchestration, and the rules they need are inline in `SKILL.md`. Use `superpowers:subagent-driven-development` when available as the execution protocol (task sequencing, checkpoints); the rules below govern what every dispatch must contain and how results are accepted — they apply on top of it, or standalone when superpowers is absent.

The single most common orchestration failure is the orchestrator assuming a sub-agent "knows" something it never wrote down. A sub-agent wakes up with zero conversation context: it has not seen the user's messages, the decisions made, or the dead ends already explored. Everything it needs must be in the briefing.

## When to delegate at all

- **Delegate:** sweeps across many files, independent workstreams, exploratory spikes, large mechanical refactors, review passes. Delegation also protects the orchestrator's own context — it keeps conclusions, not file dumps, which matters on long chantiers.
- **Don't delegate:** single-fact lookups where you already know the file or symbol — read it directly; dispatch overhead exceeds the work.
- Once work is delegated, never redo it yourself in parallel. Take up something that does not depend on it and collect the result when it lands — not redoing it is the rule, going idle is not.

## Decomposition rules (before any dispatch)

- Each workstream must be independently implementable, reviewable, and testable.
- **Freeze shared contracts first.** Types, ports, and API shapes that cross workstream boundaries are decided by the orchestrator *before* parallelizing, and are read-only for every sub-agent. This is what prevents two workstreams from silently diverging on an interface.
- **Partition files.** Every workstream owns a disjoint set of files. Reads may overlap freely; writes never. Overlap on writes is not automatically fatal — classify it first. Substantive overlap, where two workstreams would edit the same logic, means the decomposition is wrong: merge them. Incidental overlap on shared plumbing does not (see "Convergence points").
- **No git worktrees** — manual or tool-managed. Isolation does not resolve a source conflict, it defers it into a merge conflict — strictly more work than applying known additive edits in one pass. What it would buy is workspace isolation: build directories, lockfiles, test databases, ports. Remove that contention directly (distinct target dirs, distinct database names, dynamic ports) rather than duplicating the workspace. Available isolation is also what tempts a decomposition into skipping contract freezing — a temptation, never a licence, since freezing is required either way: divergence across isolated checkouts is silent until merge, whereas a file collision is loud and immediate. If partitioning is impossible, the work was not parallelizable — serialize.

## Convergence points

A file partition is written before anyone has read the code deeply enough to enumerate files, so it is always a forecast. It fails in a predictable place: not on the feature code, which partitions cleanly, but on the small set of files every feature must touch. Anticipate them by name — in most codebases the list is short:

- module and route registration (`mod.rs`, `lib.rs`, router or handler wiring)
- dependency manifests (`Cargo.toml`, `package.json`)
- migration directories, where the filename carries a sequence number
- shared error enums, shared type modules, the composition root
- config schemas and environment templates

**These are orchestrator-owned. No sub-agent writes them.** A sub-agent needing a line added there reports the exact line; the orchestrator applies all of them at integration, in one pass, in a known order. This is what keeps two genuinely independent workstreams parallel when their only conflict is one registration line each — merging them to avoid a two-line edit trades real concurrency for nothing.

### Generated artifacts are not convergence points

A file that a command can reproduce from other files is not something to partition, hand-edit, or merge. It is something to **regenerate**.

The test is one question: *can this file be rebuilt by running something?* Generated API clients, schema caches, lockfiles, derived type definitions, compiled assets — if yes, no sub-agent touches it, and neither does the orchestrator by hand. Regenerate it from the integrated state, once, after each integration.

The two species sit side by side and are easy to confuse. `Cargo.toml` is hand-written, so a sub-agent reports the line it needs; `Cargo.lock` is derived, so nobody reports anything and the orchestrator rebuilds it. Applying the reporting rule to a generated file produces nonsense the moment the file is large: asking three sub-agents to report "the exact line" they need in a thousand-line generated client is a request none of them can honestly answer.

Two failure modes make this worth a rule rather than a habit:

- **Concurrent regeneration silently produces a wrong file.** Each agent regenerates from its own partial state, so each output is correct for one workstream and missing the others. The last write wins, the result compiles, and nothing announces that two workstreams' worth of definitions just vanished.
- **Generated diffs bury the reviewed change.** A regenerated client can move a thousand lines beside twenty lines of actual work. A pull request that cannot be read is not reviewed, whatever its approval says.

Declare these in the workstream state artifact as a third category, next to the owned files and the orchestrator-owned list: **regenerated at integration**, with the exact command that rebuilds each one.

Record the partition — owned files per workstream, plus the orchestrator-owned list — in the workstream state artifact, beside the frozen contracts. It is the single source of truth for who writes what.

**Out-of-scope discovery.** A sub-agent that finds it needs to write a file it does not own stops and reports. It does not write it, and it does not widen its own scope. The orchestrator then decides: hand the file over, add it to the orchestrator-owned set, or merge the workstreams. Silent scope widening is how a partition becomes fiction.

**Cheap detection.** Every report lists the files it changed — already required by the report format. Diff those lists against the declared partition when each report lands, not at integration. An overlap caught on arrival costs a re-dispatch; the same overlap caught at integration costs a conflict resolution on merged work.

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

## The dispatch batch

Decomposition produces a list. That list is dispatched in **one message**, not one per turn.

Before dispatching, sort the workstreams into exactly two groups:

- **Independent** — nothing it needs is produced by a sibling. Every independent workstream goes in the same message, always. Three independent workstreams dispatched sequentially cost the sum of their durations instead of the longest.
- **Dependent** — needs a sibling's output. It waits for that sibling only, never for the whole batch. Dispatch it in the next message, batched with everything else that just became unblocked.

Freezing contracts first is what makes most workstreams independent. If the list comes out mostly dependent, the contracts were not frozen hard enough — go back and freeze them rather than accepting a serial plan.

**Checkable rule:** if a message contains exactly one dispatch, you must be able to name the sibling whose output it needs, or state that it is the only workstream. If you can name neither, the batch was split for no reason.

## The briefing (mandatory, every dispatch)

Every dispatch contains all six sections. A sub-agent that has to guess will guess wrong:

1. **Mission** — one sentence.
2. **Context** — decisions already made and *why*, state of sibling workstreams, anything from the conversation the sub-agent needs. It cannot see the conversation.
3. **Frozen contracts** — the types/ports/API shapes it must not modify, verbatim or by exact file path.
4. **Scope** — the files it owns, the files it must not touch, and the orchestrator-owned convergence points it reports against instead of editing. An agent that writes nothing — a review lens, an audit pass — owns no files: write **writes no files, reports only** in this slot rather than leaving it empty. An empty scope reads as unspecified, not as forbidden, and a sub-agent reads its briefing rather than the methodology — so this slot is the only place the rule can reach it.
5. **Verification** — the exact commands to run before reporting done (seeded from the mini-spec's `Verify` line). When the environment provides `rtk`, write them in their `rtk`-prefixed form — sub-agent verification output is a major token sink and rtk filters it at the source.
6. **Report format** — require structured data, not prose: files changed, tests run with their actual output, deviations from the spec, open questions. A bare "done" is not a report.

**The briefing is a cache.** A sub-agent wakes with no context, so it rebuilds its model of the codebase from scratch — and so does the next one, and the one after that. Measured on a real chantier: across 72 sub-agents, **58% of all file reads were re-reads of a file another agent had already opened**, with one architectural file read independently by 24 of them. Each of those agents paid the read, then paid again to work out what mattered in it — and that second cost lands in generation time, which dominates everything else.

The redundancy is structural, not sloppiness: an agent with no context has no way to know a sibling already answered the question. The only place it can be removed is upstream. **Anything more than one sub-agent would read belongs in the briefing.** The orchestrator reads once and distributes the result.

This is what section 3 is for, used properly. A frozen contract is not only what a sub-agent must not modify — it is what it must not go looking for. And section 4 should name the module to imitate: "same layering as `<path>`" replaces a dozen exploratory reads, because an agent handed a canonical example does not have to infer the convention from three instances of it.

The arithmetic only works if the excerpt is shorter than the file. Where it is not, name the file and say what to take from it — the expensive part was never the read, it was deciding what in it mattered.

Point sub-agents at the skill excerpts they need (e.g. `references/rust.md` for Rust work) instead of paraphrasing them — paraphrase drifts from the source.

Match the model to the stage: implementation of a well-specified workstream runs on the implementation model recorded at kickoff; review, verification, and judgment stages get the strongest reasoning available.

## Accepting results (trust but verify)

A sub-agent's claim is not evidence.

- Read the sub-agent's diff yourself before integrating.
- Re-run the verification commands yourself; do not integrate on the strength of the report alone.
- Integrate workstreams **sequentially**. After each integration, run that workstream's targeted tests — the exact commands from its briefing's Verification section, nothing wider. Run the full suite **once**, after the last integration.
- Running the full suite at every integration point is not the cautious choice, it is the less informative one: mid-integration, the cross-workstream interactions it exists to catch do not exist yet, so it can only rediscover what the targeted tests already reported — at O(N) cost.
- **The full suite belongs to whoever holds a coherent tree**, and which one that is depends on how the workstreams run. When they run one after another, each merged before the next starts, the sub-agent holds one: it runs the exit block at the end of its own task and catches its own regression before opening a pull request. When they run concurrently in a shared checkout, it does not — a full run there tests a tree carrying siblings' unfinished work, so it fails for reasons the agent cannot act on, or passes on a state that will never exist. Then only the orchestrator's post-integration run counts, and sub-agents stay scoped to their own crates throughout. Say which regime applies in the briefing; an agent cannot tell from inside.
- If the final run fails, *then* bisect by replaying the suite at each integration point. Pay the O(N) cost once there is a real failure to localize.
- If a report shows deviations from the spec, decide explicitly: accept and record why in the decision log, or re-dispatch with a corrected briefing. Prefer **continuing the same sub-agent** with the correction — it already holds the context — over briefing a fresh one from scratch.
- For critical or surprising findings, verify adversarially: dispatch an independent sub-agent whose brief is to *refute* the finding, not confirm it. A finding that survives a motivated skeptic is worth trusting.

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
