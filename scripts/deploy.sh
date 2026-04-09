#!/usr/bin/env bash
# =============================================================================
# deploy.sh – Deploy the full NexShop platform to Kubernetes
# Usage: DOCKER_USERNAME=yourusername bash scripts/deploy.sh
# =============================================================================
set -euo pipefail

: "${DOCKER_USERNAME:?Please export DOCKER_USERNAME=your-dockerhub-username}"
TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S="$(cd "$SCRIPT_DIR/../k8s" && pwd)"

echo "============================================="
echo " NexShop – Kubernetes Deployment"
echo " Docker Hub User : $DOCKER_USERNAME"
echo " Image Tag       : $TAG"
echo "============================================="

# ── 0. Label nodes ────────────────────────────────────────────────────────────
echo ""
echo "[1/8] Labelling nodes..."
kubectl label node k8s2-worker2 role=app --overwrite
kubectl label node k8s2-worker3 role=app --overwrite
# ── 1. Namespaces ────────────────────────────────────────────────────────────
echo "[2/8] Creating namespaces..."
kubectl apply -f "$K8S/namespaces/namespaces.yaml"

# ── 2. Secrets & ConfigMap ────────────────────────────────────────────────────
echo "[3/8] Applying secrets and config..."
kubectl apply -f "$K8S/infrastructure/secrets-and-config.yaml"

# ── 3. Infrastructure ─────────────────────────────────────────────────────────
echo "[4/8] Deploying infrastructure (MySQL, MongoDB, Kafka, Keycloak)..."
kubectl apply -f "$K8S/infrastructure/mysql/mysql.yaml"
kubectl apply -f "$K8S/infrastructure/mongodb/mongodb.yaml"
kubectl apply -f "$K8S/infrastructure/kafka/kafka.yaml"
kubectl apply -f "$K8S/infrastructure/keycloak/keycloak.yaml"

echo "  Waiting for MySQL to be ready..."
kubectl rollout status deployment/mysql -n nexshop --timeout=120s

echo "  Waiting for MongoDB to be ready..."
kubectl rollout status deployment/mongodb -n nexshop --timeout=120s

echo "  Waiting for Kafka to be ready..."
kubectl rollout status deployment/kafka -n nexshop --timeout=120s

# ── 4. Monitoring stack ───────────────────────────────────────────────────────
echo "[5/8] Deploying monitoring stack (Tempo)..."
kubectl apply -f "$K8S/monitoring/tempo.yaml"

# ── 5. Patch image names in app manifests then apply ──────────────────────────
echo "[6/8] Deploying microservices..."

SERVICES=(
  "product-service"
  "order-service"
  "inventory-service"
  "notification-service"
  "api-gateway"
  "frontend"
)

for svc in "${SERVICES[@]}"; do
  MANIFEST="$K8S/apps/$svc/$svc.yaml"
  # Replace placeholder with actual Docker Hub username + tag
  sed "s|YOUR_DOCKERHUB_USERNAME/$svc:latest|$DOCKER_USERNAME/$svc:$TAG|g" \
    "$MANIFEST" | kubectl apply -f -
done

# ── 6. Wait for apps ──────────────────────────────────────────────────────────
echo "[7/8] Waiting for microservices to be ready..."
for svc in "${SERVICES[@]}"; do
  echo "  Waiting for $svc..."
  kubectl rollout status deployment/"$svc" -n nexshop --timeout=180s
done

# ── 7. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "[8/8] Deployment complete!"
echo ""
echo "============================================="
echo " Access Points"
echo "============================================="
echo " Frontend     : http://10.10.10.11:30200"
echo " API Gateway  : http://10.10.10.11:30900"
echo " Keycloak     : http://10.10.10.11:30818"
echo " Kafka UI     : http://10.10.10.11:30886"
echo " Grafana      : http://10.10.10.12:30300"
echo "============================================="
echo ""
echo " Pods status:"
kubectl get pods -n nexshop
echo ""
echo " Monitoring pods:"
kubectl get pods -n monitoring
