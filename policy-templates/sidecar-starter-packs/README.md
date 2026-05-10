# Sidecar starter packs (OPA/Cedar)

These starter packs are policy-framework examples for Thoth policy sidecars.

They are intentionally customer-agnostic:

- no tenant names, user emails, domains, or account IDs
- no proprietary detector internals
- no private signatures or incident playbook content

Use these bundles as a baseline for new customer onboarding across tenants, then tune by pull request.

## Files

- `opa-standard-dlp.rego`
  - Blocks customer-facing requests when sensitivity exceeds public.
  - Adds critical anomaly hard-stop behavior.
- `opa-least-privilege-analyst.rego`
  - Least-privilege pattern for analyst-style tool access decisions.
- `cedar-standard-dlp.cedar`
  - Cedar equivalent of standard DLP boundaries.
- `cedar-least-privilege-analyst.cedar`
  - Cedar least-privilege baseline for analyst workflows.

Each policy includes `thoth_rule` directives so Enforcer can execute low-latency deterministic sidecar decisions.

## Assignment patterns

Use any of these assignment modes when creating policy bundle versions:

- `all`
- `agent:<agent-id>`
- `<agent-id>` (direct agent ID match)

Keep pricing tiers separate from policy assignments in customer-facing configs.

## Rollout guidance

1. Start with `enforcement_mode=observe` in `dev`.
2. Evaluate day-7 report and DLP mismatch findings.
3. Promote to `enforcement_mode=enforce` in `prod` after review.
4. Use rollback by version ID if false positives exceed threshold.
