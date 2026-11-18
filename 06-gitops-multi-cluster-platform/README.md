# GitOps-Based Multi-Cluster Platform

Two clusters (**dev**, **prod**) managed declaratively from one Git repo by **Argo CD** using **ApplicationSets**, **Kustomize** overlays, **Kyverno** policy enforcement, **External Secrets**, **cert-manager**, and a documented DR procedure.

```
bootstrap/                 create clusters, install Argo CD, register clusters, apply root app
platform/applicationsets/  platform-addons (cert-manager, external-secrets, kyverno → every cluster)
                           platform-config (policies, secret store, certs → every cluster)
                           apps (podinfo with per-cluster Kustomize overlay)
platform/policies/         Kyverno ClusterPolicies, ClusterSecretStore/ExternalSecret, Issuer/Certificate
apps/podinfo/              base + overlays/{dev,prod}
disaster-recovery/         backup.sh, restore.sh, RUNBOOK.md
```

| Requirement | Implementation |
|---|---|
| ≥ 2 clusters declaratively | `clusters/`, ApplicationSets with `clusters` generator |
| Policy enforcement | Kyverno: no `:latest`, limits required, non-root (`Enforce`) |
| Secret references | `ExternalSecret` → `ClusterSecretStore`; no secret values in Git |
| Certificate automation | cert-manager `ClusterIssuer` + `Certificate` with auto-renew |
| DR procedure | `disaster-recovery/RUNBOOK.md` + scripts |

## Run
```bash
export REPO_URL=https://github.com/OWNER/REPO.git   # push this repo first; replace REPO_URL in platform/applicationsets/*.yaml too
./bootstrap/bootstrap.sh
```
Verify policy enforcement: `kubectl --context kind-prod -n podinfo run bad --image=nginx:latest` → denied by Kyverno.
Verify cert: `kubectl --context kind-prod -n podinfo get certificate podinfo-tls`.

Note: The `fake` secrets provider is for local demos; swap to AWS Secrets Manager/Vault for real use (comment in `external-secrets.yaml`).
