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
assert 'kind: PersistentVolumeClaim'                           "PVC rendered"
assert 'kind: Ingress'                                         "Ingress rendered"
assert 'name: HAPPY_INJECT_HTML_CONFIG'                        "runtime config injection env"
assert 'name: HAPPY_STATIC_DIR'                                "static dir env"
assert 'secretKeyRef'                                          "HANDY_MASTER_SECRET from secret"
assert 'cert-manager.io/cluster-issuer: "letsencrypt-prod"'    "TLS issuer"
assert 'storageClassName: "test-sc"'                           "storageClass set"
assert 'kubernetes.io/arch'                                    "arm64 affinity"
assert 'type: Recreate'                                        "Recreate strategy"

# Exact value check (yq decodes the YAML-escaped JSON string)
got="$(yq 'select(.kind=="Deployment").spec.template.spec.containers[0].env[] | select(.name=="HAPPY_INJECT_HTML_CONFIG").value' /tmp/happy-rendered.yaml)"
test "$got" = '{"serverUrl":"https://happy.example.com"}' \
  && echo "ok: serverUrl value" || { echo "FAIL: serverUrl value (got: $got)"; exit 1; }

echo "ALL CHECKS PASSED"
