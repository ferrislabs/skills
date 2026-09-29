---
name: cicd
description: CI/CD conventions at Ferrislabs on GitHub Actions for Rust services - quality gates, caching, pinned toolchains, Postgres integration jobs that cannot skip silently, multi-arch image build and push to ghcr, immutable sha tags, Helm chart release, infra validation, and supply-chain hardening. Consult when writing or reviewing a workflow, a Dockerfile, a release process, or when CI is slow, flaky, or red.
---

# CI/CD

Reference workflows: `/opt/ferrislabs/mestier/.github/workflows/` (`docker.yaml`, `helm-chart-release.yaml`, `codspeed.yaml`) and `/opt/aether/.github/workflows/` (`docker.yaml`, `infra.yaml`). Verify paths before citing.

Apply `devops-safety`: workflow edits touching permissions, secrets, deploy or publish steps are human-only.

## Pipeline shape

```
fmt ─┐
clippy ─┼─→ integration (real Postgres) ─→ build image ─→ push manifest ─→ (Kargo picks up sha tag)
test ─┘
webapp (lint, test, build) in parallel
```

Push to `main` and tags publish. Pull requests build but do not push.

## Rust quality gates

- One matrix entry per task (`fmt`, `clippy`, `test`), `fail-fast: false`, each with its own cache slot (`Swatinem/rust-cache` with `shared-key: rust-${{ matrix.task }}`), `cache-on-failure: true`, no target cache for `fmt`.
- Toolchain pinned to an exact version. Bump it in its own PR.
- Env: `CARGO_TERM_COLOR: always`, `RUSTFLAGS: "-D warnings"`, `CARGO_INCREMENTAL: 0`.
- `--locked` on clippy, test and build. A stale `Cargo.lock` fails CI.
- Commands: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets --locked -- -D warnings`, `cargo nextest run --workspace --locked` (or `cargo test`), plus `cargo test --doc`.
- sqlx: `SQLX_OFFLINE=true` and a check that `.sqlx/` is current (`cargo sqlx prepare --check --workspace -- --all-targets`).

## Integration job

- Real `postgres` service container with a health check.
- Set `DATABASE_URL` and `REQUIRE_DATABASE_URL=1`. Tests that skip when the database is missing must fail in CI. A green job that ran nothing is a bug.
- Run migrations up, and down then up, before the tests.

## Triggers

- `pull_request` without a base-branch filter. Stacked PRs target another branch and would otherwise merge with no CI.
- Path filters on PR and push, and every workflow lists its own file in `paths` so editing it triggers it.
- `concurrency: group: ${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`. Exception: release and publish workflows use `cancel-in-progress: false` so the check-then-push sequence stays atomic.
- `workflow_dispatch` with a `push` boolean for manual image builds.

## Permissions

- Top-level `permissions: contents: read`. Grant `packages: write` only on the job that pushes.
- No `pull_request_target` with checkout of PR code. No secrets on fork PRs.
- Use `GITHUB_TOKEN` over personal tokens.

## Image build

- Multi-stage `Dockerfile`, non-root user, minimal runtime image, one target per binary.
- `docker/build-push-action` per platform with `push-by-digest`, then a `push-manifest` job assembling the multi-arch manifest. Split by platform, not by emulation.
- Tags from `docker/metadata-action`: semver on version tags, `sha`, `pr` for pull requests, `latest` only on the default branch.
- Deploy tags are `sha-<commit>`. Kargo Warehouse filters `^sha-`. Changing the tag format breaks promotion (`gitops`).
- `should-push` gate: push only on `main`, tags, or manual dispatch with `push=true`.
- Cache: buildx cache with `mode=max`, rotated to avoid unbounded growth.

## Helm chart release

Idempotent:

1. Read `version` from `Chart.yaml`. Fail on empty or `null`.
2. `helm show chart oci://ghcr.io/ferrislabs/charts/<chart> --version <v>` to test existence.
3. Publish only if absent. Never overwrite a published version.
4. Queued concurrency, not cancelled.

## Infra validation job

- `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate`.
- `shellcheck` pinned by version in a container, so a runner update does not redden unrelated PRs.
- `helm lint` and `helm template | kubeconform` for charts.
- `yamllint` optional.

## Performance regressions

Benchmarks versioned and thresholded (CodSpeed with divan). A regression is a failing check.

## Supply chain (recommended, add as agreed)

Not all present today. Propose one at a time, each as its own PR.

1. Pin third-party actions by commit SHA.
2. `cargo deny check` (licenses, bans, sources) and `cargo audit` on a schedule.
3. Image scan (Trivy or Grype) failing on HIGH and CRITICAL with a fixed base.
4. SBOM and provenance from `build-push-action` (`sbom: true`, `provenance: mode=max`).
5. Image signing with cosign keyless, and admission verification later.
6. Dependabot or Renovate for actions, cargo and Docker base images, grouped weekly.

## Speed levers (in order)

1. Right cache key per task. 2. `--locked` and no incremental. 3. Split slow integration from fast checks. 4. `nextest`. 5. `sccache` only if compile time dominates after 1 to 4. 6. Path filters.

## Debug a red CI

1. Read the first failing step's full log, not the last line.
2. Reproduce locally with the exact command and toolchain.
3. Flaky: rerun once to classify. A test that passes on rerun is a bug to fix, not a retry to add.
4. Never `continue-on-error` to get green. Never delete a failing check.

## Review checklist

1. Toolchain pinned, `--locked` present?
2. Permissions minimal, per job?
3. Integration tests fail when the database is missing?
4. Workflow lists itself in `paths`?
5. Image tags follow `sha-<commit>`?
6. Release step idempotent?
7. Any new action pinned?
