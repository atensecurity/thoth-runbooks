# Policy lifecycle management for ALLOW, STEP_UP, and BLOCK

This runbook covers how to roll out governance policy decisions safely.

The objective is simple: tighten control without surprising users or breaking production traffic.

## Why a lifecycle matters

Most policy incidents come from rollout speed, not policy intent. Teams jump from permissive settings to hard blocking without enough observation data.

Use a staged lifecycle:

1. Observe current behavior.
2. Introduce STEP_UP where human approval is viable.
3. Move to BLOCK only after you can justify impact and rollback path.

## Baseline policy stages

Stage 0: Observe only

- `shadow_low = allow`
- `shadow_medium = allow` or `step_up`
- `shadow_high = step_up`
- `shadow_critical = step_up` or `block` (depends on org risk posture)

Stage 1: Step-up for medium and high risk

- Keep user experience intact for low-risk flows.
- Force approval workflow for medium/high.

Stage 2: Block high-risk patterns

- Move high and critical risk to `block` after approval data validates low false-positive risk.

## Change control requirements

Before any policy tier tightening in production:

- Name a change owner.
- Define measurable success and rollback criteria.
- Set a review window and approver.
- Record expected impacted tools, agents, and user paths.

If you cannot answer those four items, do not promote the change.

## How to implement the lifecycle

## Terraform path

Use `thoth_governance_settings`:

```hcl
resource "thoth_governance_settings" "tenant" {
  shadow_low      = "allow"
  shadow_medium   = "step_up"
  shadow_high     = "block"
  shadow_critical = "block"
}
```

Manage webhook/SIEM/PAM integrations with `thoth_webhook_settings`,
`thoth_siem_settings`, and `thoth_pam_settings` as separate resources.

Then trigger sync:

```hcl
resource "thoth_policy_sync" "rollout" {
  trigger               = "2026-05-02-rollout-high-block"
  wait_for_completion   = true
  poll_interval_seconds = 5
  timeout_seconds       = 180
}
```

## Pulumi path

Use governance settings and sync resource update in one stack change.

Keep rollout trigger strings explicit so you can trace exactly which change executed which sync.

## Operator path

Apply `settings`, `policyBundles`, and `policySync: true` in `ThothTenant`.

Use Git commit history as your rollout audit log.

## Canary strategy that works in practice

1. Canary tenant first.
2. Keep canary running for a full business cycle.
3. Review STEP_UP and BLOCK event rates.
4. Promote to next tenant batch.

Do not canary by random tool IDs. Canary by tenant or environment boundary so rollback is predictable.

## Approval workflow guidance (STEP_UP)

If you use STEP_UP decisions:

- Define who can approve and within what SLA.
- Define what happens on timeout.
- Log approval decisions with request context.

Avoid creating an approval queue that no one owns.

## Metrics to watch during rollout

Track these every day during rollout windows:

- Count of policy evaluations by risk tier.
- Count and rate of STEP_UP decisions.
- Count and rate of BLOCK decisions.
- False-positive reports from users.
- Mean time to approve STEP_UP requests.

If BLOCK spikes without matching threat indicators, pause rollout and investigate.

## Rollback playbook

When impact is unacceptable:

1. Revert policy tier to previous known-good values.
2. Trigger policy sync.
3. Verify status and event trend stabilization.
4. Publish incident update and next review window.

Rollback example target:

- `shadow_high` from `block` back to `step_up`

## Common failure modes

`Too many approvals, teams bypass controls`:

- Medium-risk scope is too broad.
- Tune tool risk overrides before broadening BLOCK.

`Unexpected hard blocks`:

- Stale policy package or mismatch between baseline and synced rules.
- Force sync and verify changed/applied counts.

`No visible effect after policy change`:

- Sync was not triggered or did not complete.
- Verify policy sync status and timestamps.

## Post-rollout review template

Use this after each promotion wave:

- What changed
- What was expected
- What actually happened
- Any user-impact tickets
- Any security wins
- What to tune before next wave

Keep reviews short and blunt. You need signal, not ceremony.

## Related runbooks

- `onboarding/choose-deployment-pattern.md`
- `onboarding/terraform-quickstart.md`
- `onboarding/pulumi-quickstart.md`
- `onboarding/kubernetes-operator-production.md`
- `policy-templates/README.md`
