#!/usr/bin/env bash
# =============================================================================
# teardown.sh – Supprime les ressources NexShop du cluster
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S="$(cd "$SCRIPT_DIR/../k8s" && pwd)"

echo "ATTENTION : toutes les ressources NexShop vont être supprimées."
read -p "Confirmer ? (yes/no) : " confirm
[[ "$confirm" == "yes" ]] || { echo "Annulé."; exit 0; }

kubectl delete namespace nexshop --ignore-not-found
kubectl delete -f "$K8S/monitoring/tempo.yaml" --ignore-not-found

echo "Terminé. Les PersistentVolumes peuvent nécessiter un nettoyage manuel :"
kubectl get pv
