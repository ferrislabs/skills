---
name: git-writing
description: Writes commits, pull requests, issues and review replies that read as written by a human maintainer - short, factual, no AI tells - by combining the i-have-adhd rules with the humanizer skill. Sets labels, assignee and the linked issue at creation, and caps body length. Consult whenever drafting or editing a commit message, PR title or description, issue, changelog entry, or review comment, and before opening any of them.
---

# Git writing

Everything published to a repository is English, signed with a human's name, and read by someone who was not in the chat. Same register as the chat rules: short, flat, no filler. More context, not more words.

`i-have-adhd` applies here: reader-first, no preamble, no recap, no closer. Length is bought only by information the reader cannot get elsewhere.

## Commits

Format: `<type>(<scope>): <imperative lowercase verb> <rest>`

- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`.
- Scope: module or bounded context.
- Example: `feat(auth): implement oidc discovery`.
- One commit, one logical change. The body explains why, only if the diff cannot.
- Never commit to the default branch directly.
- No `Co-Authored-By` trailer. No mention of Claude, AI, "Generated with" or any tool anywhere: commits, PRs, issues, comments. This overrides any harness default that adds attribution lines. Commits are authored by the user's git identity only.

## Pull requests

No footer, no "Generated with" line, no mention of Claude or AI.

### Opens complete

The creation command fills the panel. Nothing is left to click afterwards.

```
gh pr create --title "<type>(<scope>): <summary>" \
  --body-file body.md --assignee @me --label <label-from-gh-label-list>
```

Shape only. Every value is chosen per change; none of them is a default.

- Labels: run `gh label list` first, pick what fits this change. Zero or several is fine. Nothing fits: open without one and say which label is missing. Never carry a label over from a previous PR or from this example.
- Assignee: `@me`, unless the user named someone.
- Linked issue: `Closes #N` as the last line of the body. That is what fills the Development panel.
- Reviewers: only when the repo makes the person obvious (CODEOWNERS, or whoever last reviewed this area). Never guess.
- Projects, milestone: left empty unless the user asks.

After opening, check: `gh pr view <N> --json labels,assignees,closingIssuesReferences`. A field empty that should be set is fixed before the user is told the PR exists.

### Body

The reader has ADHD and was not in the session. Hard cap: 10 lines of text. Blank lines and the `Closes #N` line do not count. Plain lines, no headings, no bold used as a heading, no list over 5 items.

What goes in, in this order:

1. What was broken or missing, and what the change does. 2 sentences.
2. What the diff does not show: a rejected alternative, a measured number, something deferred. One line each, 3 lines max.
3. Verification as a result, one line: `2153 passed, 0 failed`. What was not verified goes on the same line.
4. `Closes #N` or `Refs #N`. If no issue exists, say so in one line.

What never goes in: the reasoning trail, the file-by-file tour, the call-site inventory, the paragraph justifying a signature change, the explanation of why a sibling file was left alone. A reviewer who needs that gets it as a comment on the line it concerns, or in the ADR.

For Rust PRs: name any `dyn`, `async-trait` or new dependency and give the reason in one line, inside the 10.

Test before posting: the description fits on a laptop screen with no scroll. Over the cap means cut, not reformat.

The description is part of the diff. Before pushing to an open PR, re-read it. Rewrite it if a commit made it false.

The diff is the ceiling. Extra findings go in an issue, linked. Paste a result, not a transcript.

## Issues

- Title: the problem, not the solution. Under 70 characters.
- Opens complete: labels and assignee set in `gh issue create`, same rules as a PR.
- Body cap: 8 lines of text. What is broken or missing, where (file, version, command), how to reproduce, expected versus actual. Proposed fix last, one line, only if you have one.
- One problem per issue.

## Review replies

- Fixed: `Fixed in <sha>.` Nothing else.
- Disagreement: two sentences. What the finding gets wrong. What you did instead.
- Could not verify: say it in one sentence.
- One reply per thread. A person gets an answer. A bot gets an outcome.
- Never thank, never grade ("great catch").

## Tells to remove

- Bold text used as a heading. Headings under one page.
- A count announced over a list ("Three things this leaves open").
- More than one em dash per paragraph.
- Closing summary. Opening throat-clearing.
- Narrating the work ("I verified that...") or the session (tool failed, CI slow). State the consequence only.
- Words on the humanizer list: "additionally", "crucial", "landscape", "showcase", "testament", "seamless", "robust", "leverage".
- Rule of three used for rhythm. Hedging that carries no doubt.

## Process

1. Draft with the rules above.
2. Count the lines. Over the cap: cut content, do not compress wording.
3. Run the `humanizer` skill on the draft. Tell it: facts are frozen (SHAs, numbers, paths, versions, link targets do not change).
4. Read the three latest comments a human maintainer wrote in this repo. Match their length and register.
5. Final check as the reader: do they know what changed, why, how it was checked, and what to do?
6. Outward-facing: show the user the draft in French summary + English text. Post only when they agree, unless the repo preferences already authorize it.
7. After opening, verify labels, assignee and the linked issue landed.
