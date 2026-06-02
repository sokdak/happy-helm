# happy-helm

Helm chart to self-host [`slopus/happy`](https://github.com/slopus/happy) as a **single pod** on Kubernetes — control your machine's **Claude Code** and **Codex** sessions from a web UI (incl. phone).

One arm64 image runs `happy-server` in **standalone mode** (embedded PGlite — no Redis/Postgres/S3) and serves the Expo **web UI** on the same origin. End-to-end encrypted; the CLI dials out to the relay.

## Build & push the image

```bash
TAG=$(date +%Y.%m.%d) PUSH=true ./docker/build.sh   # requires `docker login` to Docker Hub
```

Builds `linux/arm64` and pushes `docker.io/sokdak/happy:<TAG>` + `:latest`. Pin the upstream happy version via `HAPPY_REF` (see `docker/Dockerfile`). Omit `PUSH=true` (or set `PUSH=false`) to build and `--load` locally for testing.

## One-time secret (GitOps-safe)

`HANDY_MASTER_SECRET` signs auth tokens — create it once, out of band; never commit it.

```bash
kubectl create namespace happy
kubectl -n happy create secret generic happy-secrets \
  --from-literal=HANDY_MASTER_SECRET=$(openssl rand -hex 32)
```

## Install

```bash
helm upgrade --install happy . -n happy --create-namespace \
  --set image.tag=<TAG>
```

Key values (see `values.yaml`): `image.tag`, `server.serverUrl`, `ingress.host`, `ingress.clusterIssuer`, `ingress.tlsSecretName`, `ingress.whitelistSourceRange`, `persistence.storageClass`/`size`, `masterSecret.existingSecret`.

An example ArgoCD Application for GitOps deployment is in `examples/argocd-application.yaml`.

## Use it from your computer

```bash
npm install -g happy
export HAPPY_SERVER_URL="https://happy.example.com"
happy claude        # or: happy codex
happy daemon start  # optional: keep the machine available to start sessions remotely
```

First run: open the UI, pair via QR/link (no password). Then drive Claude/Codex from your phone; press any key on the computer to take control back.

## Security

The relay allows open account registration (data stays end-to-end encrypted and per-key isolated). Keep it behind your network perimeter, or set `ingress.whitelistSourceRange` to an allowed CIDR.
