#!/bin/bash

# Konfiguration
UPSTREAM_COMMIT_SHA="4271744bfd086fc0daa55213a86b394bac1298c8"

# Variablen setzen / Fallback für lokale Ausführung
if [ -z "$GITHUB_REPOSITORY" ]; then
  # Versuche den Namen aus der git remote URL zu extrahieren (z.B. user/repo)
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  
  # Falls das auch fehlschlägt, nutze einen Platzhalter
  : "${GITHUB_REPOSITORY:=my-overleaf-repo}"
fi

BASE_IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}/base"
IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}"

: "${GITHUB_REF:=refs/heads/$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")}"

COMMIT_HASH=$(git rev-parse --short HEAD)
CURRENT_DATE=$(date +'%Y%m%d')
CURRENT_DATE_WITH_HOUR=$(date +'%Y%m%d%H')

# Kanal festlegen
CHANNEL=""
if [[ "$GITHUB_REF" == *"main"* ]] || [[ "$GITHUB_REF" == *"master"* ]]; then
  CHANNEL="latest"
elif [[ "$GITHUB_REF" == *"stable"* ]]; then
  CHANNEL="stable"
fi

echo "IMAGE_NAME: ${IMAGE_NAME}"
echo "CHANNEL: ${CHANNEL}"

echo "--- Vorbereitung: Overleaf Upstream klonen & patchen ---"
rm -rf upstream
git clone https://github.com/overleaf/overleaf.git --depth 1 upstream
cd upstream
# Holen des spezifischen Commits
git fetch --depth 1 origin "${UPSTREAM_COMMIT_SHA}"
git checkout "${UPSTREAM_COMMIT_SHA}"

# Patches anwenden
if ls ../*.patch >/dev/null 2>&1; then
    echo "Wende Patches an..."
    git apply ../*.patch
else
    echo "Keine Patches gefunden."
fi
cd ..

echo "--- Build: Docker Base Image ---"
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t "${BASE_IMAGE_NAME}:${COMMIT_HASH}" \
  -f upstream/server-ce/Dockerfile-base \
  upstream/

echo "--- Build: Docker Final Image ---"
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg OVERLEAF_BASE_TAG="${BASE_IMAGE_NAME}:${COMMIT_HASH}" \
  --build-arg MONOREPO_REVISION="${COMMIT_HASH}" \
  -t "${IMAGE_NAME}:${COMMIT_HASH}" \
  -f upstream/server-ce/Dockerfile \
  upstream/

# Hilfsfunktion
tag_and_push() {
  local TAG=$1
  echo "Tagging & Pushing: ${TAG}"
  docker tag "${IMAGE_NAME}:${COMMIT_HASH}" "${IMAGE_NAME}:${TAG}"
  
  if [ "$CI" == "true" ]; then
    docker push "${IMAGE_NAME}:${TAG}"
  fi
}

echo "--- Tagging & Distribution ---"
if [ "$CI" == "true" ]; then
  docker push "${IMAGE_NAME}:${COMMIT_HASH}"
fi

if [ "$CHANNEL" == "latest" ]; then
  tag_and_push "latest"
  tag_and_push "main"
fi

if [ "$CHANNEL" == "stable" ]; then
  tag_and_push "stable"
  tag_and_push "stable-${CURRENT_DATE}"
  tag_and_push "stable-${CURRENT_DATE_WITH_HOUR}"
fi

if [ "$CI" != "true" ]; then
  echo "Lokale Ausführung beendet. Images wurden lokal unter ${IMAGE_NAME}:${COMMIT_HASH} gespeichert."
fi