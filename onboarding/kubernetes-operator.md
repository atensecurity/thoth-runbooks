# Kubernetes Operator Onboarding (thoth-operator)

This runbook covers deploying the Thoth Kubernetes operator so customer platform teams can manage Thoth tenant configuration via Kubernetes-native workflows.

This public version is intentionally limited. Keep environment-specific cutover
procedures and incident workflows in your internal runbooks.

## Why Operator + IaC Together

Recommended pattern:

1. Use Terraform/Pulumi providers for account-level and long-lived control-plane resources.
2. Use `thoth-operator` for cluster-local tenant reconciliation and GitOps-driven configuration updates.

This keeps platform provisioning and workload-side governance automation clearly separated.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.13+
- Network egress from cluster to `https://<thoth-control-plane-host>`
- Thoth admin auth token for the target tenant

## Install Operator

```bash
helm upgrade --install thoth-operator oci://ghcr.io/atensecurity/charts/thoth-operator \
  --version 0.1.0 \
  --namespace thoth-system \
  --create-namespace
```

## Create Auth Secret

```bash
kubectl -n thoth-system create secret generic thoth-admin-token \
  --from-literal=token='<THOTH_ADMIN_AUTH_TOKEN>'
```

## Apply ThothTenant

```yaml
apiVersion: platform.atensecurity.com/v1alpha1
kind: ThothTenant
metadata:
  name: tenant-a
  namespace: thoth-system
spec:
  tenantId: tenant-a
  apexDomain: "<apex-domain>"
  authSecretRef:
    name: thoth-admin-token
    key: token
  settings:
    enforceMcpPolicies: true
    approvalMode: "step_up"
  policySync: true
```

```bash
kubectl apply -f thothtenant.yaml
```

## Verify Reconciliation

```bash
kubectl -n thoth-system get thothtenant tenant-a -o wide
kubectl -n thoth-system describe thothtenant tenant-a
kubectl -n thoth-system logs deploy/thoth-operator
```

Healthy state indicators:

- `.status.phase` = `Ready`
- `Ready` condition = `True`
- `observedGeneration` matches current generation

## MDM Provider (Optional)

Add `mdmProvider` to `spec` and store provider token in a Kubernetes Secret. Do not place MDM credentials directly in CR YAML.

## Operational Guidance

- Rotate auth tokens through secret updates; reconciliation will re-apply desired state.
- Scope operator to a namespace with `watchNamespace` when multi-team isolation is required.
- Use GitOps for all CR changes and track approvals in your existing change-management workflow.
