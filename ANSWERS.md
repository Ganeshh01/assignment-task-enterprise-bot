# Part 5 — Written Answers

## Q1. Migration Strategy: `ingress-nginx` to Kubernetes Gateway API

Migrating ~40 Ingress workloads from end-of-life `ingress-nginx` to the Kubernetes Gateway API without downtime requires a staged, side-by-side migration pattern focusing on traffic shadowing and weighted DNS / Load Balancer switching.

### Staged Approach & Execution Order

1. **Prerequisite & CRD Setup**:
   - Install official Gateway API Custom Resource Definitions (`GatewayClass`, `Gateway`, `HTTPRoute`) and deploy a modern Gateway API controller (e.g., Envoy Gateway or Cilium Service Mesh) alongside `ingress-nginx`.

2. **Control Plane Provisioning**:
   - Instantiate a global `GatewayClass` and define a `Gateway` object provisioned with its own distinct Load Balancer external IP/hostname.
   - Translate existing `Ingress` manifests into corresponding declarative `HTTPRoute` resources in parallel, mapping hosts, paths, header matches, and backend references without touching live traffic.

3. **Validation & Shadow Testing**:
   - Perform internal verification by querying the new Gateway IP directly via host header overrides (`curl -H "Host: app.domain.com" http://<NEW_GW_IP>`).
   - Enable request mirroring/shadowing on critical routes to validate latency and response accuracy under real traffic conditions.

4. **Zero-Downtime Traffic Migration**:
   - Shift external ingress traffic incrementally using weighted DNS records (e.g., Route53 / Cloudflare 90/10 split -> 50/50 -> 100%) or by updating upstream cloud load balancer target groups.

5. **Decommissioning**:
   - Monitor metrics (4xx/5xx rates, latency, TLS handshakes) for 48 hours before deleting legacy `Ingress` resources and uninstalling `ingress-nginx`.

---

### Expected Risks & Potential Breakages

- **Nginx-Specific Annotations**: Custom annotations like `nginx.ingress.kubernetes.io/configuration-snippet`, rewrites, or rate-limiting are not natively supported in standard `HTTPRoute` specs and require translation to Gateway API `URLRewrite` filters or vendor ExtensionFilters.
- **TLS Certificate Binding**: cert-manager integration semantics change from `acme.cert-manager.io/http01-edit-in-place` annotations to `DNSRoute` / `Gateway` listener secret references.
- **Client Session Affinity**: Cookie-based sticky session annotations on Nginx ingress will break unless explicitly reconfigured via vendor-specific Gateway policies.
