---
name: spec-driven
description: Spec-driven development and architecture for Ferrislabs. The spec is written before the code and is the contract. Covers the mini-spec (M), the full spec (L), the question batch that closes the spec phase, ADRs for architecture decisions, the project glossary, and how each Acceptance line becomes an executable test. Consult before starting any M or L task, any new feature, any architecture decision, or when the user says spec, design, ADR, architecture, or "on devrait".
---

# Spec-driven development

Spec first. Code second. The spec is the answer to any later "what should this do".

Pairs with `dev-methodology` (sizing, waits), `rust-dev` (architecture rules), `rust-testing` (Acceptance → tests).

## Flow

1. **Read.** Existing code, ticket, glossary, prior ADRs.
2. **Ask.** One batch, one message, only for what you would otherwise guess (see below).
3. **Spec.** Mini-spec (M) or full spec (L). Templates: `references/spec-template.md`.
4. **Tests from Acceptance.** Each Acceptance line becomes a test before the code (scenario, unit, or simulation).
5. **Implement.** Red, green, refactor, per Acceptance line.
6. **Verify.** Run the `Verify (exit)` block. Update the spec if reality differed.

S-sized work skips steps 2 to 3. Iterations reuse the existing spec.

## The question batch

Before the spec exists, questions are cheap. A restated request is still incomplete. Ask about what misalignment hides in:

- **Invariants:** what must never happen?
- **Out of scope:** where does the change stop?
- **Acceptance:** what observable check proves it works?

Rules: one message, closed questions, a recommendation for each, keep working on what they do not block. If a field can be filled from the code or the ticket, fill it. Do not ask it.

## Once the spec exists

The spec is the answer. Do not reopen what it settles. A question arising during implementation is a defect in the spec: name the gap, amend the spec in one line, say you amended it. No ad-hoc Q&A.

## Invariants live in types

Order of preference for enforcing an invariant:

1. Type (newtype, enum, `TryFrom`). Compiler enforces.
2. Constructor that returns `Result`.
3. Test. Only where types cannot carry it.

A test standing in for a type that could carry the rule is a defect. Name it as debt if the type change is out of scope.

## Architecture rules

- Decide boundaries first (domain, ports, adapters), details later (DB, transport, framework).
- Business logic depends on nothing infrastructural.
- Do not abstract before the third occurrence.
- Depth beats count: a module hides a lot behind a small interface. A wrapper that costs as much as it hides is deletion material.
- Complexity moves, it does not vanish. Say where it now lives.
- Do not distribute what need not be distributed.

## ADR: record the why

Write an ADR when a decision is non-obvious, costly to reverse, or rejected an attractive alternative. Template and location: `references/adr-template.md`. One ADR per decision, immutable once accepted, superseded by a new one.

Not an ADR: naming, formatting, anything the code says plainly.

## Glossary

Domain terms in `docs/glossary.md`: term, one-line definition, rejected synonym. Use the exact term in specs, identifiers, feature files, commits. Skip on thin utilities with no domain vocabulary.

## Entry document

`CLAUDE.md` (or `AGENTS.md`) answers *where*: where modules register, which layer owns which rule, which commands verify. If you find it wrong, fix it in the same turn. Keep it short: only stable, load-bearing lines.

## Traceability

```
Spec Acceptance line  →  Gherkin scenario tag (@spec-<id>-<n>)  →  step  →  use case
```

Every Acceptance line has a test. Every scenario tag points to a line. A line without a test is not accepted. A test without a line is scope creep or a missing line: decide which.

## Spec size

| Size | Artifact |
|------|----------|
| S | none |
| M | mini-spec (7 fields) |
| L | full spec + decomposition + ADRs where needed |

One planning pass per task. Never a spec and a separate plan for the same M task.
