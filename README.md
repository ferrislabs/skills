# ferrislabs skills

Claude Code plugin for Ferrislabs.

## Install

```
/plugin marketplace add ./skills
/plugin install ferrislabs@ferrislabs-skills
```

Validate after any change: `claude plugin validate .`

## Skills

| Skill | Role |
|-------|------|
| `i-have-adhd` | Vendored from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT). Always on, no off switch. |
| `ferris-communication` | Autism + ADHD output rules: French, literal, direct, predictable. Always on. |
| `dev-methodology` | Sizing (Iteration, S, M, L), the three blocking waits, done means done, sub-agents. |
| `spec-driven` | Spec before code, question batch, ADRs, glossary, Acceptance → tests. |
| `architecture` | Hexagonal, dependency direction, clean code, near-zero comments. |
| `agent-orchestration` | Issue-driven autonomous agent. Main keeps decisions, sonnet implements, haiku searches and does mechanical edits. |
| `gitops` | ArgoCD + Kargo: config repo layout, promotion pipeline, adding an env or a service, debugging. |
| `kubernetes` | Helm chart conventions, Gateway API, CNPG, probes, security context, validation. |
| `cicd` | GitHub Actions for Rust: gates, caching, image build, chart release, supply chain. |
| `devops-safety` | Read / change-by-PR / human-only classes for infra. Overrides agent autonomy. |
| `rust-dev` | Static > enum > dyn, no `async-trait`, memory discipline, hexagonal, types, errors. |
| `rust-testing` | Unit, integration, Gherkin (cucumber-rs), property, simulation. |
| `git-writing` | Commits, PRs, issues, review replies. Humanized, uses `humanizer`. |

## Agents and command

| File | Model | Role |
|------|-------|------|
| `agents/ferris-implementer.md` | sonnet | Implements one workstream |
| `agents/ferris-reviewer.md` | sonnet | One review lens, read-only |
| `agents/ferris-scout.md` | haiku | Read-only fact finding |
| `agents/ferris-mechanic.md` | haiku | Mechanical edits |
| `commands/work-issues.md` | session | `/ferrislabs:work-issues [label]`, the issue loop |

Per-repo config: `.claude/ferris.local.md` (template in `skills/agent-orchestration/references/config-template.md`).

## Always-on mechanism

`hooks/hooks.json` runs `hooks/always-on.sh` at every `SessionStart` (startup, resume, clear, compact). It prints the bodies of `i-have-adhd` and `ferris-communication` into the session context. No flag file, no opt-in.

`i-have-adhd` has no `disable-model-invocation`, and its description says it is always active, so it also loads by description if the hook is absent.

## Dependencies

- `humanizer` skill (used by `git-writing`).

## Vendored code

`skills/i-have-adhd/` is a copy of upstream with two edits: frontmatter (no `disable-model-invocation`, new description) and the Persistence section (no off switch). License: `skills/i-have-adhd/LICENSE`.
`skills/dev-methodology/references/orchestration.md` is copied from LeadcodeDev/skills.
