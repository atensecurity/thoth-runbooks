# PAM Approval Gates Runbook

## Objective

Integrate Thoth step-up decisions with privileged approval flows.

## Flow

1. Thoth emits `STEP_UP` decision event.
2. PAM workflow creates approval challenge with context.
3. On approval, downstream system executes privileged action.
4. On denial or timeout, action remains blocked and incident is logged.

## Minimum controls

- Approval TTL
- Dual-approval for critical actions
- Immutable audit trail linking decision, approver, and target action
