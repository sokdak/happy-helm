# happy-helm

Helm chart to self-host [`slopus/happy`](https://github.com/slopus/happy) on Kubernetes — control your machine's **Claude Code** and **Codex** sessions from a web UI (incl. phone).

One arm64 image runs in two roles on **two origins**: **api** (the `happy-server` relay — `GET /` returns the API welcome so native/App-Store apps can register it as a custom server) and **fe** (the Expo **web UI**, pointed at the api origin). Backed by **PostgreSQL** (bundled). End-to-end encrypted; the CLI dials out to the relay. (The server also has an embedded-PGlite mode, but it has Prisma `Bytes`/enum bugs that break machine/session listing — use Postgres.)

## Build & push the image

```bash
TAG=$(date +%Y.%m.%d) PUSH=true ./docker/build.sh   # requires `docker login` to Docker Hub
```

Builds `linux/arm64` and pushes `docker.io/sokdak/happy:<TAG>` + `:latest`. Pin the upstream happy version via `HAPPY_REF` (see `docker/Dockerfile`). Omit `PUSH=true` (or set `PUSH=false`) to build and `--load` locally for testing.

## One-time secrets (GitOps-safe)

Create these once, out of band; never commit them.

```bash
kubectl create namespace happy

# Master secret (signs auth tokens)
kubectl -n happy create secret generic happy-secrets \
  --from-literal=HANDY_MASTER_SECRET=$(openssl rand -hex 32)

# Postgres credentials (URL-safe password) + connection URL
PW=$(openssl rand -hex 24)
kubectl -n happy create secret generic happy-postgres \
  --from-literal=password="$PW" \
  --from-literal=database-url="postgresql://happy:${PW}@happy-postgres:5432/happy?schema=public"
```

## Install

```bash
helm upgrade --install happy . -n happy --create-namespace \
  --set image.tag=<TAG>
```

Key values (see `values.yaml`): `image.tag`, `api.host`, `fe.host` (+ optional `fe.serverUrl`), `ingress.clusterIssuer`, `ingress.whitelistSourceRange`, `postgres.enabled`/`storageClass`/`size`, `database.existingSecret`, `masterSecret.existingSecret`.

An example ArgoCD Application for GitOps deployment is in `examples/argocd-application.yaml`.

## Use it from your computer

```bash
npm install -g happy
export HAPPY_SERVER_URL="https://api.happy.example.com"   # api origin (relay)
export HAPPY_WEBAPP_URL="https://happy.example.com"       # fe origin (web UI); needed for web-browser auth
happy auth login    # → Web Browser → approve in the browser (init the account there first)
happy claude        # or: happy codex
happy daemon start  # keep the machine online so it appears in the UI machine list
```

First run: open the UI (the `fe` host), create the account (master secret stays in the browser), then `happy auth login` → approve. Then drive Claude/Codex from your phone; press any key on the computer to take control back.

## Security

The relay allows open account registration (data stays end-to-end encrypted and per-key isolated). Keep it behind your network perimeter, or set `ingress.whitelistSourceRange` to an allowed CIDR.
