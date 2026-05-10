# Customer environment initialization

Use this runbook to initialize a new customer tenant for early pilot execution.

This is intentionally tooling-agnostic:

- Option A: `thothctl` for fast bootstrap.
- Option B: Terraform for managed lifecycle from day one.

## Scope

This runbook covers:

- baseline tenant posture,
- policy-pack assignment and deterministic controls,
- runtime/evidence verification,
- first reporting outputs (day-7 and monthly estimate).

It does not expose internal model prompts, private heuristics, or proprietary threat signatures.

## Preflight checklist

Before touching the tenant, confirm:

- Tenant slug and customer domain are correct.
- One security owner and one platform owner are assigned.
- Org-scoped API key is provisioned and stored in a secret manager.
- Pilot workflow scope is explicit (usually two agents).
- Success criteria are explicit (attribution, risky-pattern detection, policy actionability).

## Choose a public starter template

Select one starter template and adapt placeholders:

- `policy-templates/fintech-two-agent-pilot/`
- `policy-templates/healthcare-two-agent-pilot/`

Template files:

- `principals.yaml`
- `resources.yaml`
- `grants.yaml`

Use the template values as your source of truth for:

- allowed purposes,
- default sensitivity classifications,
- deterministic controls (`mismatch_boost`, `delegation_boost`, `trust_floor`, `critical_threshold`).

## Option A: Initialize with thothctl

1. Authenticate:

```bash
thothctl auth login \
  --tenant-id "<tenant-id>" \
  --admin-email "<admin@customer-domain>" \
  --customer-domain "<customer-domain>"
```

2. Apply week-1 shadow baseline:

```bash
thothctl bootstrap \
  --tenant-id "<tenant-id>" \
  --compliance-profile soc2 \
  --shadow-low allow \
  --shadow-medium allow \
  --shadow-high step_up \
  --shadow-critical step_up \
  --json
```

3. Apply packs and deterministic controls:

```bash
thothctl governance apply-packs \
  --tenant-id "<tenant-id>" \
  --environment dev \
  --all-agents \
  --pack-id "<pack-id-1>" \
  --pack-id "<pack-id-2>" \
  --mismatch-boost 25 \
  --delegation-boost 12 \
  --trust-floor 0.20 \
  --critical-threshold 0.85 \
  --json
```

4. Verify runtime and evidence:

```bash
thothctl governance runtime-status --tenant-id "<tenant-id>" --environment dev --json
thothctl governance day7-report --tenant-id "<tenant-id>" --days 7 --json
thothctl evidence verify --tenant-id "<tenant-id>" --json
thothctl evidence chain --tenant-id "<tenant-id>" --limit 100 --json
```

## Option B: Initialize with Terraform

1. Define provider + baseline resources from `onboarding/terraform-quickstart.md`.
2. Add `thoth_pack_assignment_bulk` with deterministic controls.
3. Add `thoth_policy_sync` dependency on pack assignment.
4. Run:

```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

5. Verify:

```bash
thothctl governance runtime-status --tenant-id "<tenant-id>" --environment dev --json
thothctl governance day7-report --tenant-id "<tenant-id>" --days 7 --json
thothctl evidence verify --tenant-id "<tenant-id>" --json
```

## Week-1 and week-2 posture

Recommended rollout:

- Week 1: `allow/allow/step_up/step_up` for `low/medium/high/critical`.
- Week 2: `allow/step_up/block/block` after reviewing false positives and owner approval throughput.

## Output artifacts for customer review

Produce these artifacts by end of week 1 and week 2:

- Runtime attribution report (who/agent/tool/resource/decision/reason).
- Risky-pattern summary (top findings + severity + actionability).
- Deterministic control settings snapshot (current thresholds and recent changes).
- Evidence integrity snapshot (`evidence verify` + sample session bundle).
- Billing preview (`billing estimate`) and credit-bank status (`billing credit-bank`).

## Production hardening gate

Do not promote to broad blocking until all of the following are true:

- Day-7 report has stable, explainable decision patterns.
- Approval queue SLA is defined and met.
- Rollback owner + rollback command path are documented.
- Customer signs off on target week-2 control posture.

## Related runbooks

- `onboarding/thothctl-quickstart.md`
- `onboarding/terraform-quickstart.md`
- `operations/policy-lifecycle-management.md`
- `policy-templates/README.md`
