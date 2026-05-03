# Running thoth-operator in production

This runbook is for platform teams running `thoth-operator` in customer or internal clusters.

If you are only testing basic install, start with `onboarding/kubernetes-operator.md`. This guide focuses on production operation: version pinning, isolation, upgrades, rollback, and incident handling.

## Target architecture

Recommended production model:

- Central IaC (Terraform or Pulumi) defines global governance baseline.
- `thoth-operator` applies cluster-local tenant intent through `ThothTenant` CRs.

That split lets cluster teams move quickly without bypassing platform guardrails.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.13+
- Outbound network access to `https://grid.<tenant_id>.atensecurity.com`
- One namespace dedicated to operator runtime (`thoth-system`)
- Admin bearer token for target tenant in a Kubernetes Secret

## Step 1: create namespace and baseline controls

```bash
kubectl create namespace thoth-system
```

Decide whether you want cluster-wide watch or namespace scope:

- Cluster-wide: leave `watchNamespace` empty.
- Namespace-scoped: set `watchNamespace` to one namespace.

Namespace scope is usually cleaner in multi-team clusters.

## Step 2: create production values file

Create `values-prod.yaml`:

```yaml
replicaCount: 2

image:
  repository: ghcr.io/atensecurity/thoth-operator
  tag: "0.1.0"
  pullPolicy: IfNotPresent

watchNamespace: "thoth-system"

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

## Step 3: install with pinned chart version

```bash
helm upgrade --install thoth-operator oci://ghcr.io/atensecurity/charts/thoth-operator \
  --version 0.1.0 \
  --namespace thoth-system \
  --values values-prod.yaml
```

Production tip:

- Pin chart and image versions. Do not deploy `latest` in production.

## Step 4: create and manage secrets

Create Thoth admin token secret:

```bash
kubectl -n thoth-system create secret generic thoth-admin-token \
  --from-literal=token='<THOTH_ADMIN_BEARER_TOKEN>'
```

For MDM providers, store their API tokens in separate secrets. Keep each integration token isolated.

## Step 5: apply a production-grade ThothTenant

```yaml
apiVersion: platform.atensecurity.com/v1alpha1
kind: ThothTenant
metadata:
  name: tenant-prod
  namespace: thoth-system
spec:
  tenantId: tenant-prod
  apexDomain: atensecurity.com
  authSecretRef:
    name: thoth-admin-token
    key: token
  settings:
    complianceProfile: "soc2"
    shadowLow: "allow"
    shadowMedium: "step_up"
    shadowHigh: "block"
    shadowCritical: "block"
  policySync: true
```

```bash
kubectl apply -f thothtenant-prod.yaml
```

## Step 6: verify health and reconcile status

```bash
kubectl -n thoth-system get deploy,pods
kubectl -n thoth-system get thothtenant tenant-prod -o yaml
kubectl -n thoth-system describe thothtenant tenant-prod
kubectl -n thoth-system logs deploy/thoth-operator --tail=200
```

Healthy indicators:

- Controller pods are ready.
- `status.phase` is `Ready`.
- `status.observedGeneration` matches `metadata.generation`.

## Secret rotation workflow

Good rotation sequence:

1. Update secret value in place.
2. Confirm secret update completed.
3. Verify operator reconciliation for affected `ThothTenant`.
4. Confirm tenant status returns to `Ready`.

The controller watches referenced secret names and should reconcile quickly after updates.

## Upgrade workflow

For each version bump:

1. Test in non-production cluster first.
2. Upgrade chart with explicit `--version` and image tag.
3. Verify controller health and one test tenant reconcile.
4. Roll to production after a defined soak window.

Example:

```bash
helm upgrade thoth-operator oci://ghcr.io/atensecurity/charts/thoth-operator \
  --version 0.1.1 \
  --namespace thoth-system \
  --values values-prod.yaml
```

## Rollback workflow

If reconcile behavior regresses:

```bash
helm history thoth-operator -n thoth-system
helm rollback thoth-operator <REVISION> -n thoth-system
```

Then verify:

```bash
kubectl -n thoth-system rollout status deploy/thoth-operator
kubectl -n thoth-system get thothtenant
```

## Incident checklist

If tenants stop reconciling:

1. Check operator pod health and restart loops.
2. Check auth secret presence and key name.
3. Check network egress to Thoth endpoint.
4. Check `ThothTenant` conditions and latest events.
5. Check whether policy sync calls are timing out.

If behavior unexpectedly shifts to more blocking:

1. Inspect recent `ThothTenant` changes.
2. Inspect recent global IaC applies.
3. Roll back recent policy changes first, then retry sync.

## Hardening checklist

- Use dedicated namespace for operator runtime.
- Keep RBAC minimal for the namespaces you actually manage.
- Use version-pinned chart and image references.
- Keep secrets out of CR specs and Git history.
- Add alerting on operator pod failures and non-ready tenant status.

## Recommended GitOps layout

```text
clusters/
  prod/
    thoth-system/
      helmrelease-thoth-operator.yaml
      thothtenant-tenant-prod.yaml
      secrets/
```

Store secret manifests as references to your secret management controller, not raw secret values.
