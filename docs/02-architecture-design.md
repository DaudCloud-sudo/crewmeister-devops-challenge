# Architecture decisions

The implementation favors a small local lab that can be inspected and rerun on the RHEL VM. This records why the tools were chosen and where the design stops short of production infrastructure.

| Decision | Selected approach and reason | Alternatives and remaining trade-offs |
|---|---|---|
| Container runtime | Rootless Podman is available on RHEL and runs without a privileged Docker daemon. | Docker is a viable alternative. Rootless Podman changes networking, port mapping, and storage behavior; it is not universally more secure for every workload. |
| Local Kubernetes | kind runs Kubernetes nodes as containers and is straightforward to create for local tests. | Minikube offers another local workflow; a managed service represents cloud operations more closely. The current one-node kind cluster has no node HA and does not model cloud networking. |
| Application deployment | Helm is the canonical source for the Crewmeister and MySQL release, values, and updates. | `k8s/app.yaml` and `k8s/mysql.yaml` are retained as raw-manifest reference examples, not a second deployable path. The examples can drift and must not be applied alongside the Helm release. |
| Infrastructure as Code | Terraform declares a separate `terraform-lab` kind cluster instead of relying only on manual cluster creation. | Terraform could also manage Kubernetes/Helm resources, but this provider currently creates only a local kind cluster. The challenge does not explicitly require Terraform to own the app release. |
| Database persistence | A single MySQL Deployment with a PVC keeps database files across Pod replacement and keeps the challenge setup simple. | An ephemeral database would lose data on replacement; a managed database is outside this local design. The PVC is not a backup/failover plan, and the single instance has no HA. |
| CI | GitHub Actions uses a temporary hosted Ubuntu runner and temporary MySQL service, separate from the RHEL VM. | A self-hosted runner could access local infrastructure, but would couple CI to the VM. This workflow tests Maven and repository configuration only; it does not publish an image or deploy. |
| Monitoring | Actuator health supports probes; Micrometer exposes metrics for Prometheus; Grafana queries those time series. A MySQL exporter adds server-side metrics. | Actuator-only checks provide no metric history; a larger monitoring stack would add cost and resource use. This local setup has bounded ephemeral history and no alerting or external availability monitoring. |

## Deployment boundaries

- `devops-lab` is the local cluster for the Crewmeister Helm release and monitoring manifests.
- `terraform-lab` is a separate cluster created by `terraform/kind-lab/main.tf`.
- GitHub Actions runs in GitHub-hosted infrastructure and does not connect to either local cluster.
- AWS is not provisioned. A cloud design would need provider-specific networking, identity, storage, and operations decisions.

The README has the compact architecture diagram and challenge status table. The [local operations guide](LOCAL-OPERATIONS-GUIDE.md) contains startup, verification, data, monitoring, and recovery commands.
