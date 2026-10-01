# Briefing and report templates

A sub-agent starts with zero context. Everything it needs is in the briefing. Six sections, always.

## Briefing

```
Mission:
  <one sentence>

Context:
  <decisions already made and why; state of sibling workstreams; issue #N link>

Frozen contracts (read-only):
  <types/ports verbatim, or exact file paths>

Scope:
  Owns:        <files it may write>
  Must not touch: <files>
  Report instead of editing: <convergence points, with the exact line needed>
  Imitate:     <path of a module with the right layering>
  (Review/scout agents: "writes no files, reports only")

Verification:
  <exact commands, scoped to the crate; rtk-prefixed if available>
  Regime: <sequential = run full exit block | concurrent = stay scoped>

Report format:
  files_changed: [...]
  commands_run: [{cmd, result}]   # actual output, one line each
  deviations: [...]
  open_questions: [...]
  Terse. No preamble, no recap.

Rules:
  Output rules: report in terse structured form. No preamble, no recap.
  Comments in code: none. Only an explicit line below overrides this one.
  Code rules: no async-trait. Static dispatch first, enum second, dyn only if allowed here. Borrow instead of clone.
  Scope: write only the files under Owns. Anything else: stop and report.
```

## Scout briefing (haiku)

```
Mission: find <fact>.
Search in: <paths>.
Return: max 10 lines. Paths with line numbers and one-line facts. No file contents.
Writes no files, reports only.
```

## Mechanic briefing (haiku)

```
Mission: apply <exact transformation> to <exact files>.
Example before/after: <snippet>
Owns: <files>
Verification: <command>
Report: files changed, command output.
Rules: no comments, do not touch anything else.
```

## Reviewer briefing (sonnet)

```
Mission: review the diff for <ONE lens: correctness | security | spec conformance | performance>.
Diff: <command to obtain it>
Spec: <acceptance lines>
Writes no files, reports only.
Report: findings as [{severity: blocking|important|cosmetic, file:line, problem, fix}]. Empty list is a valid answer.
```

## Accepting a report

1. Diff the changed-files list against the declared partition. Overlap: stop, decide.
2. Read the diff yourself.
3. Re-run the verification commands yourself.
4. Deviation: accept and log why, or continue the same agent with a correction.
5. Two failed rounds: take it over or re-scope.
