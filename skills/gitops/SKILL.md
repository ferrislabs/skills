---
name: gitops
description: GitOps conventions at Ferrislabs with ArgoCD and Kargo - config repo layout, app-of-apps per environment, naming, sync waves, Kargo Warehouse/Stage/ProjectConfig promotion (dev and staging automatic, production manual), image tagging, adding an environment or a service, and debugging sync or promotion. Consult when touching a *-infra repo, an ArgoCD Application, a Kargo object, environment values, or an image tag.
---

# GitOps: ArgoCD + Kargo

Reference implementation: `/opt/ferrislabs/mestier-infra` (README documents every choice). Read it before adding an environment. Verify a path still exists before citing it.

Always apply `devops-safety` first.

## Principles

1. Git is the only way to change the cluster. `kubectl apply` is for bootstrap only.
2. Code repo and config repo are separate. CI builds images in the code repo. Promotion writes the tag in the config repo.
3. One ArgoCD instance, environments isolated by namespace.
4. Kargo drives promotion by committing the new tag to the config repo `main`. ArgoCD syncs it like any change.
5. Image tags are immutable: `sha-<commit>`. Never `latest` in values.

## Config repo layout

```
<project>-infra/
  charts/argocd/  charts/kargo/        wrapper charts
  kargo/<project>-delivery/            Project, ProjectConfig, Warehouse, Stages, Application
  base/<app>/                          env-agnostic bases and common values.yaml
  envs/{dev,staging,production}/
    root.yaml                          app-of-apps for the whole env
    apps/                              Application manifests managed by root.yaml
    <app>/                             overlays + env values.yaml
```

DRY comes from Kustomize base plus overlays for raw manifests, and layered Helm values (`base/.../values.yaml` then `envs/<env>/.../values.yaml`).

## Naming

- Root app-of-apps: bare env name (`staging`, `dev`). Production keeps historical bare names.
- Other Applications in an env: `<name>-<env>` (`mestier-db-staging`).
- Namespace: `<project>-<env>`.
- Application names share one flat `argocd` namespace. Check `argocd app list` for uniqueness before choosing one.

## Sync order

- `argocd.argoproj.io/sync-wave`: data layer (DB, cache) wave 0, application wave 1.
- Kargo objects: Project wave -1, ProjectConfig and Warehouse wave 0, Stages in promotion order (dev 1, staging 2, production 3).
- App migrations: PreSync hook Job. See `kubernetes`.
- Pinned chart versions must be published before the Application that references them. Out of order gives `ComparisonError`, self-healing but confusing.

## Promotion pipeline

```
push main (code repo) → CI builds sha-<commit> → Warehouse → dev (auto) → staging (auto, only Freight verified on dev) → production (manual)
```

### Warehouse

```yaml
spec:
  interval: 5m
  subscriptions:
    - image:
        repoURL: ghcr.io/ferrislabs/<app>
        imageSelectionStrategy: NewestBuild
        allowTagsRegexes:
          - "^sha-"
        cacheByTag: true
```

- `NewestBuild` because sha tags have no semver or lexical order.
- `allowTagsRegexes: ^sha-` is mandatory when CI also pushes `latest`. Otherwise `latest` can win, `yaml-update` writes an unchanged value, the diff is empty, and the Freight never lands.

### ProjectConfig

Auto-promotion lives here, not on the Stage. Same name and namespace as the Project.

```yaml
spec:
  promotionPolicies:
    - stageSelector: { name: dev }
      autoPromotionEnabled: true
    - stageSelector: { name: staging }
      autoPromotionEnabled: true
    - stageSelector: { name: production }
      autoPromotionEnabled: false
```

### Stage steps

```
git-clone → yaml-update → git-commit → git-push → argocd-update → [production: git-tag → git-push tag] → http (notify)
```

- `requestedFreight.sources.stages` chains environments: staging sources `dev`, production sources `staging`.
- `argocd-update` blocks until the app is Healthy. Everything after it proves a verified promotion. Keep tag and notification after it.
- Production tags the config repo `production-<tag>` as the audit trail.
- Push credentials: a Secret labelled `kargo.akuity.io/cred-type: git` in the project namespace.
- Kargo Project namespace is created by Kargo from the labelled Project object. Do not pre-create it with `CreateNamespace=true`.

Kargo syntax changes between versions. Check the installed version's docs before editing a Stage.

## Add an environment

1. Copy `envs/staging/` to `envs/<env>/`. Rename Applications with the `-<env>` suffix, namespace `<project>-<env>`.
2. Own values file with image tag placeholders.
3. Add a Stage `<env>` with its `sources`, sync wave, and `argocd-update` target.
4. Add its policy to `ProjectConfig`. Default `autoPromotionEnabled: false` until agreed.
5. Register DNS and hostname. Own OIDC client per environment even if the realm is shared, so tokens do not cross environments.
6. Validate: `helm template`, `kubeconform`, `argocd app diff`. PR. Human applies `root.yaml`.

## Add a service to the pipeline

1. Code repo CI pushes `ghcr.io/ferrislabs/<svc>:sha-<commit>` (see `cicd`).
2. Add an image subscription to the Warehouse with `^sha-`.
3. Add its `image.tag` key to each Stage's `yaml-update` and to each env values file.
4. Add its Application under each env `apps/`.

## Debug

| Symptom | Check |
|---------|-------|
| Freight never lands | Tag filter. `latest` winning gives an empty diff. |
| Application `ComparisonError` | Chart version not published yet. |
| Sync stuck Progressing | Wave ordering, missing Secret, hook Job failing. `argocd app get <app>`. |
| Promotion stuck at `argocd-update` | Target app not Healthy. Read the app, not Kargo. |
| Drift keeps reverting | Someone edited the live object. Fix in git. |
| Namespace not adopted | Project missing `kargo.akuity.io/project: "true"` label. |

Read-only commands: `argocd app get|diff|list`, `kargo get stages|freight -p <project>`, `kubectl get|describe|logs -n <ns>`.

## Rollback

`git revert` the promotion commit on the config repo `main`. ArgoCD syncs back. Production revert is human-only. Data migrations are not undone by a revert.
