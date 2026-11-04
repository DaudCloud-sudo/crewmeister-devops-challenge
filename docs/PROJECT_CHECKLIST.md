# Challenge checklist

Statuses reflect repository evidence and recorded test results. “Unverified” means the current live environment or GitHub run was not checked; it does not erase earlier documented results.

| Requirement | Class | Status | Evidence and remaining work |
|---|---|---|---|
| Dockerfile | Core | Complete | `Dockerfile` packages the Java 17 JAR. `docs/CHALLENGES.md` records a successful Podman image build; rebuild for current verification. |
| Helm chart | Core | Complete | `helm/crewmeister/` defines app, MySQL, services, probes, and persistent volume claim. Current cluster release not live-verified. |
| Terraform interacting with Kubernetes | Core | Partial | `terraform/kind-lab/main.tf` provisions `terraform-lab` through the kind provider. It does not manage the `devops-lab` Helm release. |
| Local Kubernetes with kind | Core | Complete | Prior `docs/CHALLENGES.md` and local lab notes record `devops-lab` deployment and API checks. Current cluster access was blocked during the audit. |
| GitHub Actions CI | Plus | Partial | `.github/workflows/ci.yml` runs Maven verification with MySQL and uploads a JAR. Latest hosted run status not verified. |
| Monitoring | Plus | Partial | Actuator health endpoint and Kubernetes probes are configured. Prometheus metrics scraping and Grafana are not implemented. |

## Implementation and evidence

- **Application/container:** Java 17, Spring Boot, Maven, MySQL, Flyway; container image is built from the packaged JAR.
- **Canonical deployment:** Helm deploys Crewmeister and MySQL to `devops-lab`. The raw `k8s/` manifests are reference examples, not a second supported deployment path.
- **Infrastructure boundary:** Terraform provisions a separate `terraform-lab` kind cluster. It does not own the application release.
- **Startup helper:** starts the existing kind node container when stopped, waits at most 180 seconds for a Ready Kubernetes node, and reports the cluster state. It never creates or resets a cluster.
- **Credentials:** the database password is expected in a locally provisioned Kubernetes Secret. No password value belongs in the repository.

## Optional work and limitations

- A CI image-build check, image publication, and CD are optional; no automated delivery is configured.
- Prometheus/Grafana are optional enhancements; health probes already provide basic health checking.
- AWS is design-only. No cloud resources are provisioned.
- Single-node kind has no node-level high availability. A PVC is not a backup.
- The RHEL VM’s Kubernetes API and Podman runtime could not be inspected in the audit due to sandbox socket/runtime permissions; current live status remains unverified.
