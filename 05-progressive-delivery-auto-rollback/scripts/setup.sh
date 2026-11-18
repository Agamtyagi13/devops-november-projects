#!/usr/bin/env bash
# Local demo: kind + Argo CD + Argo Rollouts + kube-prometheus-stack (Prometheus & Grafana)
set -euo pipefail
kind create cluster --name progressive --wait 120s || true

helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/prometheus-values.yaml
helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace

kubectl apply -f argocd/application.yaml
echo "Grafana:  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80  (admin / prom-operator)"
echo "Import monitoring/grafana-dashboard.json into Grafana."
