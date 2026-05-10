# Policy templates

These templates are safe starter baselines for early customer pilots.

They are intentionally generic and public-safe:

- No customer identifiers.
- No real secrets, tokens, domains, or group names.
- No proprietary model prompts, scoring formulas, or internal detection signatures.

## What these templates are for

- Two-agent pilot onboarding (security analyst + coding agent).
- Purpose-aware access control (`customer-facing`, `internal`, `confidential`).
- Early deterministic controls (`mismatch_boost`, `delegation_boost`, `trust_floor`, `critical_threshold`) that can be reviewed in pull requests.

## What these templates are not

- A complete compliance pack library.
- A drop-in replacement for customer-specific legal/security policy.
- A publication of Aten internal threat-detection IP.

## Available templates

- `fintech-two-agent-pilot/`
  - SOC2-style baseline profile for a two-agent pilot.
- `healthcare-two-agent-pilot/`
  - HIPAA-style baseline profile for a two-agent pilot.
- `sidecar-starter-packs/`
  - Reusable OPA/Cedar policy bundles for multi-tenant onboarding.
  - Includes assignment patterns for `all` and explicit agent-scoped targets.

Each template contains:

- `principals.yaml`
- `resources.yaml`
- `grants.yaml`
- `README.md`

## Rollout guidance

1. Start in observation mode during week 1.
2. Introduce `STEP_UP` for medium/high in week 2.
3. Promote to `BLOCK` only after approval metrics and false-positive rates are acceptable.

Use these runbooks together with:

- `onboarding/customer-environment-initialization.md`
- `operations/policy-lifecycle-management.md`
- `onboarding/thothctl-quickstart.md`
- `onboarding/terraform-quickstart.md`
- `onboarding/pulumi-quickstart.md`
