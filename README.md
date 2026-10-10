# Enterprise Bot DevOps Technical Task Submission

This repository contains the completed solution for the DevOps / Platform Engineer technical assessment.

---

## Repository Structure

```
.
├── setup.sh            # One-command idempotent local environment bootstrap
├── README.md           # Documentation, architectural choices & AI policy disclosure
├── ANSWERS.md          # Architectural plan for zero-downtime Gateway API migration
├── service/            # Part 1: Python HTTP microservice & multi-stage Dockerfile
│   ├── app.py
│   ├── Dockerfile
│   └── .dockerignore
├── chart/              # Part 2: Parametrized Helm chart for the microservice
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── lab/                # Part 4: Debug lab handout and defect fixes
    ├── scenario.sh
    ├── cluster-state/
    ├── broken-chart/
    ├── FINDINGS.md
    └── part4-session.log
```

---

## How to Run & Verify

### Prerequisites
- Docker (running)
- `kind`
- `kubectl`
- `helm`

### Step 1: Execute One-Command Setup (Parts 1–3)
Run the idempotent setup script from the root of the repository:

```bash
chmod +x setup.sh
./setup.sh
```

Running `./setup.sh` a second time will verify idempotency (returns exit code 0 without errors).

### Step 2: Verify Microservice & Ingress
Add `demo.local` to your local `/etc/hosts` file resolving to `127.0.0.1`:
```text
127.0.0.1 demo.local
```

Test endpoints:
```bash
# Direct HTTP curl test via Ingress host
curl -s http://demo.local/
# Expected Output: {"app": "demo-app", "version": "1.0.0", "pod": "demo-demo-service-xxx"}

# Health check endpoint
curl -s http://demo.local/healthz
# Expected Output: {"status": "ok"}
```

Verify dynamic value overrides (as evaluated by grading harness):
```bash
helm upgrade demo ./chart -n demo --set config.appName=custom-app --set config.version=9.9.9
curl -s http://demo.local/
# Expected Output: {"app": "custom-app", "version": "9.9.9", "pod": "demo-demo-service-xxx"}
```

### Step 3: Verify Part 4 Debug Lab
Navigate to the `lab/` directory and execute:

```bash
cd lab
./scenario.sh up
./scenario.sh verify
```

Output will show **`ALL GREEN — 7/7 checks passed`**.

---

## Resource Requests and Limits Rationale

The microservice default values in `chart/values.yaml` are configured as:

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

### Rationale:
1. **CPU Requests (`50m`) & Limits (`200m`)**:
   The lightweight Python HTTP service has a baseline CPU footprint of ~5–10m under light traffic. A request of `50m` (0.05 core) guarantees Kubernetes scheduler placement without overcommitting node resources, while a ceiling of `200m` accommodates transient startup CPU spikes and concurrent JSON encoding.
2. **Memory Requests (`64Mi`) & Limits (`128Mi`)**:
   Python 3.12 slim runtime consumes ~30–40MB of RSS memory upon initialization. Setting memory request to `64Mi` avoids pod evictions, while setting a hard limit of `128Mi` prevents runaway memory leaks while staying well within standard Kubernetes node guardrails.

---

## What Was Deliberately Skipped & Associated Risks

1. **TLS / HTTPS Termination on Ingress**:
   - *Skipped*: SSL certificates (e.g. `cert-manager` with Let's Encrypt or self-signed CA) were omitted for local cluster simplicity.
   - *Risk*: Plain HTTP transmits data in cleartext, exposing traffic to interception in untrusted networks.
2. **Horizontal Pod Autoscaler (HPA) & PodDisruptionBudget (PDB)**:
   - *Skipped*: HPA policies based on CPU/RAM metrics and PDBs during node drains.
   - *Risk*: Fixed replica count (2) cannot automatically handle sudden traffic spikes or maintain availability guarantees during cluster maintenance.
3. **Structured Metrics / Prometheus Exporter**:
   - *Skipped*: Did not integrate Prometheus `/metrics` endpoint (OpenTelemetry / prometheus_client).
   - *Risk*: Limited visibility into p99 latency, request rates, and error rate trends in observability dashboards.

---

## Recommendations for Production Readiness

1. **Observability & Telemetry**:
   - Integrate `structlog` for JSON structured logging to stdout for log aggregators (Fluentbit / Datadog).
   - Expose Prometheus metrics (`http_requests_total`, `http_request_duration_seconds`).
2. **Security Hardening**:
   - Enforce Kubernetes `NetworkPolicies` restricting pod-to-pod egress/ingress.
   - Attach `cert-manager` for automated TLS certificate management on Ingress.
   - Run container vulnerability scans in CI pipeline (Trivy / Grype).
3. **High Availability**:
   - Configure `podAntiAffinity` across topology domains (nodes/zones).
   - Implement `PodDisruptionBudget` (`minAvailable: 1`).

---

## How I Used AI

In accordance with Enterprise Bot's AI Policy:

- **Tools Used**: Antigravity (Google DeepMind agentic coding assistant powered by Gemini 3.6 Flash).
- **Parts Assisted**:
  - Drafting multi-stage Dockerfile best practices and non-root security context configuration.
  - Structuring the Helm chart template layout and POSIX bash `setup.sh` script.
  - Formulating the architectural response in `ANSWERS.md` for zero-downtime Gateway API migration.
- **Corrections & Audits Applied**:
  - Audited `lab/broken-chart/` against `cluster-state/limits.yaml` to ensure resource limits remained under the 1 CPU limit.
  - Manually verified Helm template outputs using `helm template` and double-checked path syntax in `scenario.sh`.
