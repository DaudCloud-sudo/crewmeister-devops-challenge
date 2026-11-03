# Crewmeister Challenge

## Background

At Crewmeister, our development team is continuously growing. We aim to hire the best educated, motivated, and enthusiastic people in the field who have fun building up Crewmeister in our vision to empower small businesses to thrive in a digital world. For this quest, we are continuously getting new applicants from all over the world. To filter which candidates could be a good fit, we provide our candidates with a coding challenge that we manually review and evaluate.

---

## DevOps Engineer Task

As a DevOps Engineer at Crewmeister, you will be in charge of several challenging tasks in your daily work. One of your core responsibilities will be to ensure that the system is always running smoothly and that the application is deployed successfully to our customers.

In this challenge, you should use DevOps best practices to architect and implement the complete cycle of building, packaging, and deploying a Java application (specified later in this document). 

The following are core technologies/tools that should be present in the solution:

- Dockerfile
- Helm Chart
- Terraform to interact with the Kubernetes cluster

You have the flexibility to utilize any cloud provider of your choice to deploy and run the application effectively. Additionally, it should be designed to operate seamlessly on local machines, allowing for a versatile setup that caters to various operational preferences and environments.

## Plus:

- Create a CI Pipeline in Github to automate the application lifecycle

- Add monitoring tools to check the health of the application

## Important Points:

- At Crewmeister, we value creativity and pushing for better. You are encouraged to expand the solution as you find fit. To do so, you must ensure high-quality documentation and that the base solution is correctly executed.
- All the tools used must be publicly accessible or explicitly documented on how to authenticate.
- All the tools must be free to use.

 ## Submission:
- Provide the link to your GitHub repository in the Greenhouse submission form.
- Submit your completed project via the Greenhouse link in the email received from the Recruitment Manager.

## Challenge Application

A Spring Boot application that provides a simple user management REST API.

### Technologies Used

- Java 17
- Spring Boot 3.3.5
- MySQL Database
- Flyway Migration
- Maven
- Spring Data JPA
- Spring Actuator

### Pre-requisites

- JDK 17
- MySQL
- Maven

### API Endpoints

#### GET /user

Retrieves a user by ID

#### POST /user

Creates a new user


## Local DevOps Lab: Startup and Verification

The local Kubernetes lab uses rootless Podman and kind. The existing `devops-lab`
cluster runs the Crewmeister application and MySQL through the Helm release
`crewmeister`.

To start and verify the existing cluster manually, run `./scripts/start-devops-lab.sh`.
The script starts the existing kind node container if needed, waits for the Kubernetes
node to become Ready, and displays the application pods, MySQL pod, and Helm release.

A user-level systemd service is configured as `devops-lab-startup.service`.
It is enabled to run at user startup. Check its status with
`systemctl --user status devops-lab-startup.service --no-pager`.

The service is a `Type=oneshot` unit with `RemainAfterExit=yes`. Therefore,
`active (exited)` with `status=0/SUCCESS` means the startup and verification
script completed successfully; it is not a continuously running process.

The Terraform configuration in `terraform/kind-lab` manages a separate kind
cluster named `terraform-lab`. It is separate from the `devops-lab` cluster
and the Helm release described above.

