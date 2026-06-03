#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== helm lint =="
helm lint .

echo "== helm template (render to /tmp/happy-rendered.yaml) =="
helm template happy . -f ci/test-values.yaml >| /tmp/happy-rendered.yaml

echo "== structural assertions =="
assert() { grep -q "$1" /tmp/happy-rendered.yaml && echo "ok: $2" || { echo "FAIL: $2"; exit 1; }; }
assert 'kind: StatefulSet'                                     "Postgres StatefulSet rendered"
assert 'postgres:16-alpine'                                    "Postgres image"
assert 'name: DB_PROVIDER'                                     "DB_PROVIDER env"
assert 'value: "postgres"'                                     "provider = postgres"
assert 'name: DATABASE_URL'                                    "DATABASE_URL env"
assert 'prisma migrate deploy'                                 "runs prisma migrate deploy"
assert 'wait-for-postgres'                                     "init container waits for DB"
assert 'host: "api.happy.example.com"'                         "api ingress host"
assert 'host: "happy.example.com"'                             "fe ingress host"
assert 'rm -rf /app/webapp'                                    "api strips web UI (serves API root)"
assert 'name: HAPPY_INJECT_HTML_CONFIG'                        "fe injects runtime config"
assert 'secretKeyRef'                                          "secrets via secretKeyRef"
assert 'cert-manager.io/cluster-issuer: "letsencrypt-prod"'    "TLS issuer"
assert 'storageClassName: "test-sc"'                           "postgres storageClass"
assert 'kubernetes.io/arch'                                    "arm64 affinity"
assert 'type: Recreate'                                        "Recreate strategy"

# Exactly two app Deployments (api + fe) and two Ingresses (split origins)
test "$(grep -c 'kind: Deployment' /tmp/happy-rendered.yaml)" = "2" \
  && echo "ok: 2 Deployments (api + fe)" || { echo "FAIL: expected 2 Deployments"; exit 1; }
test "$(grep -c 'kind: Ingress' /tmp/happy-rendered.yaml)" = "2" \
  && echo "ok: 2 Ingresses (split origins)" || { echo "FAIL: expected 2 Ingresses"; exit 1; }

# Must NOT use embedded PGlite
if grep -q 'PGLITE_DIR\|standalone.ts migrate' /tmp/happy-rendered.yaml; then
  echo "FAIL: still references PGlite"; exit 1
else
  echo "ok: no PGlite references"
fi

# fe injects the API origin as the server URL (yq decodes the YAML-escaped JSON)
got="$(yq 'select(.kind=="Deployment").spec.template.spec.containers[0].env[] | select(.name=="HAPPY_INJECT_HTML_CONFIG").value' /tmp/happy-rendered.yaml)"
test "$got" = '{"serverUrl":"https://api.happy.example.com"}' \
  && echo "ok: fe serverUrl -> api origin" || { echo "FAIL: serverUrl value (got: $got)"; exit 1; }

echo "ALL CHECKS PASSED"
