# Spec templates

Location: the PR description for M. `docs/specs/<name>.md` for L (also the workstream state artifact, see `dev-methodology/references/orchestration.md`).

## Mini-spec (M)

```
Goal:         <one sentence>
Invariants:   <rules that must hold. Say which are enforced by type, which by test>
Out of scope: <what this change does not do>
Acceptance:   <numbered, observable, each becomes a test>
              1. ...
              2. ...
Modules:      <bounded contexts touched. Many = misplaced, not large>
Files:        <expected files>
Verify (exit): <exact commands, run once at the end>
Verify (loop): <scoped command, if not obvious>
```

## Full spec (L)

```
# <Feature name>

Goal
  <one sentence>

Context
  <why now, what exists, links to issue and ADRs>

Glossary
  <new terms only>

Invariants
  - <rule>  [type | test]

Out of scope
  - <item>

Design
  Domain:   <entities, value objects, use cases>
  Ports:    <trait names, owner module, dispatch choice: generic | enum | dyn + reason>
  Adapters: <per port>
  Errors:   <enum per boundary>

Acceptance (Gherkin)
  @spec-<id>-1  Scenario: ...
  @spec-<id>-2  Scenario: ...

Simulation
  <needed? which invariant, which rung. Or: no, because ...>

Workstreams
  <name, mission, depends on, owned files>

Frozen contracts
  <types/ports verbatim>

Risks / open questions
  <each with an owner>

Verify (exit)
  <commands>
```

## Rules

- Acceptance lines are observable. "Works well" is not one.
- Each Invariant states its enforcement: `type` or `test`. A `test` on something a type could carry is debt.
- Amendments: edit in place, add `Amended: <date> <one line why>` at the bottom.
