# Terraform quickstart for Thoth

This runbook gets you from zero to a working Terraform-managed Thoth tenant baseline.

It assumes:

- You want to manage governance through `atensecurity/thoth`.
- You are starting in a non-production tenant first.
- You want a repeatable plan/apply flow with clear rollback options.

## What this quickstart creates

You will deploy:

- Tenant baseline governance settings.
- One MDM provider integration.
- One MDM sync run.
- One policy sync run.

## Prerequisites

- Terraform `>= 1.5`
- Access to tenant admin bearer token
- Tenant ID (for example `acme-dev`)
- Optional apex domain if not using `atensecurity.com`

## Step 1: scaffold a working directory

```bash
mkdir -p thoth-terraform-quickstart
cd thoth-terraform-quickstart
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    thoth = {
      source  = "atensecurity/thoth"
      version = "~> 0.1.1"
    }
  }
}

provider "thoth" {
  tenant_id          = var.tenant_id
  apex_domain        = var.apex_domain
  admin_bearer_token = var.admin_bearer_token
}

resource "thoth_tenant_settings" "baseline" {
  compliance_profile = "soc2"

  shadow_low      = "allow"
  shadow_medium   = "step_up"
  shadow_high     = "block"
  shadow_critical = "block"

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

resource "thoth_policy_sync" "baseline" {
  trigger               = "initial-baseline"
  wait_for_completion   = true
  poll_interval_seconds = 5
  timeout_seconds       = 180
}
```

Create `variables.tf`:

```hcl
variable "tenant_id" {
  type = string
}

variable "apex_domain" {
  type    = string
  default = "atensecurity.com"
}

variable "admin_bearer_token" {
  type      = string
  sensitive = true
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

You can use environment variables instead of committing `*.tfvars` files with secrets.

```bash
export TF_VAR_tenant_id="<TENANT_ID>"
export TF_VAR_apex_domain="atensecurity.com"
export TF_VAR_admin_bearer_token="<THOTH_ADMIN_BEARER_TOKEN>"
export TF_VAR_webhook_url="https://example.internal/hooks/thoth"
export TF_VAR_webhook_secret="<WEBHOOK_SECRET>"
export TF_VAR_jamf_base_url="https://example.jamfcloud.com"
export TF_VAR_jamf_client_id="<JAMF_CLIENT_ID>"
export TF_VAR_jamf_client_secret="<JAMF_CLIENT_SECRET>"
```

Note on endpoint routing:

- If you do not set `api_base_url`, the provider derives it as `https://grid.<tenant_id>.<apex_domain>`.

## Step 3: init, plan, apply

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

## Step 4: verify state and remote behavior

```bash
terraform state list
terraform show

# Optional: verify runtime evidence-chain integrity after apply
thothctl evidence verify --tenant-id "$TF_VAR_tenant_id" --json
thothctl evidence chain --tenant-id "$TF_VAR_tenant_id" --limit 100 --json
```

You should see these resources in state:

- `thoth_tenant_settings.baseline`
- `thoth_mdm_provider.jamf`
- `thoth_mdm_sync.jamf_sync`
- `thoth_policy_sync.baseline`

## Importing existing resources into Terraform

If a tenant is already configured out of band, import before making edits.

Examples:

```bash
terraform import thoth_tenant_settings.baseline "<TENANT_ID>"
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
- Adjust shadow decisions by risk tier.
- Trigger policy sync with a new `trigger` value.

Safe change workflow:

1. Commit code change.
2. Review `terraform plan` output.
3. Apply in non-prod tenant.
4. Promote same change to prod after verification.

## Troubleshooting

`Error: invalid token`:

- Verify `TF_VAR_admin_bearer_token` value and token scope.

`Plan wants to recreate MDM provider unexpectedly`:

- Re-check `provider_name` and current remote value.
- Import first if resource existed before Terraform management.

`policy_sync` appears unchanged:

- Change the `trigger` string to force a new sync execution.

## Recommended next step

After this quickstart is stable, add CI plan checks and environment promotion gates.
