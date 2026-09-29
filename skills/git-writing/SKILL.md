---
name: git-writing
description: Writes commits, pull requests, issues and review replies that read as written by a human maintainer - short, factual, no AI tells - by combining the i-have-adhd rules with the humanizer skill. Consult whenever drafting or editing a commit message, PR title or description, issue, changelog entry, or review comment, and before opening any of them.
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

Write in this order, as plain paragraphs:

1. What changes and why (2 to 4 sentences).
2. What the reviewer must know that the diff does not show: rejected alternatives, what was measured, what is deferred.
3. What was verified, as a result: `nextest: 412 passed, 0 failed`. What was not verified, in one sentence.
4. Link: `Closes #N` or `Refs #N`. If no issue exists, say so.

Rules:

- Opens complete: reviewers, assignee, labels set in the creation command. Labels only from the existing set. Never guess a reviewer.
- The description is part of the diff. Before pushing to an open PR, re-read it. Rewrite it if a commit made it false.
- The diff is the ceiling. Extra findings go in an issue, linked.
- Paste a result, not a transcript.
- For Rust PRs: name any `dyn`, `async-trait`, or new dependency and give the reason in one line.

## Issues

- Title: the problem, not the solution. Under 70 characters.
- Body: what is broken or missing, where (file, version, command), how to reproduce, expected versus actual. Proposed fix last, if any.
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

1. Draft with the rules above. No headings if under one page.
2. If longer than a few paragraphs, run the `humanizer` skill on the draft. Tell it: facts are frozen (SHAs, numbers, paths, versions, link targets do not change).
3. Read the three latest comments a human maintainer wrote in this repo. Match their length and register.
4. Final check as the reader: do they know what changed, why, how it was checked, and what to do?
5. Outward-facing: show the user the draft in French summary + English text. Post only when they agree, unless the repo preferences already authorize it.
