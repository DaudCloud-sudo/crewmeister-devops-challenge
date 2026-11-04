#!/usr/bin/env bash
set -euo pipefail

cluster="devops-lab"
node_container="${cluster}-control-plane"
context="kind-${cluster}"
timeout_seconds=180
interval_seconds=3

if ! podman container exists "$node_container"; then
  echo "Error: kind node container '$node_container' does not exist." >&2
  exit 1
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "$node_container")" != "true" ]]; then
  podman start "$node_container" >/dev/null
fi

echo "Waiting up to ${timeout_seconds}s for a Ready Kubernetes node..."
deadline=$((SECONDS + timeout_seconds))
until kubectl --context "$context" get nodes --no-headers 2>/dev/null | grep -q ' Ready '; do
  if (( SECONDS >= deadline )); then
    echo "Error: Kubernetes node did not become Ready within ${timeout_seconds}s." >&2
    kubectl --context "$context" get nodes || true
    exit 1
  fi
  sleep "$interval_seconds"
done

kubectl --context "$context" get nodes
kubectl --context "$context" get pods
helm --kube-context "$context" list --all-namespaces
