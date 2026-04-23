# SOAR Incident Orchestration Runbook

## Objective

Automate response to high-risk Thoth governance events.

## Trigger conditions

- Repeated `BLOCK` on same endpoint
- `CRITICAL` risk-tier decisions
- Fail-open threshold events

## Playbook steps

1. Enrich with tenant, endpoint, user, and tool context.
2. Open incident ticket with evidence payload.
3. Invoke endpoint containment or identity step-up controls.
4. Notify SOC and track remediation SLA.
5. Close incident after validation and post-incident notes.
