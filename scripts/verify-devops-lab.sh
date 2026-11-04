#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
context="kind-devops-lab"
namespace="default"
cluster="devops-lab"
node_container="${cluster}-control-plane"
local_port="18080"
prometheus_port="19090"
grafana_port="13000"
exporter_port="19104"
request_timeout="10s"
port_forward_pids=()
port_forward_logs=()
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

fetch_http() {
  local url="$1"
  local response
  response="$(curl --silent --show-error --fail --max-time 3 "$url" 2>/dev/null)" || return 1
  printf '%s' "$response"
}

ensure_forward() {
  local service="$1" local_port="$2" target_port="$3" probe_url="$4"
  local log_file pid

  if fetch_http "$probe_url" >/dev/null; then
    return
  fi

  log_file="$(mktemp)"
  port_forward_logs+=("$log_file")
  kubectl --context "$context" -n monitoring \
    port-forward --address 127.0.0.1 "service/$service" "${local_port}:${target_port}" \
    >"$log_file" 2>&1 &
  pid=$!
  port_forward_pids+=("$pid")

  for _ in {1..30}; do
    if fetch_http "$probe_url" >/dev/null; then
      echo "OK: temporary loopback port-forward for $service is responding on 127.0.0.1:$local_port."
      return
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      fail "Port-forward to $service exited; check whether localhost:$local_port is already in use."
    fi
    sleep 1
  done
  fail "Timed out waiting for $service through localhost:$local_port."
}

cleanup() {
  local pid log_file
  for pid in "${port_forward_pids[@]}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  for log_file in "${port_forward_logs[@]}"; do
    rm -f -- "$log_file"
  done
}
trap cleanup EXIT

for command_name in podman kind kubectl helm curl timeout python3; do
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
kubectl --context "$context" -n monitoring --request-timeout="$request_timeout" \
  rollout status deployment/mysql-exporter --timeout=120s \
  || fail "MySQL exporter Deployment is not available."

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

exporter_endpoints="$(kubectl --context "$context" -n monitoring --request-timeout="$request_timeout" \
  get endpoints mysql-exporter -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{" "}{end}')" \
  || fail "Could not inspect endpoints for Service 'mysql-exporter'."
[[ -n "${exporter_endpoints// /}" ]] || fail "Service 'mysql-exporter' has no ready endpoints."
echo "OK: Service 'mysql-exporter' has ready endpoint(s)."

helm_status="$(timeout 20s helm --kube-context "$context" -n "$namespace" status crewmeister)" \
  || fail "Helm release 'crewmeister' could not be read."
grep -Eq '^STATUS:[[:space:]]+deployed$' <<<"$helm_status" \
  || fail "Helm release 'crewmeister' is not deployed."
echo "OK: Helm release 'crewmeister' is deployed."

health_url="http://127.0.0.1:${local_port}/actuator/health"
if ! fetch_health; then
  port_forward_log="$(mktemp)"
  port_forward_logs+=("$port_forward_log")
  kubectl --context "$context" -n "$namespace" \
    port-forward --address 127.0.0.1 "service/crewmeister-app" "${local_port}:8080" \
    >"$port_forward_log" 2>&1 &
  port_forward_pids+=("$!")

  for _ in {1..30}; do
    if fetch_health; then
      break
    fi
    if ! kill -0 "${port_forward_pids[-1]}" 2>/dev/null; then
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

prometheus_url="http://127.0.0.1:${prometheus_port}"
ensure_forward prometheus "$prometheus_port" 9090 "$prometheus_url/api/v1/targets"
prometheus_targets="$(fetch_http "$prometheus_url/api/v1/targets?state=active")" \
  || fail "Prometheus targets API did not respond."
python3 -c 'import json,sys; d=json.load(sys.stdin); t=[x for x in d["data"]["activeTargets"] if x["labels"].get("job")=="crewmeister-app"]; print("OK: Prometheus app targets="+str(len(t))+", health="+(",".join(x["health"] for x in t) if t else "missing")); sys.exit(0 if t and all(x["health"]=="up" for x in t) else 1)' <<<"$prometheus_targets" \
  || fail "Prometheus does not have an UP crewmeister-app target."
python3 -c 'import json,sys; d=json.load(sys.stdin); t=[x for x in d["data"]["activeTargets"] if x["labels"].get("job")=="mysql-exporter"]; print("OK: Prometheus MySQL targets="+str(len(t))+", health="+(",".join(x["health"] for x in t) if t else "missing")); sys.exit(0 if t and all(x["health"]=="up" for x in t) else 1)' <<<"$prometheus_targets" \
  || fail "Prometheus does not have an UP mysql-exporter target."
uptime_metric="$(curl --silent --show-error --fail --max-time 5 --get \
  --data-urlencode 'query=process_uptime_seconds{job="crewmeister-app"}' \
  "$prometheus_url/api/v1/query")" || fail "Could not query the app uptime metric in Prometheus."
python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("data",{}).get("result",[]); print("OK: Prometheus has "+str(len(r))+" Crewmeister uptime metric series."); sys.exit(0 if r else 1)' <<<"$uptime_metric" \
  || fail "Prometheus has no Crewmeister uptime metric sample."
mysql_up_metric="$(curl --silent --show-error --fail --max-time 5 --get \
  --data-urlencode 'query=mysql_up{job="mysql-exporter"}' \
  "$prometheus_url/api/v1/query")" || fail "Could not query MySQL exporter status in Prometheus."
python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("data",{}).get("result",[]); values=[float(x["value"][1]) for x in r]; print("OK: Prometheus mysql_up="+(",".join(map(str,values)) if values else "missing")); sys.exit(0 if values and all(v==1 for v in values) else 1)' <<<"$mysql_up_metric" \
  || fail "MySQL exporter is not reporting mysql_up=1."

exporter_url="http://127.0.0.1:${exporter_port}"
ensure_forward mysql-exporter "$exporter_port" 9104 "$exporter_url/metrics"
exporter_metrics="$(curl --silent --show-error --fail --max-time 5 "$exporter_url/metrics")" \
  || fail "MySQL exporter metrics endpoint did not respond."
grep -Eq '^mysql_up[[:space:]]+1([.]0+)?$' <<<"$exporter_metrics" \
  || fail "MySQL exporter endpoint did not report mysql_up 1."
echo "OK: MySQL exporter endpoint returns mysql_up 1."

grafana_url="http://127.0.0.1:${grafana_port}"
ensure_forward grafana "$grafana_port" 3000 "$grafana_url/api/health"
grafana_health="$(fetch_http "$grafana_url/api/health")" || fail "Grafana health API did not respond."
grep -Eq '"database"[[:space:]]*:[[:space:]]*"ok"' <<<"$grafana_health" \
  || fail "Grafana database health is not OK."
echo "OK: Grafana health API reports a healthy database."
datasource_health="$(fetch_http "$grafana_url/api/datasources/uid/prometheus/health")" \
  || fail "Grafana cannot query its Prometheus datasource."
grep -Eq '"status"[[:space:]]*:[[:space:]]*"OK"' <<<"$datasource_health" \
  || fail "Grafana Prometheus datasource is not healthy."
echo "OK: Grafana can query the Prometheus datasource."
dashboard="$(fetch_http "$grafana_url/api/dashboards/uid/crewmeister-app")" \
  || fail "Crewmeister dashboard is not provisioned in Grafana."
python3 -c 'import json,sys; d=json.load(sys.stdin)["dashboard"]; p=d.get("panels",[]); titles={x.get("title") for x in p}; required={"MySQL server availability","MySQL queries per second"}; print("OK: Grafana dashboard="+d["title"]+", panels="+str(len(p))); sys.exit(0 if d.get("uid")=="crewmeister-app" and required<=titles else 1)' <<<"$dashboard" \
  || fail "Grafana Crewmeister dashboard is missing or has no panels."

grafana_query="$(curl --silent --show-error --fail --max-time 10 --request POST \
  --header 'Content-Type: application/json' \
  --data-binary '{"queries":[{"refId":"A","datasource":{"type":"prometheus","uid":"prometheus"},"expr":"mysql_global_status_uptime{job=\"mysql-exporter\"}","instant":true,"range":false}],"from":"now-5m","to":"now"}' \
  "$grafana_url/api/ds/query")" || fail "Grafana could not execute the MySQL dashboard query."
python3 -c 'import json,sys; d=json.load(sys.stdin); results=d.get("results",{}).values(); frames=[f for r in results for f in r.get("frames",[])]; values=[v for f in frames for col in f.get("data",{}).get("values",[]) for v in col if v is not None]; print("OK: Grafana MySQL query returned "+str(len(values))+" value(s)."); sys.exit(0 if values else 1)' <<<"$grafana_query" \
  || fail "Grafana MySQL dashboard query returned no data."

echo "PASS: devops-lab workloads, Services, PVC, Helm release, app health, app and MySQL Prometheus scraping, and Grafana MySQL dashboard data are verified."
