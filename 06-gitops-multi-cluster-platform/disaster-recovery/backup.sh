#!/usr/bin/env bash
# Backs up what Git does NOT hold: Argo CD cluster registrations/secrets & app state export. Run on a schedule (CronJob/CI).
set -euo pipefail
OUT="dr-backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
CTX="${1:-kind-dev}"
kubectl --context "$CTX" -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster -o yaml > "$OUT/argocd-clusters.yaml"
kubectl --context "$CTX" -n argocd get applications,applicationsets,appprojects -o yaml > "$OUT/argocd-apps.yaml"
echo "Backup in $OUT  (store encrypted, e.g. aws s3 cp --sse AES256 -r)"
