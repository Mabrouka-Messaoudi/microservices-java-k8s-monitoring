#!/usr/bin/env bash
# =============================================================================
# build-push.sh – Build and push all NexShop microservice Docker images
# Usage: DOCKER_USERNAME=yourusername bash scripts/build-push.sh
# =============================================================================
set -euo pipefail

: "${DOCKER_USERNAME:?Please export DOCKER_USERNAME=your-dockerhub-username}"
TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVICES=(
  "product-service"
  "order-service"
  "inventory-service"
  "notification-service"
  "api-gateway"
  "frontend"
)

# Source paths – adjust if your services live elsewhere
declare -A SERVICE_PATHS=(
  ["product-service"]="$ROOT_DIR/services/product-service"
  ["order-service"]="$ROOT_DIR/services/order-service"
  ["inventory-service"]="$ROOT_DIR/services/inventory-service"
  ["notification-service"]="$ROOT_DIR/services/notification-service"
  ["api-gateway"]="$ROOT_DIR/services/api-gateway"
  ["frontend"]="$ROOT_DIR/services/frontend"
)

echo "============================================="
echo " NexShop – Docker Build & Push"
echo " User   : $DOCKER_USERNAME"
echo " Tag    : $TAG"
echo "============================================="

docker login

for svc in "${SERVICES[@]}"; do
  SRC="${SERVICE_PATHS[$svc]}"
  IMAGE="$DOCKER_USERNAME/$svc:$TAG"

  if [ ! -d "$SRC" ]; then
    echo "[SKIP] $svc – source directory not found at $SRC"
    continue
  fi

  # Copy Dockerfile if service doesn't have one yet
  if [ ! -f "$SRC/Dockerfile" ]; then
    echo "[INFO] Copying Dockerfile template to $svc"
    cp "$ROOT_DIR/services/Dockerfile.template" "$SRC/Dockerfile"
  fi

  echo ""
  echo "──────────────────────────────────────────"
  echo " Building  : $IMAGE"
  echo " Source    : $SRC"
  echo "──────────────────────────────────────────"

  docker build \
    --platform linux/amd64 \
    --tag "$IMAGE" \
    "$SRC"

  echo " Pushing   : $IMAGE"
  docker push "$IMAGE"
  echo " ✅ Done   : $IMAGE"
done

echo ""
echo "============================================="
echo " All images pushed successfully!"
echo " Run: DOCKER_USERNAME=$DOCKER_USERNAME bash scripts/deploy.sh"
echo "============================================="
