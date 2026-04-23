# Splunk SIEM Runbook

## Objective

Route Thoth governance events into Splunk with tenant/fleet/endpoint context.

## Integration pattern

1. Configure tenant webhook destination in Thoth settings.
2. Point webhook URL to Splunk HEC receiver.
3. Validate signature and map fields into Splunk CIM-friendly attributes.

## Required fields

- `tenant_id`
- `agent_id`
- `destination_channel`
- `siem_provider`
- `occurred_at`
- `action`
- `risk_tier`

## Verification

- Send webhook test event from control-plane automation.
- Confirm event indexing under expected sourcetype.
- Validate enriched fields in saved searches and alerts.
