---
name: devops-safety
description: Safety rules for any infrastructure work at Ferrislabs - Kubernetes, ArgoCD, Kargo, Helm, Terraform, CI/CD workflows, secrets, RBAC. Defines what an agent may read, what it may only change through a pull request, and what stays human-only. Consult before running kubectl, helm, argocd, kargo or terraform, before editing anything under deploy/, charts/, envs/, kargo/, .github/workflows/, and whenever an issue touches infrastructure.
---

# DevOps safety

Cluster and pipeline mistakes are outward-facing and often irreversible. This skill sets the ceiling. It overrides any autonomy granted elsewhere (`agent-orchestration`).

## Three classes

| Class | Examples | Rule |
|-------|----------|------|
| **Read** | `kubectl get/describe/logs`, `kubectl diff`, `helm template/lint/show`, `argocd app get/diff`, `kargo get`, `terraform validate/plan` | Allowed. Check the context first. |
| **Change by PR** | Chart templates, values for **dev** and **staging**, Kustomize bases, new Application manifests, Kargo Warehouse/Stage edits, non-secret CI changes | PR only. Attach the evidence below. Never applied by hand. |
| **Human only** | Anything in production, secrets, RBAC, cluster-wide resources, Kargo production promotion, CI/CD workflow edits that touch permissions or secrets, DNS, certificates, deletions, `terraform apply`, image or chart publishing | Prepare a proposal. Stop. |

Unsure which class: take the stricter one.

## Before any cluster command

1. `kubectl config current-context`. Say which cluster you are on. Not the expected one: stop.
2. Read-only verbs first. `kubectl diff` before any change.
3. No `delete`, `--force`, `--grace-period=0`, `--prune`, `kubectl edit`, `kubectl patch`, `kubectl apply` on a live cluster. Changes reach the cluster through git and ArgoCD.
4. No `argocd app sync --force`, `--prune`, or `kargo promote` to production.
5. Namespaced commands always carry `-n <namespace>`. No implicit default namespace.

## Evidence attached to an infra PR

1. Rendered diff: `helm template` before/after, or `kubectl diff`, summarized in the PR.
2. Validation result: `helm lint` and `kubeconform` (or `terraform validate`) output as one line.
3. Blast radius: which environments, namespaces and workloads change.
4. Rollback: for GitOps it is `git revert` of the merge. Say if that is not enough (migration, PVC, CRD).
5. What was not verified.

## Secrets

- Never in git, never in a PR, never in a log, never in a briefing. Not even base64.
- Reference by name only: `secretKeyRef`, External Secrets, OpenBao path.
- A secret found in the repo: lead the message with it, do not copy it, propose rotation. Rotation is human-only.
- Do not print `kubectl get secret -o yaml`.

## Production

- Never modified by an agent. Not values, not images, not sync.
- Promotion to production is a human action in Kargo (`autoPromotionEnabled: false`).
- Incident in production: report symptoms and read-only findings. Do not remediate.

## Migrations and data

- Reversible: write and test the `.down.sql`.
- Runs as a Job or PreSync hook, never manually against a shared database.
- Anything that drops, truncates or rewrites data: human only, with backup confirmed.

## CI/CD workflows

Editing `.github/workflows/*` is class **Change by PR** only for build, test and lint steps. Changes to `permissions`, `secrets`, `pull_request_target`, deploy or publish steps, or third-party actions: human only.

## Issues that touch infrastructure

- An issue labelled `infra` is skipped by the autonomous loop (`skip-labels` in `.claude/ferris.local.md`).
- An issue that turns out to need a Human-only action: comment the exact proposal (files, commands, diff), label `blocked`, stop.

## Red flags

| Thought | Reality |
|---------|---------|
| "Just a quick `kubectl edit` to test" | Drift ArgoCD will revert or hide. Change git. |
| "Dev is safe, I can apply directly" | Dev goes through git too. |
| "The secret is only base64" | It is a secret. |
| "Promotion is green, I'll promote prod" | Human only. |
| "The workflow needs `contents: write`" | Permission change: human review. |
| "Same context as last time" | Check it. |
