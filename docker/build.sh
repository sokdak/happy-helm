#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

HAPPY_REPO="${HAPPY_REPO:-https://github.com/sokdak/happy.git}"       # source repo (fork with local customizations)
HAPPY_REF="${HAPPY_REF:-241c9f0bfbd658255453730d5f390215e0c2cc62}"   # pinned sokdak/happy main SHA (2026-06-05)
IMAGE="${IMAGE:-docker.io/sokdak/happy}"
TAG="${TAG:?set TAG, e.g. TAG=2026.06.02}"
PLATFORM="${PLATFORM:-linux/arm64}"
PUSH="${PUSH:-false}"                        # set PUSH=true to push (requires `docker login`)

args=(--platform "$PLATFORM" --build-arg HAPPY_REPO="$HAPPY_REPO" --build-arg HAPPY_REF="$HAPPY_REF"
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest")
if [ "$PUSH" = "true" ]; then args+=(--push); else args+=(--load); fi

docker buildx build "${args[@]}" "$HERE"
