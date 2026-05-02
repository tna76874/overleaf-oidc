#!/bin/bash
set -e

# Configuration
UPSTREAM_COMMIT_SHA="4271744bfd086fc0daa55213a86b394bac1298c8"

# Set variables / fallback for local execution
if [ -z "$GITHUB_REPOSITORY" ]; then
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  : "${GITHUB_REPOSITORY:=my-overleaf-repo}"
fi

BASE_IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}/base"
IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}"

: "${GITHUB_REF:=refs/heads/$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")}"
: "${PLATFORM:=linux/amd64}"
: "${ARCH_TAG:=$(echo "$PLATFORM" | cut -d'/' -f2)}"

COMMIT_HASH=$(git rev-parse --short HEAD)

echo "IMAGE_NAME:  ${IMAGE_NAME}"
echo "PLATFORM:    ${PLATFORM}"
echo "ARCH_TAG:    ${ARCH_TAG}"

echo "--- Preparing: Clone & patch Overleaf upstream ---"
rm -rf upstream
git clone https://github.com/overleaf/overleaf.git --depth 1 upstream
cd upstream
git fetch --depth 1 origin "${UPSTREAM_COMMIT_SHA}"
git checkout "${UPSTREAM_COMMIT_SHA}"

if ls ../*.patch >/dev/null 2>&1; then
    echo "Applying patches..."
    git apply ../*.patch
else
    echo "No patches found."
fi
cd ..

if [ "$CI" == "true" ]; then
  # --- CI: build each arch separately, push with arch-specific tag ---
  echo "--- CI Build: Base image (${PLATFORM}) ---"
  docker buildx build \
    --platform "${PLATFORM}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from "type=registry,ref=${BASE_IMAGE_NAME}:cache-${ARCH_TAG}" \
    --cache-to   "type=registry,ref=${BASE_IMAGE_NAME}:cache-${ARCH_TAG},mode=max" \
    -t "${BASE_IMAGE_NAME}:${COMMIT_HASH}-${ARCH_TAG}" \
    -f upstream/server-ce/Dockerfile-base \
    --push \
    upstream/

  echo "--- CI Build: Final image (${PLATFORM}) ---"
  docker buildx build \
    --platform "${PLATFORM}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg OVERLEAF_BASE_TAG="${BASE_IMAGE_NAME}:${COMMIT_HASH}-${ARCH_TAG}" \
    --build-arg MONOREPO_REVISION="${COMMIT_HASH}" \
    --cache-from "type=registry,ref=${IMAGE_NAME}:cache-${ARCH_TAG}" \
    --cache-to   "type=registry,ref=${IMAGE_NAME}:cache-${ARCH_TAG},mode=max" \
    -t "${IMAGE_NAME}:${COMMIT_HASH}-${ARCH_TAG}" \
    -f upstream/server-ce/Dockerfile \
    --push \
    upstream/

  echo "Done: pushed ${IMAGE_NAME}:${COMMIT_HASH}-${ARCH_TAG}"
else
  # --- Local: single-arch build, load into local Docker ---
  echo "--- Local Build: Base image ---"
  docker build \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    -t "${BASE_IMAGE_NAME}:${COMMIT_HASH}" \
    -f upstream/server-ce/Dockerfile-base \
    upstream/

  echo "--- Local Build: Final image ---"
  docker build \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg OVERLEAF_BASE_TAG="${BASE_IMAGE_NAME}:${COMMIT_HASH}" \
    --build-arg MONOREPO_REVISION="${COMMIT_HASH}" \
    -t "${IMAGE_NAME}:${COMMIT_HASH}" \
    -f upstream/server-ce/Dockerfile \
    upstream/

  echo "Local build complete: ${IMAGE_NAME}:${COMMIT_HASH}"
fi
