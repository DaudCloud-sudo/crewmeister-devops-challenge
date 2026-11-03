#!/usr/bin/env bash
set -euo pipefail

CLUSTER="devops-lab"
NODE_CONTAINER="${CLUSTER}-control-plane"
KUBE_CONTEXT="kind-${CLUSTER}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting existing kind cluster: ${CLUSTER}"

if ! podman container exists "${NODE_CONTAINER}"; then
  log "ERROR: Podman container ${NODE_CONTAINER} does not exist."
  log "The cluster may need recovery or recreation."
  exit 1
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "${NODE_CONTAINER}")" != "true" ]]; then
  podman start "${NODE_CONTAINER}"
else
  log "Node container is already running."
fi

log "Waiting for Kubernetes node to become Ready..."

for attempt in $(seq 1 60); do
  if kubectl --context "${KUBE_CONTEXT}" get nodes \
      --no-headers 2>/dev/null | grep -q ' Ready '; then
    break
  fi

  if [[ "${attempt}" -eq 60 ]]; then
    log "ERROR: Kubernetes node did not become Ready within 5 minutes."
    kubectl --context "${KUBE_CONTEXT}" get nodes || true
    exit 1
  fi

  sleep 5
done

log "Kubernetes node status:"
kubectl --context "${KUBE_CONTEXT}" get nodes

log "Crewmeister workloads:"
kubectl --context "${KUBE_CONTEXT}" get pods

log "Helm releases:"
helm --kube-context "${KUBE_CONTEXT}" list --all-namespaces

log "Startup checks completed."
