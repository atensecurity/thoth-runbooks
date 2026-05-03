# Pulumi quickstart for Thoth

This runbook shows how to manage Thoth governance resources with Pulumi.

Use this when your teams already deploy infrastructure through Pulumi stacks and want Thoth controls in the same workflow.

## What this quickstart creates

You will deploy:

- A Thoth provider instance configured for one tenant.
- Tenant baseline governance settings.
- One MDM provider integration.
- One MDM sync run.

## Prerequisites

- Pulumi CLI installed and authenticated.
- Node.js 20+ or Python 3.11+.
- A Thoth tenant ID and admin bearer token.

## Option A: Node.js quickstart

```bash
mkdir -p thoth-pulumi-nodejs
cd thoth-pulumi-nodejs
pulumi new nodejs --yes
npm install @pulumi/pulumi @atensec/pulumi-thoth@0.1.1
```

Replace `index.ts` with:

```ts
import * as pulumi from "@pulumi/pulumi";
import * as thoth from "@atensec/pulumi-thoth";

const cfg = new pulumi.Config();

const tenantId = cfg.require("tenantId");
const adminBearerToken = cfg.requireSecret("adminBearerToken");
const webhookUrl = cfg.require("webhookUrl");
const webhookSecret = cfg.requireSecret("webhookSecret");

const provider = new thoth.Provider("thoth", {
  tenantId,
  adminBearerToken,
});

const tenantSettings = new thoth.governance.TenantSettings(
  "baseline",
  {
    complianceProfile: "soc2",
    shadowLow: "allow",
    shadowMedium: "step_up",
    shadowHigh: "block",
    shadowCritical: "block",
    webhookEnabled: true,
    webhookUrl,
    webhookSecret,
  },
  { provider }
);

const mdmProvider = new thoth.mdm.Provider(
  "jamf",
  {
    providerName: "jamf",
    name: "Jamf Pro",
    enabled: true,
    configJson: JSON.stringify({
      base_url: cfg.require("jamfBaseUrl"),
      client_id: cfg.require("jamfClientId"),
      client_secret: cfg.requireSecret("jamfClientSecret"),
    }),
  },
  { provider }
);

new thoth.mdm.Sync(
  "jamf-sync",
  {
    providerName: mdmProvider.providerName,
    waitForCompletion: true,
    timeoutSeconds: 180,
  },
  { provider }
);

export const tenant = tenantSettings.tenantId;
```

Set config values:

```bash
pulumi config set tenantId "<TENANT_ID>"
pulumi config set --secret adminBearerToken "<THOTH_ADMIN_BEARER_TOKEN>"
pulumi config set webhookUrl "https://example.internal/hooks/thoth"
pulumi config set --secret webhookSecret "<WEBHOOK_SECRET>"
pulumi config set jamfBaseUrl "https://example.jamfcloud.com"
pulumi config set jamfClientId "<JAMF_CLIENT_ID>"
pulumi config set --secret jamfClientSecret "<JAMF_CLIENT_SECRET>"
```

Deploy:

```bash
pulumi preview
pulumi up
```

Optional post-deploy integrity check:

```bash
thothctl evidence verify --tenant-id "<TENANT_ID>" --json
thothctl evidence chain --tenant-id "<TENANT_ID>" --limit 100 --json
```

## Option B: Python quickstart

```bash
mkdir -p thoth-pulumi-python
cd thoth-pulumi-python
pulumi new python --yes
pip install pulumi pulumi-thoth==0.1.1
```

Replace `__main__.py` with:

```python
import json

import pulumi
import pulumi_thoth as thoth

config = pulumi.Config()

provider = thoth.Provider(
    "thoth",
    tenant_id=config.require("tenantId"),
    admin_bearer_token=config.require_secret("adminBearerToken"),
)

tenant_settings = thoth.governance.TenantSettings(
    "baseline",
    compliance_profile="soc2",
    shadow_low="allow",
    shadow_medium="step_up",
    shadow_high="block",
    shadow_critical="block",
    webhook_enabled=True,
    webhook_url=config.require("webhookUrl"),
    webhook_secret=config.require_secret("webhookSecret"),
    opts=pulumi.ResourceOptions(provider=provider),
)

mdm_provider = thoth.mdm.Provider(
    "jamf",
    provider_name="jamf",
    name="Jamf Pro",
    enabled=True,
    config_json=json.dumps(
        {
            "base_url": config.require("jamfBaseUrl"),
            "client_id": config.require("jamfClientId"),
            "client_secret": config.require_secret("jamfClientSecret"),
        }
    ),
    opts=pulumi.ResourceOptions(provider=provider),
)

thoth.mdm.Sync(
    "jamf-sync",
    provider_name=mdm_provider.provider_name,
    wait_for_completion=True,
    timeout_seconds=180,
    opts=pulumi.ResourceOptions(provider=provider),
)

pulumi.export("tenant", tenant_settings.tenant_id)
```

Set config and deploy:

```bash
pulumi config set tenantId "<TENANT_ID>"
pulumi config set --secret adminBearerToken "<THOTH_ADMIN_BEARER_TOKEN>"
pulumi config set webhookUrl "https://example.internal/hooks/thoth"
pulumi config set --secret webhookSecret "<WEBHOOK_SECRET>"
pulumi config set jamfBaseUrl "https://example.jamfcloud.com"
pulumi config set jamfClientId "<JAMF_CLIENT_ID>"
pulumi config set --secret jamfClientSecret "<JAMF_CLIENT_SECRET>"

pulumi preview
pulumi up
```

## Notes on endpoint routing

- If `apiBaseUrl` is omitted, the provider derives `https://grid.<tenant_id>.<apex_domain>`.
- Keep `apexDomain` default unless your tenant uses a custom domain model.

## Day-2 operations

- Use stack config updates for secret rotation.
- Keep separate stacks per environment (`dev`, `staging`, `prod`).
- Promote the same code, not hand-edited copies.

## Troubleshooting

`Provider initialization fails`:

- Check token validity and tenant ID.
- Confirm egress to `grid.<tenant_id>.<apex_domain>`.

`Resource drift after manual API edits`:

- Run `pulumi refresh`.
- Reconcile stack state and code before the next `pulumi up`.

`MDM sync times out`:

- Increase `timeoutSeconds` and inspect downstream MDM API health.

## Recommended next step

Add policy lifecycle controls in a dedicated stack update pipeline with manual approvals for STEP_UP and BLOCK posture changes.
