# Live Interview & Screen-Share Defense Guide

This guide is designed for your live technical interview with the Enterprise Bot engineering team. In shortlisted candidate rounds, you will screen-share, walk them through your submission, defend your architectural choices, and modify/debug code on the spot.

---

## 1. The 60-Second Elevator Pitch

> *"For this task, I delivered a containerized Python microservice backed by a parameterized Helm chart, an idempotent setup script for `kind` and `ingress-nginx`, fixed six defects in the Part 4 debug lab, and drafted a zero-downtime migration strategy to the Gateway API.*
>
> *I paid close attention to security and production best practices — using multi-stage non-root Docker builds, strict Kubernetes resource limits, RBAC least privilege, and full setup idempotency."*

---

## 2. Walking Through the Repository Structure

When screen-sharing, show them the repository layout and explain each folder:

- **`service/`**: Microservice source code, multi-stage `Dockerfile`, and `.dockerignore`.
- **`chart/`**: Parameterized Helm v3 chart deploying `ConfigMap`, `Deployment`, `Service`, and `Ingress`.
- **`setup.sh`**: One-command bash script to bootstrap `kind`, load images, and deploy Helm releases cleanly.
- **`lab/`**: Part 4 debug lab fixes, `FINDINGS.md` diagnostic log, and `part4-session.log` recording.
- **`ANSWERS.md`**: Gateway API migration strategy (~200 words).
- **`README.md`**: Complete documentation, resource choice rationale, skipped features, and AI usage disclosure.
- **`.github/workflows/ci.yml`**: Bonus CI pipeline with Helm linting and Trivy security scanning.

---

## 3. Detailed Walkthrough of Each Part

### Part 1: Service & Dockerfile (`service/`)
- **Key Answer**: *"I chose Python's standard `http.server` because it requires zero third-party pip dependencies, eliminating supply-chain vulnerabilities and keeping image build times instant."*
- **Endpoints**:
  - `GET /`: Dynamically reads `APP_NAME` and `VERSION` from environment variables (not hardcoded) and returns pod hostname via `socket.gethostname()`.
  - `GET /healthz`: Returns `200 OK` for Kubernetes readiness and liveness probes.
- **Dockerfile Security Context**:
  - Multi-stage build pinned to explicit tag `python:3.12.9-slim-bookworm` (avoids mutable `latest`).
  - Creates dedicated system user/group `appuser` (UID 10001) and sets `USER 10001:10001` so containers never run as `root`.

---

### Part 2: Helm Chart (`chart/`)
- **Key Answer**: *"Templates contain zero hardcoded application values. Everything is parameterized through `values.yaml` and injected dynamically via ConfigMap and Helm overrides."*
- **Replicas & Resources**:
  - 2 replicas by default for high availability.
  - Resource requests (`cpu: 50m`, `memory: 64Mi`) for scheduler placement, resource limits (`cpu: 200m`, `memory: 128Mi`) to prevent runaway resource usage.
- **Ingress**:
  - Configured with `ingressClassName: nginx` targeting host `demo.local`.

---

### Part 3: One-Command Setup Script (`setup.sh`)
- **Key Answer**: *"I wrote `setup.sh` to be completely idempotent. It checks cluster and controller state before creating them so running it twice exits cleanly with code 0."*
- **Steps**:
  1. Creates `kind` cluster named `demo` with HTTP (80) and HTTPS (443) host port mappings if not present.
  2. Installs `ingress-nginx` controller via official manifest.
  3. Builds `demo-service:v1.0.0` Docker image and loads it into `kind` via `kind load docker-image`.
  4. Runs `helm upgrade --install demo ./chart -n demo --create-namespace`.

---

### Part 4: Debug Lab — Defending the 6 Defect Fixes

They will ask: *"How did you find these bugs and why did you fix them this way?"*

#### 1. Job Restart Policy (`migrate-job.yaml`)
- **Symptom**: Helm install error `Job.batch "migrate" is invalid: spec.template.spec.restartPolicy: Unsupported value: "Always"`.
- **Root Cause**: Kubernetes batch Jobs execute to completion; `restartPolicy: Always` is invalid for Jobs (only `OnFailure` or `Never` are allowed).
- **Fix**: Changed `restartPolicy: Always` to `OnFailure`.

#### 2. RBAC ServiceAccount Binding (`rbac.yaml`)
- **Symptom**: `reporter` pod got `HTTP 403 Forbidden` when querying `/report`.
- **Root Cause**: `RoleBinding` bound `reporter-read` permissions to `name: default` instead of `name: reporter`.
- **Fix**: Updated `subjects[0].name` from `default` to `reporter`.

#### 3. LimitRange Resource Violation (`values.yaml`)
- **Symptom**: `metrics` pod creation failed with `maximum cpu usage per Container is 1, but limit is 4`.
- **Root Cause**: `cluster-state/limits.yaml` defines a namespace LimitRange with container max CPU ceiling of `1`. `metrics` requested `2` and limited `4`.
- **Fix**: Reduced `metrics` CPU request to `50m` and limit to `200m`.

#### 4. Gateway DNS Endpoint (`values.yaml`)
- **Symptom**: `gateway /status` returned `error: dial tcp: lookup backend.default.svc: no such host`.
- **Root Cause**: `BACKEND_URL` was set to `http://backend.default.svc:8080`, but workloads run in `debug-lab` namespace.
- **Fix**: Changed `BACKEND_URL` to `http://backend.debug-lab.svc:8080`.

#### 5. Missing Metrics Service (`metrics.yaml`)
- **Symptom**: `metrics` deployment was running, but in-cluster network calls could not resolve `http://metrics:8080`.
- **Root Cause**: `metrics.yaml` defined a Deployment but lacked a Kubernetes `Service` object.
- **Fix**: Added `kind: Service` targeting `app: metrics` on port 8080.

#### 6. Read-Only Filesystem Scratch Space (`worker.yaml`)
- **Symptom**: `worker` pod crashed with `Read-only file system` errors under `securityContext.readOnlyRootFilesystem: true`.
- **Root Cause**: Application worker required temporary file write access under `/tmp`.
- **Fix**: Attached an `emptyDir` scratch volume mounted at `/tmp`.

---

## 5. Part 5: Gateway API Migration Strategy (`ANSWERS.md`)

- **Core Concept**: Side-by-side migration with zero downtime.
- **Key Stages**:
  1. Install Gateway API CRDs & Gateway Controller (e.g. Envoy Gateway) alongside `ingress-nginx`.
  2. Provision `Gateway` and translate `Ingress` rules into `HTTPRoute` resources in parallel.
  3. Validate traffic with `curl` host header overrides and request mirroring.
  4. Perform weighted DNS or load balancer IP migration (90/10 -> 50/50 -> 100%).
  5. Decommission legacy `ingress-nginx` after 48h observation.
- **What Breaks**: Custom Nginx annotations (`configuration-snippet`), cert-manager annotations, and sticky session cookies.

---

## 6. On-the-Spot Live Modification Practice (Be Ready For These!)

In the live round, interviewers often say: *"Great! Now modify your code live to do X."* Here is how to handle common requests:

1. **"Change the replica count to 5 using Helm."**
   - Command: `helm upgrade demo ./chart -n demo --set replicaCount=5`
2. **"Change the APP_NAME to 'enterprise-bot' and verify."**
   - Command: `helm upgrade demo ./chart -n demo --set config.appName=enterprise-bot`
   - Test: `curl -s http://demo.local/`
3. **"Check pod logs or debug a crash live."**
   - Commands:
     - `kubectl -n demo get pods`
     - `kubectl -n demo logs deploy/demo-demo-service`
     - `kubectl -n demo describe pod <pod-name>`
