#!/usr/bin/env bash
# =============================================================================
# teardown.sh – Remove everything from the cluster
# =============================================================================
set -euo pipefail

echo "WARNING: This will delete all NexShop resources."
read -p "Are you sure? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

kubectl delete namespace nexshop   --ignore-not-found
kubectl delete -f ../k8s/monitoring/tempo.yaml --ignore-not-found

echo "Done. PersistentVolumes may need manual cleanup:"
kubectl get pv
