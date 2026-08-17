#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

HAPPY_REPO="${HAPPY_REPO:-https://github.com/sokdak/happy.git}"       # source repo (fork with local customizations)
HAPPY_REF="${HAPPY_REF:-bf304e5fcfe2d812d3d74b4aade43eadc492f612}"   # pinned sokdak/happy feature/antigravity-vnext SHA (2026-07-11, antigravity Claude refresh + agy backend + GPT-5.6 picker)
IMAGE="${IMAGE:-ghcr.io/sokdak/happy}"
TAG="${TAG:?set TAG, e.g. TAG=2026.06.02}"
PLATFORM="${PLATFORM:-linux/arm64}"
PUSH="${PUSH:-false}"                        # set PUSH=true to push (requires `docker login`)

args=(--platform "$PLATFORM" --build-arg HAPPY_REPO="$HAPPY_REPO" --build-arg HAPPY_REF="$HAPPY_REF"
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest")
if [ "$PUSH" = "true" ]; then args+=(--push); else args+=(--load); fi

docker buildx build "${args[@]}" "$HERE"
