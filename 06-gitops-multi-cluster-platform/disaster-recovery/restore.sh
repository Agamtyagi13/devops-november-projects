#!/usr/bin/env bash
# Rebuild a lost management cluster or a lost workload cluster from Git.
set -euo pipefail
case "${1:-}" in
  workload)  # a workload cluster (prod) was lost: recreate it, re-register; Argo CD repopulates everything from Git
    kind delete cluster --name prod || true
    kind create cluster --config clusters/prod.yaml
    echo "Re-register: argocd cluster add kind-prod --name prod --label env=prod"
    ;;
  management)  # the Argo CD cluster (dev) was lost
    REPO_URL="${REPO_URL:?}" ./bootstrap/bootstrap.sh
    [ -n "${2:-}" ] && kubectl --context kind-dev apply -f "$2/argocd-clusters.yaml"
    ;;
  *) echo "usage: restore.sh workload | management [backup-dir]"; exit 1;;
esac
