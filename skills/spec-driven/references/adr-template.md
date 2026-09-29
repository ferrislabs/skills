# ADR template

Location: `docs/adr/NNNN-short-title.md`. Number sequentially, never reuse.

```
# NNNN. <Decision as a short statement>

Status: proposed | accepted | superseded by NNNN
Date: <YYYY-MM-DD>

## Context
What forces the decision. Facts and constraints only.

## Decision
What we do. One paragraph.

## Alternatives rejected
- <alternative>: <why not>
- <alternative>: <why not>

## Consequences
- Gains:
- Costs:
- What becomes harder:
```

## Rules

1. One decision per ADR.
2. Accepted ADRs are not edited except `Status`. Change of mind = new ADR that supersedes.
3. Always list at least one rejected alternative. If there was none, it was not a decision.
4. Keep under one page.
5. Typical Ferrislabs ADR topics: a `dyn` in a port, a new dependency, a persistence choice, a crate boundary, a public API shape, a deviation from `rust-dev` rules.
