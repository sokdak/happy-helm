#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

HAPPY_REPO="${HAPPY_REPO:-https://github.com/sokdak/happy.git}"       # source repo (fork with local customizations)
HAPPY_REF="${HAPPY_REF:-f28f087802130c886921aa95b379736899e1d92a}"   # pinned sokdak/happy main SHA; the bump automation rewrites only the SHA above, so keep this comment generic
IMAGE="${IMAGE:-ghcr.io/sokdak/happy}"
TAG="${TAG:?set TAG, e.g. TAG=2026.06.02}"
PLATFORM="${PLATFORM:-linux/arm64}"
PUSH="${PUSH:-false}"                        # set PUSH=true to push (requires `docker login`)

args=(--platform "$PLATFORM" --build-arg HAPPY_REPO="$HAPPY_REPO" --build-arg HAPPY_REF="$HAPPY_REF"
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest")
if [ "$PUSH" = "true" ]; then args+=(--push); else args+=(--load); fi

docker buildx build "${args[@]}" "$HERE"
