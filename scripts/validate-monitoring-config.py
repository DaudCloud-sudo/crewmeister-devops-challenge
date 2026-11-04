#!/usr/bin/env python3
"""Validate checked-in monitoring YAML, embedded Prometheus config and Grafana dashboard JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
MONITORING = ROOT / "monitoring"


def load_documents(path: Path) -> list[dict[str, Any]]:
    docs = [item for item in yaml.safe_load_all(path.read_text()) if item]
    if not docs:
        raise ValueError(f"{path.relative_to(ROOT)} has no YAML documents")
    return docs


def named(docs: list[dict[str, Any]], resource_name: str) -> dict[str, Any]:
    for doc in docs:
        if doc.get("metadata", {}).get("name") == resource_name:
            return doc
    raise ValueError(f"Kubernetes resource {resource_name!r} is missing")


def main() -> None:
    prometheus_docs = load_documents(MONITORING / "prometheus.yaml")
    grafana_docs = load_documents(MONITORING / "grafana.yaml")
    exporter_docs = load_documents(MONITORING / "mysql-exporter.yaml")

    prommap = named(prometheus_docs, "prometheus-config")
    prom_config = yaml.safe_load(prommap["data"]["prometheus.yml"])
    jobs = {job["job_name"]: job for job in prom_config["scrape_configs"]}
    app_job = jobs["crewmeister-app"]
    if app_job.get("metrics_path") != "/actuator/prometheus":
        raise ValueError("Crewmeister scrape path must be /actuator/prometheus")
    if "crewmeister-app.default.svc.cluster.local:8080" not in app_job["static_configs"][0]["targets"]:
        raise ValueError("Crewmeister Service DNS target is missing")
    exporter_job = jobs["mysql-exporter"]
    if "mysql-exporter.monitoring.svc.cluster.local:9104" not in exporter_job["static_configs"][0]["targets"]:
        raise ValueError("MySQL exporter Service DNS target is missing")
    if exporter_job.get("metrics_path", "/metrics") != "/metrics":
        raise ValueError("MySQL exporter scrape path must be /metrics")

    exporter = named(exporter_docs, "mysql-exporter")
    container = exporter["spec"]["template"]["spec"]["containers"][0]
    password_ref = next((env for env in container.get("env", []) if env["name"] == "MYSQLD_EXPORTER_PASSWORD"), None)
    if not password_ref or password_ref.get("valueFrom", {}).get("secretKeyRef", {}).get("name") != "mysql-exporter-auth":
        raise ValueError("MySQL exporter password must come from the mysql-exporter-auth Secret")

    dashboard_map = named(grafana_docs, "crewmeister-dashboard")
    dashboard = json.loads(dashboard_map["data"]["crewmeister-app.json"])
    panels = dashboard.get("panels", [])
    panel_ids = [panel["id"] for panel in panels]
    if len(panel_ids) != len(set(panel_ids)):
        raise ValueError("Grafana panel IDs must be unique")
    queries = [
        target.get("expr")
        for panel in panels
        for target in panel.get("targets", [])
    ]
    if not queries or any(not isinstance(query, str) or not query.strip() for query in queries):
        raise ValueError("Every Grafana target must contain a PromQL expression")
    if dashboard.get("uid") != "crewmeister-app":
        raise ValueError("Unexpected Crewmeister dashboard UID")
    expressions = set(queries)
    required_mysql_metrics = {
        'mysql_up{job="mysql-exporter"}',
        'mysql_global_status_uptime{job="mysql-exporter"}',
        'mysql_global_status_threads_connected{job="mysql-exporter"}',
        'mysql_global_variables_max_connections{job="mysql-exporter"}',
    }
    if not required_mysql_metrics.issubset(expressions):
        raise ValueError("Dashboard is missing one or more verified MySQL server queries")
    titles = {panel.get("title") for panel in panels}
    if "MySQL server availability" not in titles or "MySQL queries per second" not in titles:
        raise ValueError("Dashboard is missing required MySQL panels")

    print(
        "Monitoring configuration is valid: "
        f"{len(prometheus_docs)} Prometheus resources, "
        f"{len(grafana_docs)} Grafana resources, "
        f"{len(exporter_docs)} MySQL exporter resources, "
        f"{len(panels)} dashboard panels, {len(queries)} PromQL expressions."
    )


if __name__ == "__main__":
    main()
