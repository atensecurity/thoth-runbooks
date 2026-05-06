# Choosing the right deployment pattern for Thoth

This runbook helps platform and security teams decide how to operate Thoth in production. You can run Thoth through Terraform, Pulumi, the Kubernetes operator, or a hybrid of all three.

If you are deciding quickly, use the hybrid model:

1. Terraform or Pulumi for account-level and platform-level controls.
2. Kubernetes operator for cluster-local tenant reconciliation.

That split keeps ownership clean. Platform teams manage long-lived control-plane config. Application teams manage cluster-local changes through GitOps.

## Audience

Use this runbook if you are:

- Standing up Thoth for the first time.
- Migrating from manual API calls to IaC.
- Standardizing governance rollout across several teams.

## Two-minute decision guide

| Your situation | Recommended pattern |
| --- | --- |
| You already run Terraform for infra and want low process change | Terraform provider |
| You already run Pulumi programs across app and infra | Pulumi provider |
| Teams push all workload config through Kubernetes/GitOps | Kubernetes operator |
| You have central platform teams plus app teams owning clusters | Hybrid (Terraform/Pulumi + operator) |

## Pattern deep dive

## Pattern A: Terraform provider only

Use this when:

- You have an existing Terraform pipeline with plan/apply approvals.
- Governance controls are managed by a central platform team.
- You do not need cluster-local reconciliation loops.

What you manage well in Terraform:

- `thoth_governance_settings`, `thoth_webhook_settings`, `thoth_siem_settings`, `thoth_pam_settings`
- `thoth_mdm_provider` and `thoth_mdm_sync`
- `thoth_policy_sync`
- Browser governance resources
- Split API key resources (`thoth_fleet_api_key`, `thoth_endpoint_api_key`, `thoth_agent_api_key`) and approval resources

Tradeoffs:

- Strong auditability and drift detection.
- Slower for app teams that only operate from Kubernetes repos.

## Pattern B: Pulumi provider only

Use this when:

- You standardize on Pulumi for infra and app platform delivery.
- Teams want governance resources in TypeScript or Python programs.
- You prefer a single programming model over HCL.

What you get:

- Same control plane coverage as Terraform provider, exposed in Pulumi resources.
- Strong fit for engineering teams already shipping with Pulumi stacks.

Tradeoffs:

- Governance ownership can drift into app codebases if stack boundaries are not clear.
- You still need process controls around stack updates.

## Pattern C: Kubernetes operator only

Use this when:

- Your operational model is fully GitOps + Kubernetes CRDs.
- App teams should manage tenant behavior from cluster repos.
- You want automatic reconcile on secret updates.

What you get:

- Kubernetes-native workflow through `ThothTenant`.
- Continuous reconciliation.
- Good day-2 behavior for cluster-local changes.

Tradeoffs:

- Less ideal for central cross-tenant governance orchestration.
- You still need a release/upgrade strategy for operator versions.

## Pattern D: Hybrid (recommended)

Use this when:

- You need clear ownership boundaries.
- Central and app teams both contribute changes.
- You operate multiple environments and clusters.

A practical split:

- Terraform or Pulumi: baseline governance settings, global integrations, and central policies.
- Operator: namespace/cluster-local tenant reconciliation, secret rotation alignment, and fast app-team changes.

This model avoids a common failure mode: forcing every cluster-specific change through central IaC repos.

## Ownership model you should agree on early

Define these before rollout:

- Who owns tenant baseline controls (`shadow_*`, compliance profile, webhook posture).
- Who can trigger policy sync in production.
- Who rotates bearer and integration secrets.
- Which repo is source of truth for each resource type.

If ownership is ambiguous, governance drift will show up in your first incident.

## Recommended rollout plan (first 30 days)

Week 1:

- Pick your base pattern (Terraform, Pulumi, or hybrid).
- Establish one non-production tenant and one owner team.
- Validate endpoint derivation and auth flow.

Week 2:

- Add MDM and webhook integration.
- Run first policy sync with explicit approval trail.
- Add dashboards for webhook failures and sync errors.

Week 3:

- Add canary policy lifecycle (ALLOW -> STEP_UP -> BLOCK).
- Document rollback procedure and run tabletop.

Week 4:

- Extend to production tenant.
- Freeze baseline ownership and promote release cadence.

## Security guardrails to keep from day one

- Keep admin and integration tokens in secret stores only.
- Pin provider/operator versions and promote by environment.
- Require review gates for any change that increases blocking behavior.
- Capture who approved STEP_UP/BLOCK posture changes.

## Anti-patterns to avoid

- Running manual API updates in production while also using IaC.
- Mixing ownership for the same resource across Terraform, Pulumi, and operator.
- Shipping BLOCK rules directly without an observation and STEP_UP stage.
- Using long-lived personal tokens for automation.

## Related runbooks

- `onboarding/terraform-quickstart.md`
- `onboarding/pulumi-quickstart.md`
- `onboarding/kubernetes-operator-production.md`
- `operations/policy-lifecycle-management.md`
