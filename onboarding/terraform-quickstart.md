# Terraform quickstart for Thoth

This runbook gets you from zero to a working Terraform-managed Thoth tenant baseline.

It assumes:

- You want to manage governance through `atensecurity/thoth`.
- You are starting in a non-production tenant first.
- You want a repeatable plan/apply flow with clear rollback options.

## What this quickstart creates

You will deploy:

- Tenant baseline governance and webhook settings.
- One MDM provider integration.
- One MDM sync run.
- One policy-pack assignment baseline with deterministic controls.
- Versioned OPA/Cedar policy bundles for sidecar enforcement.
- One policy sync run.

## Prerequisites

- Terraform `>= 1.5`
- Access to an organization-scoped Thoth API key
- Tenant ID (for example `acme-dev`)
- Optional apex domain if not using your default control-plane domain

Policy template baselines live in:

- `policy-templates/fintech-two-agent-pilot/`
- `policy-templates/healthcare-two-agent-pilot/`
- `policy-templates/sidecar-starter-packs/`

## Step 1: scaffold a working directory

```bash
mkdir -p thoth-terraform-quickstart
cd thoth-terraform-quickstart
mkdir -p policies

# Copy starter sidecar policies from thoth-runbooks:
cp <path-to-thoth-runbooks>/policy-templates/sidecar-starter-packs/opa-standard-dlp.rego ./policies/
cp <path-to-thoth-runbooks>/policy-templates/sidecar-starter-packs/cedar-least-privilege-analyst.cedar ./policies/
```

Policy preflight checks for onboarding:

- OPA policy must include conditions over `input.principal`, `input.action`, and `input.context`.
- Cedar policy must include at least one `permit(...)` or `forbid(...)` statement.

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    thoth = {
      source  = "atensecurity/thoth"
      version = ">= 0.1.7"
    }
  }
}

provider "thoth" {
  tenant_id   = var.tenant_id
  apex_domain = var.apex_domain
  org_api_key = var.org_api_key
}

resource "thoth_governance_settings" "baseline" {
  compliance_profile = "soc2"
  regulatory_regimes = var.regulatory_regimes

  # Week 1 shadow-first defaults
  shadow_low      = "allow"
  shadow_medium   = "allow"
  shadow_high     = "step_up"
  shadow_critical = "step_up"
}

resource "thoth_webhook_settings" "baseline_webhook" {
  webhook_enabled = true
  webhook_url     = var.webhook_url
  webhook_secret  = var.webhook_secret
}

resource "thoth_mdm_provider" "jamf" {
  provider_name = "jamf"
  name          = "Jamf Pro"
  enabled       = true

  config_json = jsonencode({
    base_url      = var.jamf_base_url
    client_id     = var.jamf_client_id
    client_secret = var.jamf_client_secret
  })
}

resource "thoth_mdm_sync" "jamf_sync" {
  provider_name       = thoth_mdm_provider.jamf.provider_name
  wait_for_completion = true
  timeout_seconds     = 180
}

resource "thoth_pack_assignment_bulk" "pilot_controls" {
  pack_ids     = var.pilot_pack_ids
  environment  = "dev"
  all_agents   = true

  mismatch_boost     = 25
  delegation_boost   = 12
  trust_floor        = 0.20
  critical_threshold = 0.85

  trigger = "pilot-controls-v1"
}

resource "thoth_policy_bundle" "standard_dlp_opa" {
  name        = "standard-dlp"
  description = "Customer-agnostic purpose/sensitivity DLP baseline"
  framework   = "OPA"
  raw_policy  = file("${path.module}/policies/opa-standard-dlp.rego")
  enforcement_mode = "enforce"
}

# Optional: source policy from versioned S3 instead of local file.
# resource "thoth_policy_bundle" "enterprise_standard" {
#   name          = "global-governance"
#   framework     = "OPA"
#   s3_uri        = "s3://<policy-bucket>/<version>/standard.rego"
#   s3_version_id = "3Lg....optionalVersionId"
#   expected_hash = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
#   assignments   = ["all"]
#   enforcement_mode = "enforce"
# }

resource "thoth_policy_bundle" "least_privilege_cedar" {
  name        = "least-privilege-analyst"
  description = "Least-privilege baseline for selected analyst/coding agents"
  framework   = "CEDAR"
  raw_policy  = file("${path.module}/policies/cedar-least-privilege-analyst.cedar")
  assignments = ["agent:security-analyst-agent", "agent:coding-agent"]
  enforcement_mode = "enforce"
}

resource "thoth_policy_sync" "baseline" {
  trigger               = "initial-baseline-with-packs"
  wait_for_completion   = true
  poll_interval_seconds = 5
  timeout_seconds       = 180

  depends_on = [
    thoth_pack_assignment_bulk.pilot_controls,
    thoth_policy_bundle.standard_dlp_opa,
    thoth_policy_bundle.least_privilege_cedar
  ]
}
```

Create `variables.tf`:

```hcl
variable "tenant_id" {
  type = string
}

variable "org_api_key" {
  type      = string
  sensitive = true
}

variable "pilot_pack_ids" {
  type        = list(string)
  description = "Compliance packs to apply for pilot controls"
}

variable "regulatory_regimes" {
  type        = list(string)
  description = "Explicit regimes for baseline regulatory pack loading."
  default     = ["soc2"]
}

variable "apex_domain" {
  type    = string
  default = "example.com"
}

variable "webhook_url" {
  type = string
}

variable "webhook_secret" {
  type      = string
  sensitive = true
}

variable "jamf_base_url" {
  type = string
}

variable "jamf_client_id" {
  type = string
}

variable "jamf_client_secret" {
  type      = string
  sensitive = true
}
```

## Step 2: set secrets safely

Use environment variables instead of committing `*.tfvars` with secrets.

```bash
export TF_VAR_tenant_id="<TENANT_ID>"
export TF_VAR_org_api_key="<THOTH_ORG_API_KEY>"
export TF_VAR_apex_domain="<APEX_DOMAIN>"
export THOTH_API_KEY="<THOTH_ORG_API_KEY>"
export THOTH_TENANT_ID="<TENANT_ID>"

# Choose packs from `thothctl governance packs` output:
export TF_VAR_pilot_pack_ids='["<pack-id-1>","<pack-id-2>"]'
export TF_VAR_regulatory_regimes='["soc2"]'

export TF_VAR_webhook_url="https://example.internal/hooks/thoth"
export TF_VAR_webhook_secret="<WEBHOOK_SECRET>"
export TF_VAR_jamf_base_url="https://example.jamfcloud.com"
export TF_VAR_jamf_client_id="<JAMF_CLIENT_ID>"
export TF_VAR_jamf_client_secret="<JAMF_CLIENT_SECRET>"
```

Notes:

- `THOTH_API_KEY` must be an organization-scoped key.
- `THOTH_TENANT_ID` lets provider config omit `tenant_id` when desired.
- If you do not set `api_base_url`, the provider derives it from `tenant_id` and `apex_domain`.

## Step 3: init, plan, apply

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

## Step 4: verify state and runtime behavior

```bash
terraform state list
terraform show

# Verify pack assignment + runtime status
thothctl governance runtime-status --tenant-id "$TF_VAR_tenant_id" --json
thothctl governance day7-report --tenant-id "$TF_VAR_tenant_id" --days 7 --json

# Verify evidence-chain integrity
thothctl evidence verify --tenant-id "$TF_VAR_tenant_id" --json
thothctl evidence chain --tenant-id "$TF_VAR_tenant_id" --limit 100 --json
```

Read-only invoice access as JSON from Terraform data sources:

```hcl
data "thoth_billing_invoices" "recent" {
  limit = 50
}

output "billing_invoices_json" {
  value = data.thoth_billing_invoices.recent.invoices_json
}

output "billing_invoices_response_json" {
  value = data.thoth_billing_invoices.recent.response_json
}
```

You should see these resources in state:

- `thoth_governance_settings.baseline`
- `thoth_webhook_settings.baseline_webhook`
- `thoth_mdm_provider.jamf`
- `thoth_mdm_sync.jamf_sync`
- `thoth_pack_assignment_bulk.pilot_controls`
- `thoth_policy_bundle.standard_dlp_opa`
- `thoth_policy_bundle.least_privilege_cedar`
- `thoth_policy_sync.baseline`

## Importing existing resources into Terraform

If a tenant is already configured out of band, import before making edits.

Examples:

```bash
terraform import thoth_governance_settings.baseline "<TENANT_ID>"
terraform import thoth_webhook_settings.baseline_webhook "<TENANT_ID>"
terraform import thoth_mdm_provider.jamf "jamf"
terraform import thoth_policy_sync.baseline "policy-sync"
```

Then run:

```bash
terraform plan
```

Resolve drift in code before first production apply.

## Day-2 operations

Common updates:

- Rotate webhook/MDM secrets.
- Move from week-1 shadow to week-2 selective block posture.
- Tune deterministic controls by changing `thoth_pack_assignment_bulk` values.
- Trigger policy sync with a new `trigger` value.

Safe change workflow:

1. Commit code change.
2. Review `terraform plan` output.
3. Apply in non-prod tenant.
4. Promote same change to prod after verification.

## Troubleshooting

`Error: invalid token`:

- Verify `TF_VAR_org_api_key` or `THOTH_API_KEY` and confirm it is org-scoped.

`Plan wants to recreate MDM provider unexpectedly`:

- Re-check `provider_name` and current remote value.
- Import first if resource existed before Terraform management.

`pack_assignment_bulk` fails with unknown pack IDs:

- Validate pack IDs with `thothctl governance packs --tenant-id "$TF_VAR_tenant_id" --json`.

`policy_sync` appears unchanged:

- Change the `trigger` string to force a new sync execution.

## Recommended next step

After this quickstart is stable, add CI plan checks and environment promotion gates.
Then use `onboarding/customer-environment-initialization.md` as your customer-facing pilot initialization checklist.
