# thothctl quickstart

This runbook is the fastest way to bootstrap a tenant with the `thothctl` CLI before you adopt Terraform, Pulumi, or the Kubernetes operator.

Use it when you need to:

- validate a tenant quickly,
- prove ALLOW/STEP_UP/BLOCK behavior in a headless workflow,
- or recover quickly during operations without waiting on a full IaC cycle.

## What you will do

1. authenticate an admin session,
2. apply a governance baseline,
3. optionally upsert MDM and trigger sync,
4. validate runtime key scope,
5. inspect current tenant state.

## Prerequisites

- `thothctl` installed
- tenant ID
- admin email for SSO login
- network egress to `https://grid.<tenant_id>.atensecurity.com`

## 1) Sanity check local CLI

```bash
thothctl --version
thothctl manual | head -n 40
```

## 2) Set shell variables

```bash
export THOTH_TENANT_ID="<tenant-id>"
export THOTH_APEX_DOMAIN="atensecurity.com"
export THOTH_ADMIN_EMAIL="<admin@customer-domain>"
```

## 3) Authenticate admin session

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "$THOTH_ADMIN_EMAIL" \
  --apex-domain "$THOTH_APEX_DOMAIN"
```

Notes:

- The session is tenant-scoped.
- If your token expires or gets rejected, run `thothctl auth login` again.

## 4) Bootstrap tenant baseline

Use this first-pass baseline in non-production:

```bash
thothctl bootstrap \
  --tenant-id "$THOTH_TENANT_ID" \
  --compliance-profile soc2 \
  --shadow-low allow \
  --shadow-medium step_up \
  --shadow-high block \
  --shadow-critical block \
  --json
```

Add webhook wiring if needed:

```bash
thothctl bootstrap \
  --tenant-id "$THOTH_TENANT_ID" \
  --webhook-url "https://example.internal/hooks/thoth" \
  --webhook-secret "<webhook-secret>" \
  --webhook-enabled true \
  --json
```

## 5) Optional: upsert MDM and trigger sync

Jamf example:

```bash
thothctl bootstrap \
  --tenant-id "$THOTH_TENANT_ID" \
  --mdm-provider jamf \
  --mdm-name jamf-prod \
  --mdm-config-file ./jamf-config.json \
  --start-sync \
  --json
```

Then check MDM status:

```bash
thothctl mdm list --tenant-id "$THOTH_TENANT_ID" --json
```

## 6) Inspect current tenant state

```bash
thothctl settings get --tenant-id "$THOTH_TENANT_ID" --json
thothctl browser providers list --tenant-id "$THOTH_TENANT_ID" --json
thothctl approvals tools --tenant-id "$THOTH_TENANT_ID" --json
```

## 7) Issue and validate a scoped runtime key

Create key for one fleet:

```bash
thothctl api-keys create \
  --tenant-id "$THOTH_TENANT_ID" \
  --fleet-id "<fleet-id>" \
  --permission execute \
  --permission read \
  --ttl-seconds 604800 \
  --json
```

Authorize that key against the same scope:

```bash
thothctl api-keys authorize \
  --tenant-id "$THOTH_TENANT_ID" \
  --key-id "<key-id>" \
  --api-key \
  --permission execute \
  --fleet-id "<fleet-id>" \
  --json
```

## 8) Common failure modes

`HTTP 401` during admin actions:

- Session is stale or invalid. Re-run `thothctl auth login`.

`HTTP 400 ... fleet does not exist`:

- Validate scope IDs first with `thothctl endpoints list --tenant-id "$THOTH_TENANT_ID" --json`.

`choose exactly one scope selector`:

- Use only one of `--organization`, `--fleet-id`, `--endpoint-id`, or `--agent-id`.

`policy behavior changed but not reflected in traffic`:

- Confirm baseline applied, then verify sync status and approval/feed outputs.

## 9) Move from CLI-first to managed lifecycle

After initial bootstrap, move long-lived config into one of these:

- `onboarding/terraform-quickstart.md`
- `onboarding/pulumi-quickstart.md`
- `onboarding/kubernetes-operator-production.md`

Keep `thothctl` for fast diagnostics, emergency operations, and controlled break-glass changes.
