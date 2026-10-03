#!/usr/bin/env bash
# =============================================================================
# deploy.sh – Déploie la plateforme NexShop complète sur Kubernetes
#
# Variables requises :
#   DOCKER_USERNAME   compte Docker Hub qui héberge les images
#   NODE_IP           IP d'un nœud du cluster (utilisée pour les NodePorts)
#   APP_NODES         nœuds applicatifs, séparés par des espaces (label role=app)
#   MONITORING_NODE   nœud de monitoring (label role=monitoring)
# Variables optionnelles : IMAGE_TAG (défaut : latest)
# Secrets : scripts/secrets.env (voir scripts/secrets.env.example)
#
# Exemple :
#   DOCKER_USERNAME=moncompte NODE_IP=192.168.100.113 \
#   APP_NODES="k8s-worker1 k8s-worker2" MONITORING_NODE=k8s-worker2 \
#   bash scripts/deploy.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S="$ROOT_DIR/k8s"

if [ -f "$SCRIPT_DIR/secrets.env" ]; then
  set -a; source "$SCRIPT_DIR/secrets.env"; set +a
fi

: "${DOCKER_USERNAME:?Définir DOCKER_USERNAME=<compte Docker Hub>}"
: "${NODE_IP:?Définir NODE_IP=<IP-d-un-noeud-du-cluster>}"
: "${APP_NODES:?Définir APP_NODES=\"noeud1 noeud2\" (voir : kubectl get nodes)}"
: "${MONITORING_NODE:?Définir MONITORING_NODE=<nom du noeud de monitoring>}"
: "${MAIL_USERNAME:?Définir MAIL_USERNAME dans scripts/secrets.env}"
: "${MAIL_PASSWORD:?Définir MAIL_PASSWORD dans scripts/secrets.env}"
TAG="${IMAGE_TAG:-latest}"

echo "============================================="
echo " NexShop – Déploiement Kubernetes"
echo " Docker Hub     : $DOCKER_USERNAME"
echo " Tag            : $TAG"
echo " Noeuds app     : $APP_NODES"
echo " Noeud monitoring: $MONITORING_NODE"
echo "============================================="

# ── 1. Labels des nœuds ──────────────────────────────────────────────────────
echo "[1/9] Labels des noeuds..."
for node in $APP_NODES; do
  kubectl label node "$node" role=app --overwrite
done
kubectl label node "$MONITORING_NODE" role=monitoring --overwrite

# ── 2. Namespaces ────────────────────────────────────────────────────────────
echo "[2/9] Namespaces..."
kubectl apply -f "$K8S/namespaces/namespaces.yaml"

# ── 3. Secrets et ConfigMap ──────────────────────────────────────────────────
echo "[3/9] Secrets et configuration..."
kubectl apply -f "$K8S/infrastructure/secrets-and-config.yaml"

kubectl create secret generic mail-secret -n nexshop \
  --from-literal=username="$MAIL_USERNAME" \
  --from-literal=password="$MAIL_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Certificat TLS auto-signé pour le frontend (créé une seule fois)
if ! kubectl get secret frontend-tls -n nexshop >/dev/null 2>&1; then
  echo "  Génération du certificat TLS auto-signé (frontend-tls)..."
  TLS_DIR="$(mktemp -d)"
  trap 'rm -rf "$TLS_DIR"' EXIT
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "$TLS_DIR/tls.key" -out "$TLS_DIR/tls.crt" \
    -subj "/CN=nexshop" -addext "subjectAltName=IP:$NODE_IP" 2>/dev/null
  kubectl create secret tls frontend-tls -n nexshop \
    --cert="$TLS_DIR/tls.crt" --key="$TLS_DIR/tls.key"
fi

# ── 4. Infrastructure ────────────────────────────────────────────────────────
echo "[4/9] Infrastructure (MySQL, MongoDB, Kafka, Keycloak)..."
kubectl apply -f "$K8S/infrastructure/mysql/mysql.yaml"
kubectl apply -f "$K8S/infrastructure/mongodb/mongodb.yaml"
kubectl apply -f "$K8S/infrastructure/kafka/kafka.yaml"
kubectl apply -f "$K8S/infrastructure/keycloak/keycloak.yaml"

for dep in mysql mongodb kafka; do
  echo "  Attente de $dep..."
  kubectl rollout status deployment/"$dep" -n nexshop --timeout=120s
done

# ── 5. Monitoring ────────────────────────────────────────────────────────────
echo "[5/9] Monitoring (Tempo)..."
kubectl apply -f "$K8S/monitoring/tempo.yaml"

# ── 6. Configuration nginx du frontend ───────────────────────────────────────
echo "[6/9] Configuration nginx du frontend..."
kubectl apply -f "$ROOT_DIR/services/frontend/configmap.yaml"

# ── 7. Microservices ─────────────────────────────────────────────────────────
echo "[7/9] Microservices..."
SERVICES=(
  "product-service"
  "order-service"
  "inventory-service"
  "notification-service"
  "api-gateway"
  "frontend"
)

for svc in "${SERVICES[@]}"; do
  sed -e "s|YOUR_DOCKERHUB_USERNAME/$svc:latest|$DOCKER_USERNAME/$svc:$TAG|g" \
      -e "s|__NODE_IP__|$NODE_IP|g" \
      "$K8S/apps/$svc/$svc.yaml" | kubectl apply -f -
done

# ── 8. Attente des déploiements ──────────────────────────────────────────────
echo "[8/9] Attente des microservices..."
for svc in "${SERVICES[@]}"; do
  echo "  Attente de $svc..."
  kubectl rollout status deployment/"$svc" -n nexshop --timeout=180s
done

# ── 9. Résumé ────────────────────────────────────────────────────────────────
MON_IP="$(kubectl get node "$MONITORING_NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
echo "[9/9] Déploiement terminé."
echo ""
echo "============================================="
echo " Points d'accès"
echo "============================================="
echo " Frontend     : https://$NODE_IP:30200  (certificat auto-signé)"
echo " API Gateway  : http://$NODE_IP:30900"
echo " Keycloak     : http://$NODE_IP:30818"
echo " Kafka UI     : http://$NODE_IP:30886"
echo " Grafana      : http://$MON_IP:30300"
echo "============================================="
echo ""
kubectl get pods -n nexshop
echo ""
kubectl get pods -n monitoring
