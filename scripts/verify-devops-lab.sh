#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
context="kind-devops-lab"
namespace="default"
cluster="devops-lab"
node_container="${cluster}-control-plane"
local_port="18080"
request_timeout="10s"
port_forward_pid=""
port_forward_log=""
health_body=""
health_http_code=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

fetch_health() {
  local response
  response="$(curl --silent --show-error --max-time 3 --write-out $'\n%{http_code}' \
    "$health_url" 2>/dev/null)" || return 1
  health_body="${response%$'\n'*}"
  health_http_code="${response##*$'\n'}"
  [[ "$health_http_code" == "200" ]] \
    && grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"' <<<"$health_body"
}

cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" 2>/dev/null || true
    wait "$port_forward_pid" 2>/dev/null || true
  fi
  if [[ -n "$port_forward_log" ]]; then
    rm -f -- "$port_forward_log"
  fi
}
trap cleanup EXIT

for command_name in podman kind kubectl helm curl timeout; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

timeout 10s podman info >/dev/null || fail "Rootless Podman is unavailable in this user session."
echo "OK: Podman responds."

clusters="$(timeout 10s env KIND_EXPERIMENTAL_PROVIDER=podman kind get clusters)" \
  || fail "Could not list kind clusters using the Podman provider."
grep -Fxq "$cluster" <<<"$clusters" || fail "kind cluster '$cluster' was not found."
echo "OK: kind cluster '$cluster' exists."

timeout 10s kubectl config get-contexts -o name | grep -Fxq "$context" \
  || fail "kubectl context '$context' was not found."
timeout 10s podman container exists "$node_container" \
  || fail "Existing kind node container '$node_container' was not found."

# This project helper only starts the existing node container and waits for
# Kubernetes readiness; it does not create, delete, or reset cluster resources.
timeout 200s "$script_dir/start-devops-lab.sh" \
  || fail "The existing devops-lab cluster did not become ready."

kubectl --context "$context" --request-timeout="$request_timeout" \
  wait --for=condition=Ready nodes --all --timeout=30s \
  || fail "A devops-lab node is not Ready."

for deployment in crewmeister-app mysql; do
  kubectl --context "$context" -n "$namespace" --request-timeout="$request_timeout" \
    rollout status "deployment/$deployment" --timeout=120s \
    || fail "Deployment '$deployment' is not available."
done

kubectl --context "$context" -n "$namespace" --request-timeout="$request_timeout" \
  wait --for=condition=Ready pods -l app=crewmeister-app --timeout=120s \
  || fail "Crewmeister application Pod is not Ready."
kubectl --context "$context" -n "$namespace" --request-timeout="$request_timeout" \
  wait --for=condition=Ready pods -l app=mysql --timeout=120s \
  || fail "MySQL Pod is not Ready."

pvc_phase="$(kubectl --context "$context" -n "$namespace" --request-timeout="$request_timeout" \
  get pvc mysql-data -o jsonpath='{.status.phase}')" \
  || fail "Could not inspect PVC 'mysql-data'."
[[ "$pvc_phase" == "Bound" ]] || fail "PVC 'mysql-data' is '$pvc_phase', expected Bound."
echo "OK: MySQL PVC is Bound."

for service in crewmeister-app mysql; do
  addresses="$(kubectl --context "$context" -n "$namespace" --request-timeout="$request_timeout" \
    get endpoints "$service" -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{" "}{end}')" \
    || fail "Could not inspect endpoints for Service '$service'."
  [[ -n "${addresses// /}" ]] || fail "Service '$service' has no ready endpoints."
  echo "OK: Service '$service' has ready endpoint(s)."
done

helm_status="$(timeout 20s helm --kube-context "$context" -n "$namespace" status crewmeister)" \
  || fail "Helm release 'crewmeister' could not be read."
grep -Eq '^STATUS:[[:space:]]+deployed$' <<<"$helm_status" \
  || fail "Helm release 'crewmeister' is not deployed."
echo "OK: Helm release 'crewmeister' is deployed."

health_url="http://127.0.0.1:${local_port}/actuator/health"
if ! fetch_health; then
  port_forward_log="$(mktemp)"
  kubectl --context "$context" -n "$namespace" \
    port-forward --address 127.0.0.1 "service/crewmeister-app" "${local_port}:8080" \
    >"$port_forward_log" 2>&1 &
  port_forward_pid=$!

  for _ in {1..30}; do
    if fetch_health; then
      break
    fi
    if ! kill -0 "$port_forward_pid" 2>/dev/null; then
      fail "Port-forward exited before health responded; check whether localhost:${local_port} is already in use."
    fi
    sleep 1
  done
fi

[[ "$health_http_code" == "200" ]] \
  || fail "Actuator health did not return HTTP 200 at $health_url."
grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"' <<<"$health_body" \
  || fail "Actuator health did not report UP at $health_url."
echo "OK: Actuator health returned HTTP 200 and reports UP."
echo "PASS: devops-lab workloads, Services, PVC, Helm release, and application health are verified."
