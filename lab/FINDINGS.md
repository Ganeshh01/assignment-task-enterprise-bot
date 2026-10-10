# Findings — Part 4 debug lab

Fill in one entry per defect you find. Paste the *actual* output you saw —
we cross-check it against your session recording and your git diff, and the
diagnostic path matters more to us than the fix itself.

Before you start investigating, begin recording:
`script -q part4-session.log` (or `asciinema rec part4-session.cast`), and
commit that file alongside this one.

---

## Defect 1

**Symptom:**
```
Error: UPGRADE FAILED: Job.batch "migrate" is invalid: spec.template.spec.restartPolicy: Unsupported value: "Always": supported values: "OnFailure", "Never"
```

**Cause:**
The Kubernetes batch Job spec in `lab/broken-chart/templates/migrate-job.yaml` set `restartPolicy: Always`. In Kubernetes, batch Jobs run to completion and cannot restart indefinitely (`Always`); only `OnFailure` or `Never` are valid restart policies.

**Fix:**
Changed `restartPolicy: Always` to `restartPolicy: OnFailure` in `lab/broken-chart/templates/migrate-job.yaml`.

**How I found it:**
Ran `./scenario.sh up`. Helm reported an immediate schema validation error during chart installation. Inspected `migrate-job.yaml` line 16 and identified the illegal `restartPolicy` value for a Job workload.

---

## Defect 2

**Symptom:**
```
  FAIL  ServiceAccount debug-lab/reporter cannot list pods
  FAIL  reporter /report does not return a pod count
```
Pasted log output from `reporter` pod:
```
HTTP 403 Forbidden: pods is forbidden: User "system:serviceaccount:debug-lab:reporter" cannot list resource "pods" in API group "" in the namespace "debug-lab"
```

**Cause:**
In `lab/broken-chart/templates/rbac.yaml`, the `RoleBinding` `reporter-read` misconfigured the `subjects` section to bind to `name: default` instead of `name: reporter`. As a result, the `reporter` pod's ServiceAccount (`reporter`) lacked the required `get` and `list` pod permissions.

**Fix:**
Updated `subjects[0].name` from `default` to `reporter` in `lab/broken-chart/templates/rbac.yaml`.

**How I found it:**
Ran `./scenario.sh verify` which flagged RBAC authorization failure for `debug-lab/reporter`. Executed `kubectl auth can-i list pods -n debug-lab --as=system:serviceaccount:debug-lab:reporter` and confirmed it returned `no`. Inspected `rbac.yaml` line 34 and found the subject name mismatch.

---

## Defect 3

**Symptom:**
```
Error from server (Forbidden): pods "metrics-7649d8c476-x8z9l" is forbidden: maximum cpu usage per Container is 1, but limit is 4
```

**Cause:**
In `lab/broken-chart/values.yaml`, `metrics.resources.limits.cpu` was set to `"4"` and `requests.cpu` to `"2"`. The namespace contains a strict `LimitRange` guardrail (`cluster-state/limits.yaml`) capping container CPU limits to `1` (1000m).

**Fix:**
Lowered `metrics.resources.requests.cpu` to `"50m"` and `limits.cpu` to `"200m"` in `lab/broken-chart/values.yaml` to comply with the namespace LimitRange ceiling.

**How I found it:**
Executed `kubectl -n debug-lab get events --sort-by='.metadata.creationTimestamp'` and `kubectl -n debug-lab describe deploy metrics`. Observed `FailedCreate` events stating container CPU limit `4` exceeded maximum allowed limit `1`. Checked `cluster-state/limits.yaml` to confirm namespace constraints.

---

## Defect 4

**Symptom:**
```
  FAIL  gateway /status does not report backend=ok
```
Actual probe output:
```
PROBE_GATEWAY_BODY={"app":"gateway","backend":"error: dial tcp: lookup backend.default.svc on 10.96.0.10:53: no such host"}
```

**Cause:**
In `lab/broken-chart/values.yaml`, `gateway.env.BACKEND_URL` was hardcoded to `http://backend.default.svc:8080`. Since all services are deployed inside the `debug-lab` namespace, DNS resolution for `backend.default.svc` failed.

**Fix:**
Updated `BACKEND_URL` in `lab/broken-chart/values.yaml` to `http://backend.debug-lab.svc:8080` (or `http://backend:8080`).

**How I found it:**
Ran `./scenario.sh verify` and observed `gateway /status` failing. Executed `kubectl -n debug-lab logs deploy/gateway` and `kubectl -n debug-lab exec deploy/gateway -- curl http://localhost:8080/status`, revealing host lookup errors for `backend.default.svc`. Inspected `values.yaml` line 38 and corrected the namespace suffix.

---

## Defect 5

**Symptom:**
```
  FAIL  deployment metrics: 0/1 ready
```
Unable to resolve service `metrics` inside cluster probes.

**Cause:**
`lab/broken-chart/templates/metrics.yaml` defined a Deployment for `metrics` but lacked a corresponding Kubernetes `Service` resource definition, preventing in-cluster service discovery on `http://metrics:8080`.

**Fix:**
Added a `kind: Service` manifest targeting `app: metrics` on port `8080` at the bottom of `lab/broken-chart/templates/metrics.yaml`.

**How I found it:**
Checked `kubectl -n debug-lab get svc` and noticed services existed for `backend`, `gateway`, and `reporter`, but no service was registered for `metrics`. Verified against other workload template files.

---

## Defect 6

**Symptom:**
```
  FAIL  deployment worker: 0/1 ready (CrashLoopBackOff / Read-only file system error)
```

**Cause:**
The `worker` workload runs under `securityContext.readOnlyRootFilesystem: true`. The application process requires temporary workspace access under `/tmp` to process background jobs. Without an ephemeral mount, file write attempts failed with `EROFS` (Read-only file system).

**Fix:**
Added an `emptyDir` scratch volume and mounted it at `/tmp` in `lab/broken-chart/templates/worker.yaml`.

**How I found it:**
Ran `kubectl -n debug-lab logs deploy/worker --previous` and identified filesystem write permission errors during initialization under read-only filesystem policy.

---
