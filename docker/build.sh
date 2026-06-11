#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

HAPPY_REPO="${HAPPY_REPO:-https://github.com/sokdak/happy.git}"       # source repo (fork with local customizations)
HAPPY_REF="${HAPPY_REF:-88dbdc0e724f4ae8b75772680b9a6a15032ca9d7}"   # pinned sokdak/happy feature/antigravity SHA (2026-06-11, Fable 5 + xhigh + SDK 0.3.167)
IMAGE="${IMAGE:-docker.io/sokdak/happy}"
TAG="${TAG:?set TAG, e.g. TAG=2026.06.02}"
PLATFORM="${PLATFORM:-linux/arm64}"
PUSH="${PUSH:-false}"                        # set PUSH=true to push (requires `docker login`)

args=(--platform "$PLATFORM" --build-arg HAPPY_REPO="$HAPPY_REPO" --build-arg HAPPY_REF="$HAPPY_REF"
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest")
if [ "$PUSH" = "true" ]; then args+=(--push); else args+=(--load); fi

docker buildx build "${args[@]}" "$HERE"
