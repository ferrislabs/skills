# `.claude/ferris.local.md`

Per-repository answers, asked once, then applied without re-asking. Change only when the user does.

```markdown
# ferrislabs preferences

pickup-label: ready              # issues the agent may take
blocked-label: blocked           # must already exist in the repo
skip-labels: infra, blocked      # issues the agent never takes
assignee: @me                    # account the agent claims with
reviewers: alice, bob            # CODEOWNERS wins where it applies
labels-for-pr: feat, fix, chore  # only labels that exist

max-issues-per-run: 5
max-subagents-in-flight: 4
max-subagents-per-issue: 12

allowed:
  - comment-on-issue
  - assign-self
  - create-branch
  - commit
  - push-feature-branch
  - open-pr
human-only:
  - merge
  - close-issue
  - delete-branch
  - create-label
  - edit-ci
  - publish
  - release
  - promote-production
  - edit-secrets-or-rbac
  - edit-workflow-permissions
  - cluster-write

default-branch: main
verify-exit: |
  cargo fmt --check
  cargo clippy --workspace --all-targets -- -D warnings
  cargo nextest run --workspace
```

## Kickoff questions (one batch, when the file is missing)

1. Which label marks an issue as takeable by the agent?
2. Which of these may the agent do alone: push a branch, open a PR, assign itself, comment?
3. Who reviews?
4. Limits: issues per run, sub-agents in flight?

Recommend the defaults above for each. Infrastructure rules: `devops-safety`.
