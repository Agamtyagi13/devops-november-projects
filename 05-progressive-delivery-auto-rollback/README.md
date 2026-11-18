# Kubernetes Progressive Delivery with Automated Rollback

Canary releases via **Argo Rollouts**, deployed by **Argo CD** from a **Helm** chart, built by **GitHub Actions**, gated by **Prometheus** service-level checks, visualised in **Grafana**.

## Flow
```
git push → GitHub Actions (lint, build, push image, bump chart tag) → Argo CD syncs
        → Argo Rollouts: 20% → pause (gate) → 50% → pause (gate) → 100%
        → AnalysisTemplate queries Prometheus every 20s: success-rate ≥ 95%, p95 latency ≤ 0.5s
        → any failed check aborts the rollout and traffic returns to the stable ReplicaSet (automatic rollback)
```

## Requirement mapping
| Requirement | Where |
|---|---|
| Canary release | `chart/templates/rollout.yaml` (`strategy.canary`) |
| Health metrics | app exposes `/metrics`; `ServiceMonitor` scrapes; Grafana dashboard in `monitoring/` |
| Promotion gates | `setWeight` + `pause` steps, plus background `analysis` |
| Automated rollback | `AnalysisTemplate` failure → Rollout aborts → stable version keeps 100% traffic |
| CI | `.github/workflows/ci-cd.yml` |

## Run locally
```bash
# prerequisites: docker, kind, kubectl, helm, kubectl-argo-rollouts plugin
./scripts/setup.sh
# build/load the image (or push via CI): docker build -t ghcr.io/OWNER/progressive-demo:v1 app && kind load docker-image ... --name progressive
./scripts/demo.sh      # good release promotes; bad release (50% errors) auto-rolls back
kubectl argo rollouts dashboard
```
Replace `OWNER`/`REPO` placeholders in `chart/values.yaml` and `argocd/application.yaml`.

## Simulating failure
`ERROR_RATE` and `LATENCY_MS` env vars (chart values `app.errorRate`, `app.latencyMs`) make a release deliberately unhealthy.
