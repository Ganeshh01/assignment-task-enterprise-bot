# Enterprise Bot DevOps Technical Task Submission

This repository contains the complete submission for the Enterprise Bot DevOps / Platform Engineer technical assessment.

- **Candidate**: Ganesh Gorantala ([@Ganeshh01](https://github.com/Ganeshh01))
- **Repository**: [https://github.com/Ganeshh01/assignment-task-enterprise-bot.git](https://github.com/Ganeshh01/assignment-task-enterprise-bot.git)

---

## Repository Structure

```
.
├── setup.sh            # One-command idempotent local environment bootstrap
├── README.md           # Comprehensive documentation & step-by-step process guide
├── ANSWERS.md          # Architectural plan for zero-downtime Gateway API migration
├── service/            # Part 1: Python HTTP microservice & multi-stage Dockerfile
│   ├── app.py          # HTTP service source code
│   ├── Dockerfile      # Multi-stage, non-root Docker build specification
│   └── .dockerignore   # Docker build context exclusions
├── chart/              # Part 2: Parametrized Helm chart for the microservice
│   ├── Chart.yaml      # Chart metadata
│   ├── values.yaml     # Parametrized configuration values
│   └── templates/      # Kubernetes manifest templates (ConfigMap, Deployment, Service, Ingress)
└── lab/                # Part 4: Debug lab handout and defect fixes
    ├── scenario.sh     # Lab driver script (unmodified)
    ├── cluster-state/  # Cluster rules & limit ranges (unmodified)
    ├── broken-chart/   # Fixed Helm chart manifests
    ├── FINDINGS.md     # Recorded symptoms, root causes, and diagnostic paths
    └── part4-session.log # Terminal debugging session transcript
```

---

## Step-by-Step Process: What We Have Done

### Part 1 — Containerized Microservice (`service/`)
1. **Application Logic (`service/app.py`)**:
   - Developed a lightweight HTTP microservice using Python's standard `http.server` library.
   - Configured `GET /` to dynamically read `APP_NAME` and `VERSION` from environment variables and return JSON containing `{"app": "<APP_NAME>", "version": "<VERSION>", "pod": "<hostname>"}`.
   - Configured `GET /healthz` to return HTTP `200 OK` (`{"status": "ok"}`).

2. **Multi-Stage Dockerfile (`service/Dockerfile`)**:
   - Pinned base image to explicit tag `python:3.12.9-slim-bookworm` (avoided `latest`).
   - Implemented multi-stage build (`builder` stage and minimal `runner` stage).
   - Enforced non-root container security by creating system user `appuser` (UID 10001) and group `appgroup` (GID 10001) and switching execution context with `USER 10001:10001`.
   - Created `.dockerignore` to filter out build clutter (`.git`, `__pycache__`, `Dockerfile`, etc.).

---

### Part 2 — Parametrized Helm Chart (`chart/`)
1. Built a clean, parameterized Helm v3 chart under `chart/` exposing configurable fields in `values.yaml`:
   - `replicaCount`: Defaults to `2`.
   - `image.repository`: `demo-service`, `image.tag`: `v1.0.0`.
   - `config.appName`: `demo-app`, `config.version`: `1.0.0`.
   - `ingress.host`: `demo.local`.
   - `resources.requests` & `resources.limits`: Configured for CPU and memory.
2. Created template manifests:
   - `configmap.yaml`: Supplies `APP_NAME` and `VERSION` environment variables to the deployment.
   - `deployment.yaml`: Deploys pods with 2 replicas, `livenessProbe` and `readinessProbe` targeting `/healthz` on port `8080`, security context, and resource boundaries.
   - `service.yaml`: ClusterIP service exposing port `80` targeting container port `8080`.
   - `ingress.yaml`: Ingress routing host `demo.local` to the service.

---

### Part 3 — Idempotent Setup Script (`setup.sh`)
1. Authored an executable bash script `setup.sh` at the repository root that automates end-to-end setup:
   - Checks if `kind` cluster named `demo` exists; creates it with HTTP/HTTPS port mappings if absent.
   - Deploys the official `ingress-nginx` controller into the cluster.
   - Builds the `demo-service:v1.0.0` Docker image and loads it into the `kind` cluster.
   - Executes `helm upgrade --install demo ./chart -n demo --create-namespace`.
2. Guaranteed strict **idempotency**: Executing `./setup.sh` multiple times consecutively succeeds with exit code `0` without causing failures or resource collisions.

---

### Part 4 — Debugging the Lab (`lab/`)
Investigated and resolved **6 independent defects** in `lab/broken-chart/`:

1. **Defect 1 (Job Restart Policy)**:
   - *Symptom*: Helm upgrade failed with `spec.template.spec.restartPolicy: Unsupported value: "Always"`.
   - *Fix*: Updated `restartPolicy: Always` to `OnFailure` in `lab/broken-chart/templates/migrate-job.yaml`.

2. **Defect 2 (RBAC ServiceAccount Authorization)**:
   - *Symptom*: `reporter` pod failed with `403 Forbidden` when attempting to list pods.
   - *Fix*: Corrected `RoleBinding` subject `name` from `default` to `reporter` in `lab/broken-chart/templates/rbac.yaml`.

3. **Defect 3 (LimitRange CPU Limit Violation)**:
   - *Symptom*: `metrics` pod creation was rejected with `maximum cpu usage per Container is 1, but limit is 4`.
   - *Fix*: Lowered `metrics` CPU limits (`200m`) and requests (`50m`) in `lab/broken-chart/values.yaml` to comply with `cluster-state/limits.yaml`.

4. **Defect 4 (Gateway DNS Misconfiguration)**:
   - *Symptom*: `gateway /status` failed to reach backend (`lookup backend.default.svc: no such host`).
   - *Fix*: Corrected `BACKEND_URL` from `http://backend.default.svc:8080` to `http://backend.debug-lab.svc:8080` in `lab/broken-chart/values.yaml`.

5. **Defect 5 (Missing Service for Metrics)**:
   - *Symptom*: `metrics` deployment ready, but service endpoint unreachable in namespace.
   - *Fix*: Added missing `kind: Service` manifest targeting `app: metrics` in `lab/broken-chart/templates/metrics.yaml`.

6. **Defect 6 (Read-Only Filesystem Permission Error)**:
   - *Symptom*: `worker` pod entered `CrashLoopBackOff` due to write restrictions under `readOnlyRootFilesystem`.
   - *Fix*: Added `emptyDir` scratch volume mounted at `/tmp` in `lab/broken-chart/templates/worker.yaml`.

All fixes were validated by running `./scenario.sh verify` resulting in **`ALL GREEN — 7/7 checks passed`**.

---

### Part 5 — Written Architecture (`ANSWERS.md`)
Authored a ~200-word architectural response for zero-downtime migration from end-of-life `ingress-nginx` to the Kubernetes Gateway API:
- Dual-controller deployment & CRD initialization.
- Parallel `HTTPRoute` definition & traffic shadowing.
- Weighted DNS / Load Balancer IP traffic shifting.
- Analysis of risks including annotation translation, cert-manager binding, and sticky sessions.

---

### Part 6 & Bonus — Documentation & CI Pipeline
- **README**: Detailed verification commands, resource choice rationale, skipped features, and AI disclosure statement.
- **CI Workflow (`.github/workflows/ci.yml`)**: GitHub Actions pipeline that lints Helm charts, builds the Docker image, and runs security vulnerability scanning via Trivy.

---

## How to Run & Verify Locally

### Step 1: Execute Setup Script
```bash
chmod +x setup.sh
./setup.sh
```

### Step 2: Verify Microservice Endpoints
Map `127.0.0.1 demo.local` in your hosts file and test:
```bash
curl -s http://demo.local/
# Returns: {"app": "demo-app", "version": "1.0.0", "pod": "demo-demo-service-xxx"}

curl -s http://demo.local/healthz
# Returns: {"status": "ok"}
```

### Step 3: Run Lab Verification
```bash
cd lab
./scenario.sh up
./scenario.sh verify
# Returns: ALL GREEN — 7/7 checks passed
```

---

## Resource Requests & Limits Rationale

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

- **CPU (`50m` request / `200m` limit)**: Baseline idle usage is ~5m. `50m` request ensures reliable scheduling without resource starvation. `200m` limit prevents CPU throttling during startup or concurrent request spikes.
- **Memory (`64Mi` request / `128Mi` limit)**: Python 3.12 slim footprint is ~35MB RSS. `64Mi` request guarantees memory allocation, and `128Mi` limit protects against memory leaks while respecting node guardrails.

---

## What Was Deliberately Skipped & Risks

1. **TLS/HTTPS Ingress**: Skipped local SSL certificate provisioning; plain HTTP used for local testing. *Risk: Cleartext transmission in production networks.*
2. **Autoscaling (HPA) & PDB**: Skipped automatic scaling rules. *Risk: Fixed replica count cannot scale dynamically under traffic surges.*
3. **Structured Metrics Exporter**: Skipped Prometheus SDK integration. *Risk: Reduced real-time metric granularity for Grafana dashboards.*

---

## How I Used AI

In compliance with Enterprise Bot's AI Policy:
- **Tools Used**: Antigravity (Google DeepMind agentic coding assistant powered by Gemini 3.6 Flash).
- **Assisted Areas**: Formulating multi-stage Dockerfile standards, structuring Helm chart templates, POSIX bash script writing, and drafting Gateway API migration steps.
- **Verification**: All generated code, Helm charts, and cluster fixes were independently inspected and validated via local CLI tools (`helm lint`, `docker build`, `kubectl`).
