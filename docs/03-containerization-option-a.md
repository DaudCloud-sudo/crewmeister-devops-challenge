# Containerization — Option A (Host Gateway)

## Status
Verified locally on RHEL 10.2 using Podman.

## Components
- Application image: `localhost/crewmeister-app:0.1`
- Application container: `crewmeister-app-dev`
- Application container port: `8080`
- Host-published application port: `8081`
- Database container: `devops-mysql-test`
- Database port: `3306`
- Database: `challenge`
- Database: MySQL 8.0
- Application runtime: Java 17 / Spring Boot 3.3.5

## Network path
Host client -> `localhost:8081` -> application container port `8080`
-> `host.containers.internal:3306` -> host-published MySQL port
-> MySQL container.

The app container was configured with environment overrides for both
`SPRING_DATASOURCE_URL` and `SPRING_DATASOURCE_WRITER_URL`, using:

`jdbc:mysql://host.containers.internal:3306/challenge?createDatabaseIfNotExist=true`

The datasource username/password were supplied through environment variables.
Do not commit database credentials to source control.

## Verification evidence
- Application container remained Up.
- Spring Boot started successfully on container port 8080.
- Flyway connected to MySQL, validated one migration, and reported schema
  version 1.0.0 as up to date.
- Actuator health via `http://localhost:8081/actuator/health` returned HTTP 200
  and `{"status":"UP"}`.
- POST `/user` returned HTTP 200 and a greeting for `Container Test User`.
- MySQL query showed `Container Test User` persisted as ID 3.
- GET `/user?id=3` returned HTTP 200 and the expected greeting.

## Persistence inspection
The MySQL container's `/var/lib/mysql` is mounted from a Podman named volume:

`f4002082383f6b93a707b48981bf2a296c09036df9361aa19c8a7b3617ac6c82`

Preserve this volume. Do not remove it while recreating the database container.

## Learning / trade-off
Option A is a valid connectivity test and makes use of the host's published
database port. It introduces a host-gateway dependency and is less direct than
container-to-container DNS on a shared bridge network.

## Next
Implement Option B: connect/recreate MySQL on the dedicated Podman bridge,
preserve/reuse its named volume, and configure the app datasource URLs to use
the database container name and port 3306. Re-test health and API persistence.

# Option B — Shared Podman Bridge Network

## Architecture

Option B runs the Spring Boot application and MySQL as separate containers
connected to the same Podman bridge network.

- Application image: `localhost/crewmeister-app:0.1`
- Application container: `crewmeister-app-dev`
- MySQL image: `docker.io/library/mysql:8.0`
- MySQL container: `devops-mysql-test`
- Podman network: `devops-net`
- Application host port: `8081`, forwarded to container port `8080`
- MySQL container port: `3306`
- MySQL persistent storage: existing named volume mounted at `/var/lib/mysql`

The application image contains the Java runtime and Spring Boot executable JAR.
It does not contain or run MySQL.

MySQL runs in its own container using the MySQL image. The database files are
stored in a named volume so they survive MySQL container replacement.

## Network and DNS

Both containers are connected to `devops-net`, a Podman-managed bridge network
with DNS enabled.

The application connects to MySQL using:

`jdbc:mysql://devops-mysql-test:3306/challenge?createDatabaseIfNotExist=true`

The hostname `devops-mysql-test` is resolved by Podman's network DNS to the
MySQL container's address on `devops-net`.

MySQL port `3306` is not published to the RHEL host in Option B. The application
is still published on host port `8081` for local API access.

## Runtime configuration

The application receives the following environment variables:

- `SPRING_DATASOURCE_URL`: application datasource connection URL
- `SPRING_DATASOURCE_WRITER_URL`: Flyway migration connection URL
- `SPRING_DATASOURCE_USERNAME`: database username
- `SPRING_DATASOURCE_PASSWORD`: database password

The application datasource and Flyway writer URL point to the same MySQL
container in this local environment.

## Option A and Option B comparison

Option A uses `host.containers.internal:3306`. The app reaches MySQL through
the host gateway and MySQL's host-published port.

Option B uses `devops-mysql-test:3306`. The app reaches MySQL directly through
the shared Podman bridge network and container-name DNS.

Option A is a useful host-gateway connectivity approach. Option B is the chosen
container-to-container architecture for this project because the app and
database have an explicit shared network and MySQL does not need to publish
its port to the host.

## Option B validation

- MySQL container recreated on `devops-net`.
- Existing named volume preserved and reattached.
- Existing records remained present after container replacement.
- Spring Boot connected to MySQL through `devops-mysql-test:3306`.
- Flyway validated the migration and confirmed schema version `1.0.0`.
- Actuator health endpoint returned HTTP 200.
- POST created `Option B Test User`.
- SQL query confirmed the inserted row.
- GET for the inserted ID returned the expected greeting.

Option B end-to-end verification completed on 2026-11-01.

