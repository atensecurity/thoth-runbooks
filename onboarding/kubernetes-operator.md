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
  authMode: auto
  authSecretRef:
    name: thoth-admin-token
    key: token
  settings:
    enforceMcpPolicies: true
    approvalMode: "step_up"
  policyBundles:
    - name: trantor-mutual-global-dlp
      framework: OPA
      sourceUri: s3://thoth-policy-bundles/trantor/global-dlp/policy.rego
      assignments:
        - agent:coding-agent
        - agent:security-analyst-agent
      status: active
      enforcementMode: enforce
  packAssignments:
    - packIds:
        - soc2-type2
      allAgents: true
      mismatchBoost: 0.15
      delegationBoost: 0.10
      trustFloor: 0.35
      criticalThreshold: 0.85
  decisionMetadataExport:
    enabled: true
    intervalMinutes: 30
    batchLimit: 1000
    lookbackHours: 24
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

Add `mdmProvider` and optional `mdmSync` to `spec`, and store provider token in a Kubernetes Secret. Do not place MDM credentials directly in CR YAML.

## Decision metadata export (Optional)

If you set `decisionMetadataExport`, the operator exports redacted metadata only:

- Raw content and tool arguments are omitted.
- User, session, and principal identifiers are hashed.
- Policy/trace metadata is preserved for analytics and model-training pipelines.
- By default, batches are collected at:
  `POST /:tenant-id/thoth/governance/moses/training/decision-metadata/collect`.
- In customer stacks, GovAPI exports collected batches into
  `s3://$MOSES_FEEDBACK_BUCKET/$MOSES_FEEDBACK_PREFIX/<tenant>/...` for MOSES
  retraining ingestion when `THOTH_MOSES_FEEDBACK_EXPORT_ENABLED=true` (default).

Set `decisionMetadataExport.destinationUrl` only if you need to send to an external collector.
Use `decisionMetadataExport.authTokenSecretRef` when that external destination requires bearer auth.

## Operational Guidance

- Rotate auth tokens through secret updates; reconciliation will re-apply desired state.
- Scope operator to a namespace with `watchNamespace` when multi-team isolation is required.
- Use GitOps for all CR changes and track approvals in your existing change-management workflow.
