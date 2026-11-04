# Challenge checklist

Statuses reflect repository configuration and live checks completed on 2026-11-04.

| Requirement | Class | Status | Evidence and remaining work |
|---|---|---|---|
| Dockerfile | Core | Complete | `Dockerfile`; local Podman image `localhost/crewmeister-app:0.2` built and loaded into kind. |
| Helm chart | Core | Complete | `helm/crewmeister/`; live release `crewmeister` deployed in `default`, app/MySQL Pods Ready, `mysql-data` PVC Bound at 2Gi. |
| Terraform interacting with Kubernetes | Core | Partial | `terraform/kind-lab/main.tf` provisions the separate `terraform-lab` kind cluster. It does not manage the Crewmeister Helm release in `devops-lab`. |
| Local Kubernetes with kind | Core | Complete | `kind-devops-lab` node Ready; app/MySQL Pods Ready; `/actuator/health` returned UP and user API POST/SQL/GET round trip succeeded. |
| GitHub Actions CI | Plus | Complete | Workflow run for `6f94da3caf4414785352df81b9b38c127b23e355` completed successfully: [run 41752780282](https://github.com/DaudCloud-Sudo/crewmeister-devops-challenge/actions/runs/41752780282). It runs Maven `verify` with MySQL and uploads the JAR; it does not deploy. |
| Monitoring | Plus | Complete | App and MySQL exporter Prometheus targets are UP; `mysql_up` is 1 and server metric samples are present. Grafana has 21 data panels spanning app, JVM, Hikari pool, MySQL server, and scrape health. |

## Implementation and evidence

- **Application/container:** Java 17, Spring Boot, Maven, MySQL, Flyway; container image is built from the packaged JAR.
- **Canonical deployment:** Helm deploys Crewmeister and MySQL to `devops-lab`. The raw `k8s/` manifests are reference examples, not a second supported deployment path.
- **Infrastructure boundary:** Terraform provisions a separate `terraform-lab` kind cluster. It does not own the application release.
- **Startup helper:** starts the existing kind node container when stopped, waits at most 180 seconds for a Ready Kubernetes node, and reports the cluster state. It never creates or resets a cluster.
- **Credentials:** the database password is expected in a locally provisioned Kubernetes Secret. No password value belongs in the repository.

## Optional work and limitations

- Image publishing and CD are optional; no automated delivery is configured. AWS deployment is design-only and no cloud resources are provisioned.
- Single-node kind has no node-level high availability. A PVC is not a backup.
- Prometheus and Grafana use bounded ephemeral storage and provide no backup or external alerting. A PVC is not a database backup. Grafana history/settings and Prometheus history can be lost if their Pods are replaced.
