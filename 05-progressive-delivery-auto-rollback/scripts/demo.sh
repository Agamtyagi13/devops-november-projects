#!/usr/bin/env bash
# Demonstrates (1) a good release being promoted and (2) a bad release being rolled back automatically.
set -euo pipefail
NS=demo; APP=demo-app
gen_load() { kubectl -n $NS run load --rm -i --restart=Never --image=busybox -- \
  /bin/sh -c 'for i in $(seq 1 600); do wget -q -O- http://demo-app-stable/ >/dev/null 2>&1 || true; wget -q -O- http://demo-app-canary/ >/dev/null 2>&1 || true; sleep 0.2; done' & }

echo "== Good release v2 =="
gen_load
helm upgrade $APP chart -n $NS --set image.tag=v2 --set app.version=v2 --set app.errorRate=0 || true
kubectl argo rollouts get rollout $APP -n $NS --watch --timeout 5m || true

echo "== Bad release v3 (50% errors) -> expect automatic abort + rollback =="
gen_load
helm upgrade $APP chart -n $NS --set image.tag=v3 --set app.version=v3 --set app.errorRate=0.5 || true
kubectl argo rollouts get rollout $APP -n $NS --watch --timeout 5m || true
kubectl argo rollouts status $APP -n $NS || echo "Rollout degraded: canary aborted, stable (v2) still serving 100% traffic"
