#!/usr/bin/env bash
# Creates two kind clusters (dev, prod), installs Argo CD on dev (management cluster), registers prod, applies root app.
set -euo pipefail
REPO_URL="${REPO_URL:?set REPO_URL=https://github.com/OWNER/REPO.git}"

kind create cluster --config clusters/dev.yaml  || true
kind create cluster --config clusters/prod.yaml || true

kubectx() { kubectl --context "kind-$1" "${@:2}"; }
kubectx dev create ns argocd --dry-run=client -o yaml | kubectx dev apply -f -
kubectx dev apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectx dev -n argocd rollout status deploy/argocd-server --timeout=300s

# Register prod cluster with Argo CD using the docker-network address of the kind control-plane
PROD_ADDR="https://$(docker inspect prod-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'):6443"
argocd login --core
kubectl config use-context kind-dev
argocd cluster add kind-prod --name prod --label env=prod --upsert --yes \
  --server-url "$PROD_ADDR" 2>/dev/null || echo "Register prod manually: argocd cluster add kind-prod --name prod --label env=prod"
kubectl --context kind-dev -n argocd label secret -l argocd.argoproj.io/secret-type=cluster env=prod --overwrite || true
# in-cluster = dev
kubectl --context kind-dev -n argocd apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: dev
type: Opaque
stringData:
  name: dev
  server: https://kubernetes.default.svc
YAML

sed "s|REPO_URL|$REPO_URL|g" platform/root-app.yaml | kubectl --context kind-dev apply -f -
echo "Done. Argo CD UI: kubectl --context kind-dev -n argocd port-forward svc/argocd-server 8080:443"
