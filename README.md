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

> ⚠️ **Use the fork CLI built together with this image.** The image and the npm package
> [`@sokdak/happy`](https://www.npmjs.com/package/@sokdak/happy) are built from the same
> `sokdak/happy` source commit (`HAPPY_REF`) and must be used together to work correctly —
> the upstream `happy` npm package is **not** compatible with this image's fork-specific
> features (antigravity Claude modes, `agy` backend, permission behavior).

```bash
npm install -g @sokdak/happy
export HAPPY_SERVER_URL="https://api.happy.example.com"   # api origin (relay)
export HAPPY_WEBAPP_URL="https://happy.example.com"       # fe origin (web UI); needed for web-browser auth
happy auth login    # → Web Browser → approve in the browser (init the account there first)
happy claude        # or: happy codex
happy daemon start  # keep the machine online so it appears in the UI machine list
```

First run: open the UI (the `fe` host), create the account (master secret stays in the browser), then `happy auth login` → approve. Then drive Claude/Codex from your phone; press any key on the computer to take control back.

### Run a subset of agents (e.g. Codex-only)

Agent selection happens in the daemon on **your** machine, not in the cluster. This chart
deploys only the relay, the web UI, and Postgres — its image ships no agent CLI — so there
is no chart value for this. Configure it where the daemon runs:

```bash
export HAPPY_ENABLED_AGENTS=codex      # allowlist; or: HAPPY_DISABLED_AGENTS=claude
happy daemon start
```

Both accept a comma- or space-separated list of `claude`, `codex`, `gemini`, `openclaw`,
`agy`. `HAPPY_ENABLED_AGENTS` takes precedence. Neither can make a missing CLI usable —
what is installed still has the final say.

A name outside that list is a configuration error, not a no-op: the daemon reports no
agents at all and refuses to start a session, naming the value it could not read. A typo
used to parse away to an empty policy, which read as "no policy" and re-enabled every
agent found on the machine — the opposite of what was asked for.

The web UI builds its agent picker from what the daemon reports, so a disabled agent
disappears from the picker and the first enabled one becomes the default for new sessions.
A browser still holding an older `agent: "claude"` draft is coerced to an enabled agent
rather than failing. Coercion also drops the parts of that request that belonged to the
agent it named — the OAuth token, model, permission mode and resume id — because none of
them translate: a Claude token is not a Codex credential and `claude-opus-5` is not a
model Codex can run. The session starts from the target agent's own credential and
defaults instead.

This matters when an agent CLI is installed but deliberately **not** authenticated: without
the policy the daemon advertises it as available, and every request fails with
`Failed to authenticate: OAuth session expired and could not be refreshed`. Set the policy
in the same place as `HAPPY_SERVER_URL` above — and prefer a location the daemon inherits on
restart, since a daemon outlives the shell that started it.

Requires a CLI built from a source commit that includes the agent policy
(sokdak/happy#12); older builds ignore both variables. The coercion, typo and precedence
behaviour described above landed later, in sokdak/happy#14.

### Log retention on the daemon host

The daemon writes one log file per process start under `~/.happy/logs`, and for a long
time nothing removed them — a host running the daemon under systemd for three months
accumulated 204k files and 924MB. Builds including sokdak/happy#15 prune on start:

```bash
export HAPPY_LOG_RETENTION_DAYS=14   # default; 0 keeps everything
```

Deletion runs in the background, oldest first, so an existing backlog clears on the next
start. `happy doctor` reports the current file count, total size and retention window.

## Security

The relay allows open account registration (data stays end-to-end encrypted and per-key isolated). Keep it behind your network perimeter, or set `ingress.whitelistSourceRange` to an allowed CIDR.
