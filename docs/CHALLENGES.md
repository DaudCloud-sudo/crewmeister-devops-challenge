# Project Challenges, Resolutions, and Interview Notes

This log records environment and implementation challenges encountered while
building and testing the Crewmeister DevOps coding challenge. It distinguishes
verified outcomes from planned improvements.

## C-01 — Java version and RHEL package availability

- **Context:** The application uses Java 17.
- **Challenge:** Java 17 was not available from the enabled RHEL repositories.
  Newer Java versions were available, but the project requires Java 17.
- **Resolution:** Installed Eclipse Temurin 17 in the user's home directory
  rather than changing the system-wide Java installation.
- **Verification:** `java -version` and `./mvnw -version` reported Java 17.
- **Interview learning:** Runtime compatibility, package repositories,
  per-user toolchains, and avoiding unnecessary system-wide changes.

## C-02 — Maven test failed because MySQL was unavailable

- **Context:** The Maven verification lifecycle runs the Spring Boot test.
- **Challenge:** The application context failed to load because Flyway could
  not connect to MySQL (`Connection refused`, SQL state `08S01`).
- **Diagnosis:** No local MySQL or MariaDB system service was installed/running.
- **Resolution:** Used Podman to run a temporary MySQL 8.0 container and
  published its database port to the VM.
- **Verification:** `./mvnw clean verify` completed successfully.
- **Interview learning:** Application tests may depend on external services;
  diagnose the underlying dependency before treating a test failure as an
  application-code defect.

## C-03 — Docker was unavailable; Podman was available

- **Challenge:** Docker was not installed in the VM environment.
- **Resolution:** Used the installed Podman CLI for local container work.
- **Scope:** Podman is the selected tool for this local implementation.
  This does not, by itself, decide the eventual production container runtime.
- **Interview learning:** OCI-compatible tooling and separating a development
  tool choice from a production architecture decision.

## C-04 — Recovering the temporary MySQL credential

- **Challenge:** An interactive MySQL login failed when no password was
  supplied. The database rejected the connection (`using password: NO`).
- **Diagnosis:** MySQL was initialized with a root password in the container's
  environment; the application YAML default is not what initializes MySQL.
- **Resolution:** Used `podman exec` to run the MySQL client inside the
  container with its configured `MYSQL_ROOT_PASSWORD` environment value.
  Later, loaded that value into a shell variable for the app container.
- **Verification:** Queried the database and found the saved test user.
- **Security note:** Do not commit credentials, put them in an image, or
  print them in logs. Environment-variable injection is a local learning
  approach; improve secret handling for production.

## C-05 — Verifying the application API against MySQL

- **POST verification:** POST `/user` with JSON containing `name` returned
  HTTP 200 and the expected greeting.
- **Database verification:** A SQL query showed the inserted user and its
  generated ID.
- **GET verification:** GET `/user?id=2` returned the greeting for that user.
- **Outcome:** Both API operations were verified against the running database.
- **Interview learning:** Validate the full request-to-database path, not only
  whether the process starts or a health endpoint returns UP.

## C-06 — Existing MySQL container could not join the new bridge network

- **Observed:** `podman network connect devops-net devops-mysql-test` failed
  with `"pasta" is not supported: invalid network mode`.
- **Diagnosis:** The existing database container was created with `pasta`
  networking. Podman could not attach it to the newly created bridge network
  using the attempted in-place network connection.
- **Evidence:** `podman inspect` reported `Network mode: pasta`.
- **Temporary approach:** Use Podman's `host.containers.internal` alias from
  the app container to reach the VM's published MySQL port 3306.
- **Verification:** A temporary container resolved `host.containers.internal`
  to `169.254.1.2`.
- **Planned durable approach:** Preserve database data, recreate MySQL with a
  dedicated bridge network, and connect the app to MySQL using the container
  name and Podman network DNS.
- **Interview learning:** Container network namespaces, `pasta` versus bridge
  networking, published ports, host gateway aliases, container DNS, and when
  container recreation is required to change network configuration.

## C-07 — Container database URLs differ from VM-hosted application URLs

- **Challenge:** The application configuration defaults to
  `localhost:3306`. Inside the app container, `localhost` refers to the app
  container itself—not the VM or the MySQL container.
- **Resolution for the first container test:** Override both the datasource
  URL and Flyway writer URL with the host gateway alias.
- **Interview learning:** Runtime configuration, container network boundaries,
  and why both application datasource and migration-tool configuration matter.

## C-08 — Container image built successfully

- **Implementation:** Added a Dockerfile using the Eclipse Temurin Java 17
  JRE base image, set `/app` as the working directory, copied the packaged
  Spring Boot JAR, documented port 8080, and set `java -jar app.jar` as the
  entrypoint.
- **Build:** `podman build -t crewmeister-app:0.1 .`
- **Outcome:** Image `localhost/crewmeister-app:0.1` built successfully.
- **Interview learning:** Image versus container, base images, build context,
  image layers, runtime versus build dependencies, and container entrypoints.

## Current status

- Earlier local evidence records Maven verification, health checks, POST/GET
  persistence, an image build, and both Podman networking options as successful.
- On 2026-11-04, the RHEL VM reported `kind-devops-lab` Ready, app/MySQL Pods
  Ready, PVC `mysql-data` Bound, Helm release `crewmeister` deployed, and
  Actuator health UP. A user POST was inspected in MySQL and read back with GET.
- The same date, a Java 17 image tagged `localhost/crewmeister-app:0.2` was
  built and loaded into the existing kind cluster. The app was upgraded through
  Helm without changing the MySQL claim.
- GitHub Actions run [41765219947](https://github.com/DaudCloud-sudo/crewmeister-devops-challenge/actions/runs/41765219947)
  for commit `936d3297d85a62da22a2e5920389150e385055a9` completed successfully.
  It ran Maven verification with MySQL and deployment-configuration checks;
  it did not deploy to kind.
- Live checks during monitoring finalization confirmed the app and MySQL
  exporter Prometheus targets UP, `mysql_up` equal to 1, and real MySQL uptime,
  connection, and query counter samples. Grafana's provisioned dashboard and
  Prometheus data source are verified; details and limitations are in
  `docs/LOCAL-OPERATIONS-GUIDE.md`.

## Container networking milestone — Option A verified
- **Challenge:** The app container needed to connect to MySQL running in a
  separate Podman container. The initial MySQL container used `pasta` networking,
  which could not be attached directly to the dedicated bridge.
- **Temporary solution (Option A):** Publish MySQL on host port 3306 and set
  both Spring datasource and Flyway URLs to
  `jdbc:mysql://host.containers.internal:3306/challenge?createDatabaseIfNotExist=true`.
- **Verification:** Container health returned HTTP 200. POST created
  `Container Test User` in MySQL (ID 3), and GET retrieved it successfully.
- **Persistence finding:** `/var/lib/mysql` is backed by a named Podman volume.
  Preserve and reuse it when recreating the database container.
- **Trade-off:** Option A routes through the host gateway. Option B below is the
  completed follow-up and uses direct container-name DNS on a shared bridge.

## Container networking — Option B

**Challenge:** The original MySQL container used Podman's `pasta` network mode.
Connecting it to a user-defined bridge network was not supported in that mode.

**Resolution:** Backed up the challenge database, removed only the old MySQL
container (not its named volume), and recreated MySQL on `devops-net`.
Recreated the app container on the same network.

**Configuration:** The app's datasource and Flyway writer URL use
`devops-mysql-test:3306`. Podman's network DNS resolves the MySQL container name.

**Verification:** MySQL remained ready, existing database records were retained,
Flyway validated the schema, the health endpoint returned HTTP 200, and POST/GET
API operations succeeded through the containerized app.

**Learning:** A container image packages the application; a container is a
running instance. App and database are separate containers connected by a
network. Runtime environment variables configure the app's database connection.

## Local Lab Operations

The lab uses rootless Podman and kind. The `devops-lab` cluster hosts the Helm
deployed application and MySQL. Terraform manages a separate cluster named
`terraform-lab`; these are currently independent environments.

A user-level systemd oneshot service starts and verifies the existing `devops-lab`
cluster by invoking `scripts/start-devops-lab.sh`. The service is expected to show
`active (exited)` after successful completion because it is a oneshot unit with
`RemainAfterExit=yes`.

The startup helper verifies the existing environment; it does not create a new
cluster, apply Terraform, or redeploy the Helm release. Terraform-to-Helm
integration is not required for this implementation: Terraform provisions the
separate `terraform-lab` cluster.

The helper waits up to 180 seconds for the Kubernetes node to report `Ready`.
This bound lets slow startup finish while ensuring a missing or unhealthy API
returns a failure instead of leaving a systemd oneshot waiting forever.
Actuator health is used by application probes. The local monitoring manifests
configure Prometheus scraping and a provisioned Grafana dashboard; see the
operations guide for the target, API, and dashboard checks.

