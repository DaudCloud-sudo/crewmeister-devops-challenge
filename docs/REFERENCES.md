# Technical References

These official documentation pages explain technologies used in this project and provide recommended reading for operating or extending it. They were selected for relevance; this list is not a claim that every page was consulted during each implementation decision. URLs were checked against the official documentation sites on 2026-11-04 where the sites were accessible.

## Kubernetes

- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/) and [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) explain the app and database workload objects.
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/) describes stable in-cluster networking; [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) covers PVC-backed storage used by MySQL.
- [Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/workloads/pods/probes/) explains the application health probes; [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) is useful for logs and pod troubleshooting.

## Local containers and Kubernetes

- **kind:** [Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) covers creating and managing local clusters; [Configuration](https://kind.sigs.k8s.io/docs/user/configuration/) describes cluster configuration.
- **Podman:** [Podman command reference](https://docs.podman.io/en/latest/markdown/podman.1.html) covers the CLI and rootless use; [`podman build`](https://docs.podman.io/en/latest/markdown/podman-build.1.html), [`podman run`](https://docs.podman.io/en/latest/markdown/podman-run.1.html), and [`podman network`](https://docs.podman.io/en/latest/markdown/podman-network.1.html) relate to image building, containers, and the kind runtime/networking.
- **Docker:** [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) defines the instructions used by the project Dockerfile; [Docker Build overview](https://docs.docker.com/build/concepts/overview/) explains image builds and build context; [What is a container?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) introduces the container concept.

## Deployment and infrastructure

- **Helm:** [Charts](https://helm.sh/docs/topics/charts/) introduces chart structure; [Values Files](https://helm.sh/docs/chart_template_guide/values_files/) and the [Chart Template Guide](https://helm.sh/docs/chart_template_guide/) explain configuration and templates. [`helm install`](https://helm.sh/docs/helm/helm_install/) and [`helm upgrade`](https://helm.sh/docs/helm/helm_upgrade/) document release operations.
- **Terraform:** [What is Terraform](https://developer.hashicorp.com/terraform/intro), [Providers](https://developer.hashicorp.com/terraform/language/providers), and [State](https://developer.hashicorp.com/terraform/language/state) cover declarative provisioning, provider integrations, and state. [Manage Kubernetes resources with Terraform](https://developer.hashicorp.com/terraform/tutorials/kubernetes/kubernetes-provider) describes the Kubernetes provider pattern; this project’s Terraform currently provisions a separate kind cluster.
- **GitHub Actions:** [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) documents workflow configuration; [GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners) describes hosted execution; [Building and testing Java with Maven](https://docs.github.com/en/actions/tutorials/build-and-test-code/java-with-maven) is relevant to this repository’s CI.

## Application and monitoring

- **Spring Boot Actuator and Micrometer:** [Actuator endpoints](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html) covers health exposure; [Spring Boot metrics](https://docs.spring.io/spring-boot/reference/actuator/metrics.html) and [Micrometer Prometheus](https://docs.micrometer.io/micrometer/reference/implementations/prometheus.html) explain application metrics and the Prometheus registry.
- **Prometheus:** [First steps](https://prometheus.io/docs/introduction/first_steps/) introduces scraping and targets; [configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) documents scrape jobs; [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) covers metric queries.
- **Grafana:** [Dashboards](https://grafana.com/docs/grafana/latest/visualizations/dashboards/) covers dashboard creation; [Prometheus data source](https://grafana.com/docs/grafana/latest/datasources/prometheus/) describes querying Prometheus; [provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/) explains file-based data sources and dashboards.
- **MySQL 8.0:** [Server system variables](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html) and [mysqladmin](https://dev.mysql.com/doc/refman/8.0/en/mysqladmin.html) support server configuration and administration; [account management statements](https://dev.mysql.com/doc/refman/8.0/en/account-management-statements.html) documents users and grants used for exporter access.
