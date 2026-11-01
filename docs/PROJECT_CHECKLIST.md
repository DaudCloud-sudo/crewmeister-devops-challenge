# DevOps Challenge — Project Checklist

This checklist tracks the implementation of the Crewmeister DevOps challenge.
Items are marked complete only after they have been tested.

## Environment

- RHEL 10.2 VM: 8 CPUs, 8 GB RAM, 40 GB virtual disk.
- Git repository cloned from the official challenge source.
- Working branch: `devops-implementation`.
- GitHub is the project record; Notion is secondary.

## 01 — Project Requirements & Discovery
- [ ] Map challenge requirements to implementation and tests.
- [ ] Record assumptions, constraints, acceptance criteria, and risks.
- [ ] Separate core requirements from Plus features.

## 02 — Architecture & Design
- [x] Choose a local-first design using kind.
- [x] Start with a single-node cluster; document its HA limitation.
- [x] Plan MySQL in Kubernetes with a PVC.
- [x] Create kind with the CLI; use Terraform for selected cluster resources.
- [ ] Record remaining decisions and alternatives.

## 03 — Application & Containerization
- [x] Inspect the controller, entity, and repository.
- [ ] Verify the application configuration, migration, and tests.
- [ ] Build and test the supplied application.
- [ ] Create and verify the Dockerfile and image.

## 04 — Kubernetes & Helm
- [ ] Install required tools.
- [ ] Create and verify the kind cluster.
- [ ] Create the Helm chart and deploy the application and database.
- [ ] Verify access, configuration, and persistence.

## 05 — Terraform & AWS
- [ ] Configure Terraform for the existing kind cluster.
- [ ] Verify plan, apply, and teardown.
- [ ] Consider AWS only after the local workflow is working.

## 06 — CI/CD Engineering
- [ ] Add GitHub Actions for tests and build.
- [ ] Decide whether CI publishes an image.
- [ ] Document release and rollback steps.

## 07 — Observability & Operations
- [ ] Verify Actuator health checks.
- [ ] Decide whether to add Prometheus and Grafana.
- [ ] Document logs, health checks, and troubleshooting.

## 08 — Security & Reliability
- [ ] Keep credentials out of Git.
- [ ] Review container and Kubernetes permissions.
- [ ] Document persistence, backup, and single-node limitations.

## 09 — Deployment & Operations Runbook
- [ ] Document setup from a fresh RHEL environment.
- [ ] Include build, deploy, verify, upgrade, and cleanup steps.
- [ ] Test the instructions from a clean environment.

## 10 — Interview Preparation & AI Usage
- [ ] Explain the architecture and key trade-offs.
- [ ] Prepare answers based on the implementation.
- [ ] Record AI assistance and what was independently verified.

## Decisions

- Keep the starter API behavior unchanged unless an optional change is approved.
- A PVC provides local persistence, not a backup.
- A VMware snapshot is not an application rollback or database backup.
- A single-node kind cluster is for local verification, not node-level HA.
- Do not claim tools or features are working until verified.

## Progress

- [x] Inspect RHEL environment.
- [x] Clone the challenge repository.
- [x] Create `devops-implementation` from `main`.
- [x] Commit project documentation.
- [ ] Verify the Java application.
