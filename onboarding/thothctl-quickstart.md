# thothctl quickstart

This runbook is the fastest way to bootstrap a tenant with the `thothctl` CLI before you adopt Terraform, Pulumi, or the Kubernetes operator.

Use it when you need to:

- validate a tenant quickly,
- prove ALLOW/STEP_UP/BLOCK behavior in a headless workflow,
- initialize policy packs for a two-agent pilot,
- or recover quickly during operations without waiting on a full IaC cycle.

## What you will do

1. authenticate an admin session,
2. apply a governance baseline,
3. apply governance packs with deterministic controls,
4. optionally upsert policy sidecar bundles (OPA/Cedar),
5. optionally upsert MDM and trigger sync,
6. inspect runtime status, reports, and evidence,
7. validate runtime key scope.

## Prerequisites

- `thothctl` installed
- Current stable Thoth binary line (`thoth` + `thothctl`): `v0.2.29`
- tenant ID
- admin email for SSO login
- optional org API key for non-interactive calls
- network egress to your control-plane endpoint (for example `https://<thoth-control-plane-host>`)

Policy template baselines live in:

- `policy-templates/fintech-two-agent-pilot/`
- `policy-templates/healthcare-two-agent-pilot/`
- `policy-templates/sidecar-starter-packs/`

## 1) Sanity check local CLI

```bash
thothctl --version
thothctl manual | head -n 40
```

## 2) Set shell variables

```bash
export THOTH_TENANT_ID="<tenant-id>"
export THOTH_APEX_DOMAIN="<apex-domain>"
export THOTH_ADMIN_EMAIL="<admin@customer-domain>"
export THOTH_REGULATORY_REGIMES_CSV="soc2"

# Optional for non-interactive calls after initial login:
export THOTH_ORG_API_KEY="<org-api-key>"
```

## 3) Authenticate admin session

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "$THOTH_ADMIN_EMAIL" \
  --customer-domain "<customer-domain>"
```

Notes:

- The session is tenant-scoped.
- If your token expires or gets rejected, run `thothctl auth login` again.

## 4) Bootstrap tenant baseline

Week 1 (shadow-first) baseline for pilots:

```bash
thothctl bootstrap \
  --tenant-id "$THOTH_TENANT_ID" \
  --compliance-profile soc2 \
  --regulatory-regime soc2 \
  --shadow-low allow \
  --shadow-medium allow \
  --shadow-high step_up \
  --shadow-critical step_up \
  --json
```

Week 2 (selective enforcement) baseline:

```bash
thothctl bootstrap \
  --tenant-id "$THOTH_TENANT_ID" \
  --compliance-profile soc2 \
  --regulatory-regime soc2 \
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
  --regulatory-regime soc2 \
  --webhook-url "https://example.internal/hooks/thoth" \
  --webhook-secret "<webhook-secret>" \
  --webhook-enabled true \
  --json
```

Notes:

- `compliance-profile` selects an opinionated baseline preset.
- `regulatory-regime` declares the explicit legal/compliance obligations that drive baseline regulatory pack loading.
- If no `regulatory-regime` is set, GovAPI defaults to `soc2`.

## 5) Apply governance packs with deterministic controls

List available packs:

```bash
thothctl governance packs --tenant-id "$THOTH_TENANT_ID" --json
```

Apply selected packs to all pilot agents in `dev`:

```bash
thothctl governance apply-packs \
  --tenant-id "$THOTH_TENANT_ID" \
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

Use per-pack JSON when tuning controls by pack:

```bash
thothctl governance apply-packs \
  --tenant-id "$THOTH_TENANT_ID" \
  --environment dev \
  --all-agents \
  --pack-id "<pack-id-1>" \
  --pack-id "<pack-id-2>" \
  --overrides-by-pack-json '{
    "<pack-id-1>": {
      "behavioral_controls": {
        "mismatch_boost": 30,
        "delegation_boost": 14,
        "trust_floor": 0.22,
        "critical_threshold": 0.84
      }
    }
  }' \
  --json
```

## 6) Optional: add OPA/Cedar sidecar bundles

Use these starter packs to keep policy-as-code onboarding reusable across customers.

Apply an OPA bundle globally:

```bash
thothctl governance policy-bundles upsert \
  --tenant-id "$THOTH_TENANT_ID" \
  --name "standard-dlp" \
  --framework OPA \
  --raw-policy-file ./policy-templates/sidecar-starter-packs/opa-standard-dlp.rego \
  --assignment all \
  --enforcement-mode enforce \
  --json
```

Apply an S3-hosted OPA bundle with integrity pinning:

```bash
thothctl governance policy-bundles upsert \
  --tenant-id "$THOTH_TENANT_ID" \
  --name "global-governance" \
  --framework OPA \
  --s3-uri "s3://<policy-bucket>/<version>/standard.rego" \
  --s3-version-id "<optional-version-id>" \
  --expected-hash "sha256:<expected-content-hash>" \
  --assignment all \
  --enforcement-mode enforce \
  --json
```

Apply a Cedar bundle for higher-volume customer cohorts:

```bash
thothctl governance policy-bundles upsert \
  --tenant-id "$THOTH_TENANT_ID" \
  --name "least-privilege-analyst" \
  --framework CEDAR \
  --raw-policy-file ./policy-templates/sidecar-starter-packs/cedar-least-privilege-analyst.cedar \
  --assignment agent:security-analyst-agent \
  --assignment agent:coding-agent \
  --enforcement-mode enforce \
  --json
```

Inspect and rollback if needed:

```bash
thothctl governance policy-bundles list --tenant-id "$THOTH_TENANT_ID" --json
thothctl governance policy-bundles rollback --tenant-id "$THOTH_TENANT_ID" --bundle-id "<bundle-id>" --json
```

## 7) Optional: upsert MDM and trigger sync

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

## 8) Inspect runtime status and reports

```bash
thothctl settings get --tenant-id "$THOTH_TENANT_ID" --json
thothctl governance runtime-status --tenant-id "$THOTH_TENANT_ID" --json
thothctl governance day7-report --tenant-id "$THOTH_TENANT_ID" --days 7 --json
thothctl governance reports-overview --tenant-id "$THOTH_TENANT_ID" --days 30 --json
thothctl approvals tools --tenant-id "$THOTH_TENANT_ID" --json
thothctl evidence verify --tenant-id "$THOTH_TENANT_ID" --json
thothctl evidence chain --tenant-id "$THOTH_TENANT_ID" --limit 100 --json
```

If `latest_session_id` is present in the chain output, export the session bundle:

```bash
thothctl evidence bundle \
  --tenant-id "$THOTH_TENANT_ID" \
  --session-id "<session-id-from-chain>" \
  --output ./evidence-bundle-<session-id>.json
```

Optional billing preview and credit-bank check:

```bash
thothctl billing estimate --tenant-id "$THOTH_TENANT_ID" --json
thothctl billing credit-bank --tenant-id "$THOTH_TENANT_ID" --json
thothctl billing invoices --tenant-id "$THOTH_TENANT_ID" --limit 50 --json
thothctl billing invoices --tenant-id "$THOTH_TENANT_ID" --limit 50 --output ./billing/invoices-latest.json
```

## 9) Issue and validate a scoped runtime key

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

## 10) Common failure modes

`HTTP 401` during admin actions:

- Session is stale or invalid. Re-run `thothctl auth login`.

`HTTP 400 ... fleet does not exist`:

- Validate scope IDs first with `thothctl endpoints list --tenant-id "$THOTH_TENANT_ID" --json`.

`governance apply-packs` returns unknown `pack_id`:

- Confirm available pack IDs with `thothctl governance packs --tenant-id "$THOTH_TENANT_ID" --json`.

`choose exactly one scope selector`:

- Use one target mode per call: `--all-agents`, or explicit `--agent-id`, `--fleet-id`, or `--endpoint-id`.

`policy behavior changed but not reflected in traffic`:

- Confirm baseline + pack assignment applied, then verify `governance runtime-status` and approvals feed outputs.

## 11) Move from CLI-first to managed lifecycle

After initial bootstrap, move long-lived config into one of these:

- `onboarding/customer-environment-initialization.md`
- `onboarding/terraform-quickstart.md`
- `onboarding/pulumi-quickstart.md`
- `onboarding/kubernetes-operator-production.md`

Keep `thothctl` for fast diagnostics, emergency operations, and controlled break-glass changes.
