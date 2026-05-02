#!/bin/bash
set -e

# Called after both arch-specific build jobs have pushed their images.
# Creates multi-arch manifest lists from the per-arch images.

if [ -z "$GITHUB_REPOSITORY" ]; then
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  : "${GITHUB_REPOSITORY:=my-overleaf-repo}"
fi

BASE_IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}/base"
IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}"

: "${GITHUB_REF:=refs/heads/main}"

COMMIT_HASH=$(git rev-parse --short HEAD)
CURRENT_DATE=$(date +'%Y%m%d')
CURRENT_DATE_WITH_HOUR=$(date +'%Y%m%d%H')

CHANNEL=""
if [[ "$GITHUB_REF" == *"main"* ]] || [[ "$GITHUB_REF" == *"master"* ]]; then
  CHANNEL="latest"
elif [[ "$GITHUB_REF" == *"stable"* ]]; then
  CHANNEL="stable"
fi

echo "Merging manifests for commit ${COMMIT_HASH}, channel: ${CHANNEL}"

merge() {
  local TARGET=$1
  echo "Creating multi-arch manifest: ${TARGET}"
  docker buildx imagetools create \
    -t "${TARGET}" \
    "${IMAGE_NAME}:${COMMIT_HASH}-amd64" \
    "${IMAGE_NAME}:${COMMIT_HASH}-arm64"
}

# Always create a commit-hash tagged multi-arch manifest
merge "${IMAGE_NAME}:${COMMIT_HASH}"

if [ "$CHANNEL" == "latest" ]; then
  merge "${IMAGE_NAME}:latest"
  merge "${IMAGE_NAME}:main"
fi

if [ "$CHANNEL" == "stable" ]; then
  merge "${IMAGE_NAME}:stable"
  merge "${IMAGE_NAME}:stable-${CURRENT_DATE}"
  merge "${IMAGE_NAME}:stable-${CURRENT_DATE_WITH_HOUR}"
fi

echo "Done. Multi-arch manifests published."
