#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== helm lint =="
helm lint .

echo "== helm template (render to /tmp/happy-rendered.yaml) =="
helm template happy . -f ci/test-values.yaml >| /tmp/happy-rendered.yaml

echo "== structural assertions =="
assert() { grep -q "$1" /tmp/happy-rendered.yaml && echo "ok: $2" || { echo "FAIL: $2"; exit 1; }; }
assert 'kind: Deployment'                                      "Deployment rendered"
assert 'kind: Service'                                         "Service rendered"
assert 'kind: StatefulSet'                                     "Postgres StatefulSet rendered"
assert 'kind: Ingress'                                         "Ingress rendered"
assert 'postgres:16-alpine'                                    "Postgres image"
assert 'name: DB_PROVIDER'                                     "DB_PROVIDER env"
assert 'value: "postgres"'                                     "provider = postgres"
assert 'name: DATABASE_URL'                                    "DATABASE_URL env"
assert 'prisma migrate deploy'                                 "runs prisma migrate deploy"
assert 'name: HAPPY_INJECT_HTML_CONFIG'                        "runtime config injection env"
assert 'name: HAPPY_STATIC_DIR'                                "static dir env"
assert 'secretKeyRef'                                          "secrets via secretKeyRef"
assert 'cert-manager.io/cluster-issuer: "letsencrypt-prod"'    "TLS issuer"
assert 'storageClassName: "test-sc"'                           "postgres storageClass"
assert 'kubernetes.io/arch'                                    "arm64 affinity"
assert 'type: Recreate'                                        "Recreate strategy"
assert 'wait-for-postgres'                                     "init container waits for DB"

# Must NOT use embedded PGlite anymore
if grep -q 'PGLITE_DIR\|standalone.ts migrate' /tmp/happy-rendered.yaml; then
  echo "FAIL: still references PGlite"; exit 1
else
  echo "ok: no PGlite references"
fi

# Exact value check (yq decodes the YAML-escaped JSON string)
got="$(yq 'select(.kind=="Deployment").spec.template.spec.containers[0].env[] | select(.name=="HAPPY_INJECT_HTML_CONFIG").value' /tmp/happy-rendered.yaml)"
test "$got" = '{"serverUrl":"https://happy.example.com"}' \
  && echo "ok: serverUrl value" || { echo "FAIL: serverUrl value (got: $got)"; exit 1; }

echo "ALL CHECKS PASSED"
