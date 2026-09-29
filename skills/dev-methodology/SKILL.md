---
name: dev-methodology
description: Process guardrails for any development work - writing, modifying, reviewing, debugging, refactoring, architecting, testing, deploying. Sizes the task (Iteration, S, M, L), decides when to act or ask, when a message is a question versus an instruction, when work is done, and how to dispatch sub-agents. Consult on every code task, even when the user does not mention methodology. For Rust, also load rust-dev and rust-testing. For M and L work, load spec-driven.
---

# Development methodology

Process rules. Follow by default. Deviate only when the user asks, and say so.

**Speed principle.** A user round-trip is the scarcest resource. Announce and proceed. Block only on the three waits below.

**Invent nothing.** A path, flag, API, version, figure you have not seen is unknown. "Je n'ai pas vérifié" is a complete answer. Verify when cheap. Report failures as failures and skipped steps as skipped.

## Step 0: is this new work?

If the turn follows work in flight (review feedback, fixup, tweak on the current branch, anything under an existing spec), it is an **Iteration**. No sizing, no new spec. Loop: change, targeted tests, commit.

Default to Iteration once a spec exists. A second spec in one session is almost always wrong.

## Step 1: size new work

| Size | Looks like | Process |
|------|------------|---------|
| **S** | ≤ 3 files, no contract change, cause and fix clear | Regression test + fix on a branch. No spec. |
| **M** | One coherent feature or fix, one PR | Spec via `spec-driven` (short form) + TDD. |
| **L** | Several independently reviewable sub-features | Spec (full form) → decompose → sub-agents. Read `references/orchestration.md` first. |

In doubt between two sizes that both qualify: pick the smaller and say so. Grown mid-flight: escalate explicitly.

## Opening announcement (S/M)

First message: size, branch plan, and for M the spec. Statement, not question. Same turn starts work. Never end with "je continue ?".

## The three blocking waits

1. An L decomposition or its branch plan.
2. Any merge into the default branch.
3. Anything irreversible or outward-facing: deletions, force-push, shared-env migrations, spending money, sending mail, posting to a shared channel, publishing a package, opening a public issue.

Two more things end a turn, because they ask for an answer, not permission: the spec-phase question batch (see `spec-driven`), and a requirement you truly cannot read. Nothing else waits.

## A question is a question

"On pourrait utiliser X ?", "ça prendrait quoi ?", "pourquoi c'est lent ?" get an answer, not a diff. Match the French interrogative as written. End the answer with the offer to start, in one clause. A defect that is the subject of the question is answered, not repaired.

## Fix it, do not report it

Small local breakage met on the way (stale path, lint error in a file you edit, broken doc command): fix in its own commit, say so. Exceptions: it exceeds the announced scope (name it, open an issue if worthwhile), or blast radius is not small (dependency bump, CI, migration, shared env: name and leave). Something exploitable now leads the message.

A red test: find why it fails first. Never make it green just to clear the board.

## Done means done

All items asked are delivered and verified. If one is blocked, finish the others and name the specific blocker (command, error, missing decision). "Needs more investigation" is not a blocker.

## Workflow

- **TDD, proportional.** New behavior: red, green, refactor. Iteration on tested code: targeted tests in the loop, full suite once at the end. See `rust-testing`.
- **Scope the loop, not the exit.** In-loop: `cargo test -p <crate> <module>::`. Exit block runs once, named `Verify (exit)` in the spec.
- **Independent checks run together.** Exception: cargo locks the target dir, so `clippy` and `test` in one checkout serialize anyway.
- **Cheap models for bounded work.** Main session keeps decisions and integration. Implementation goes to `sonnet`, search and mechanical edits to `haiku`. Routing, issue loop and limits: `agent-orchestration`. Structure and comments: `architecture`.
- **Sub-agents, never git worktrees.** Parallel writes are made safe by file partitioning, not workspace duplication. Never two writers on one file. L work follows `references/orchestration.md`.
- **Read before you write.** Read the files you touch, the full ticket, the full error. Search prior art first.
- **Short loops.** Write, compile, test. No large batches of unverified code.
- **Deletion beats addition.** Do not abstract before the third occurrence. A shallow wrapper is worse than none.
- **Infrastructure work** (Kubernetes, ArgoCD, Kargo, CI/CD): load `devops-safety` first, then `gitops`, `kubernetes` or `cicd`.
- **Route shell through `rtk`** when available.

## Architecture drift

Propose (never run unasked) an architecture review when: an L feature just integrated, a change touched far more modules than its spec predicted, one file keeps appearing in unrelated changes, or a fix required reading code nobody expected to read.

## Red flags

| Thought | Reality |
|---------|---------|
| "This follow-up needs a spec" | Iteration. The spec holds. |
| "I'll post the plan and wait" | S/M announce and start. |
| "They asked about X, so build X" | A question is a question. |
| "I'll flag it and let them decide" | Small local breakage: fix it. |
| "It's one line, slip it in" | Blast radius, not line count. |
| "Four of five is basically done" | Finish or name the blocker. |
| "It's probably called that" | Probably is not seen. Check. |
| "One more paragraph to be thorough" | Delete it if no fact is lost. |
