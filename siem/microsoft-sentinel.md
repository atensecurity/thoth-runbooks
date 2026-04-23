# Microsoft Sentinel Runbook

## Objective

Ingest Thoth governance events into Sentinel for alerting and investigation.

## Integration pattern

1. Configure outbound Thoth webhook to an Azure ingestion endpoint.
2. Validate Thoth signature before forwarding into Sentinel tables.
3. Build analytic rules for critical/blocked actions.

## Detection starter

- Trigger on `action in ("BLOCK", "STEP_UP")`
- Group by `tenant_id`, `agent_id`, `risk_tier`
- Escalate when repeated high-risk events occur in short windows
