---
name: kubernetes
description: Kubernetes and Helm conventions at Ferrislabs for Rust services - chart layout, values layering, Gateway API HTTPRoute, CloudNativePG, migration Jobs as ArgoCD hooks, probes, resources, securityContext, PodDisruptionBudget, NetworkPolicy, secrets, graceful shutdown, and the validation commands to run before a PR. Consult when writing or reviewing a chart, a manifest, a Kustomize overlay, or when a service needs deployment settings.
---

# Kubernetes and Helm

References: `/opt/ferrislabs/mestier/deploy/helm/mestier` (service chart), `/opt/aether/charts/aether-control-plane` (chart with values-production.yaml), `/opt/aether/deploy/` (ArgoCD, OpenBao). Verify paths before citing.

Apply `devops-safety` first. Cluster changes go through git (`gitops`).

## Chart layout

```
Chart.yaml
values.yaml                 defaults, safe for dev
values-production.yaml      overrides only
templates/
  _helpers.tpl
  <component>/deployment.yaml service.yaml hpa.yaml configmap.yaml secret.yaml
  migration-job.yaml
  httproute.yaml
  serviceaccount.yaml
  NOTES.txt
```

- One directory per component (api, webapp).
- Every knob in `values.yaml` with a default. No hidden required value.
- Bump `Chart.yaml` `version` on any template or default change. The release workflow publishes a version once and skips one already published.
- Values layering in the config repo: `base/.../values.yaml` then `envs/<env>/.../values.yaml`.

## Exposure

- Gateway API `HTTPRoute` on the shared Envoy Gateway. `Ingress` only when a chart must also support clusters without Gateway API, behind a flag.
- TLS from cert-manager (`ClusterIssuer`), wildcard cert on the Gateway.
- One host per environment, path-routed (`/api` to api, rest to webapp), when possible.
- `ALLOWED_ORIGINS` and OIDC redirect URIs follow the host. Change them together.

## Database

- PostgreSQL through CloudNativePG (`Cluster` resource) as its own Application at sync wave 0. App at wave 1.
- Connection string from the CNPG-generated secret (`<cluster>-app`), by `secretKeyRef`.
- Migrations: a `Job` annotated as an ArgoCD `PreSync` hook, `hook-delete-policy: BeforeHookCreation`. It runs before the new pods. It must be idempotent and reversible.
- A migration that breaks the previous version's queries needs two releases (expand, then contract).
- sqlx: `.sqlx/` offline data committed and current.

## Pod spec baseline

Every workload:

```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: ["ALL"] }
    resources:
      requests: { cpu: 100m, memory: 128Mi }
      limits: { memory: 256Mi }
    readinessProbe: { httpGet: { path: /health/ready, port: http } }
    livenessProbe: { httpGet: { path: /health/live, port: http } }
```

Numbers are starting points. Set them from measurement, not habit.

- Requests always. Memory limit always. CPU limit only if throttling is acceptable.
- Readiness and liveness are different endpoints. Liveness never checks the database.
- `startupProbe` for slow starts instead of a long liveness delay.
- Image by tag `sha-<commit>` set from values. Never `latest`. `imagePullPolicy: IfNotPresent`.
- Writable paths (`/tmp`) as `emptyDir` when the root filesystem is read-only.

## Availability

- `replicas >= 2` in production. `PodDisruptionBudget` (`minAvailable: 1`).
- `HorizontalPodAutoscaler` on CPU or a request-based metric, with `minReplicas` equal to the baseline.
- Spread: `topologySpreadConstraints` on hostname when more than one node.
- Rolling update: `maxUnavailable: 0`, `maxSurge: 1` for stateless services.

## Graceful shutdown (Rust)

- Handle `SIGTERM`: stop accepting, drain in-flight requests, then exit (axum `with_graceful_shutdown`).
- `terminationGracePeriodSeconds` greater than the drain timeout.
- Flush telemetry (OpenTelemetry) on shutdown.
- Config by environment variables from ConfigMap and Secret. `RUST_LOG` from values.

## Network and secrets

- `NetworkPolicy`: default deny ingress in the namespace, then allow gateway to app, app to database.
- Secrets never in the chart values in clear. Options in order of preference: External Secrets or OpenBao, a Secret created out of band and referenced by name, sealed secrets. Document the out-of-band step in the chart README.
- `ServiceAccount` per workload, `automountServiceAccountToken: false` unless the pod calls the API.
- RBAC: least privilege, namespaced `Role` over `ClusterRole`.

## Multi-environment differences

Only these differ per environment: host, replicas, resources, image tag, OIDC client, bucket or database names. Anything else differing is a smell.

## Validate before a PR

```
helm dependency build charts/<chart>
helm lint charts/<chart> -f <values>
helm template <release> charts/<chart> -f <values> | kubeconform -strict -summary -ignore-missing-schemas
kubectl diff -f <rendered>            # read-only, needs cluster access
```

Attach a rendered before/after diff summary to the PR (`devops-safety`).

## Review checklist

1. Probes, requests, memory limit present?
2. `runAsNonRoot`, dropped capabilities, read-only filesystem?
3. Tag pinned, not `latest`?
4. Secret referenced, not inlined?
5. Migration is a PreSync Job and reversible?
6. PDB and replicas for production?
7. Chart `version` bumped?
8. `values.yaml` documents each new key?
