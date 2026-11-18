# Disaster Recovery Runbook

**Principle:** Git is the source of truth. Clusters are cattle; rebuilding = bootstrap + sync.

| Scenario | RTO target | Procedure |
|---|---|---|
| Workload cluster (prod) lost | ~15 min | `./disaster-recovery/restore.sh workload` → re-register cluster in Argo CD (`env=prod` label). ApplicationSets re-create addons → policies → apps automatically (sync waves). |
| Management cluster (Argo CD) lost | ~20 min | `REPO_URL=... ./disaster-recovery/restore.sh management <backup-dir>`; restores cluster registrations and root app; workload clusters keep running meanwhile. |
| Bad commit pushed | ~5 min | `git revert <sha>`; Argo CD auto-syncs (`selfHeal`). |
| Secret backend outage | n/a | Existing K8s Secrets keep working; ExternalSecrets resume refresh on recovery. |

**Backups:** `backup.sh` (daily) exports cluster registrations + Argo CD objects. App data/state is out of scope (stateless demo); for stateful apps add Velero.

**Drill (do quarterly):** 1) `kind delete cluster --name prod`  2) run restore  3) verify `kubectl --context kind-prod get pods -A` and Argo CD apps `Healthy/Synced`  4) record the measured RTO below.

| Date | Scenario | Measured RTO | Notes |
|---|---|---|---|
|  |  |  |  |
