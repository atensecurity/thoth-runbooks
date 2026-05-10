# Pulumi quickstart for Thoth

This runbook shows how to manage Thoth governance resources with Pulumi.

Use this when your teams already deploy infrastructure through Pulumi stacks and want Thoth controls in the same workflow.

## What this quickstart creates

You will deploy:

- A Thoth provider instance configured for one tenant.
- Tenant baseline governance and webhook settings.
- One MDM provider integration.
- One MDM sync run.
- Versioned OPA/Cedar policy bundles for sidecar enforcement.

## Prerequisites

- Pulumi CLI installed and authenticated.
- Node.js 20+ or Python 3.11+.
- A Thoth tenant ID and organization-scoped API key.

## Option A: Node.js quickstart

```bash
mkdir -p thoth-pulumi-nodejs
cd thoth-pulumi-nodejs
pulumi new nodejs --yes
npm install @pulumi/pulumi @atensec/pulumi-thoth@0.1.6
```

Replace `index.ts` with:

```ts
import * as pulumi from "@pulumi/pulumi";
import * as thoth from "@atensec/pulumi-thoth";

const cfg = new pulumi.Config();

const tenantId = cfg.require("tenantId");
const webhookUrl = cfg.require("webhookUrl");
const webhookSecret = cfg.requireSecret("webhookSecret");
const regulatoryRegimes = cfg.getObject<string[]>("regulatoryRegimes") ?? [
  "soc2",
];

const provider = new thoth.Provider("thoth", {
  tenantId,
});

const governanceSettings = new thoth.governance.GovernanceSettings(
  "baseline-governance",
  {
    complianceProfile: "soc2",
    regulatoryRegimes,
    shadowLow: "allow",
    shadowMedium: "step_up",
    shadowHigh: "block",
    shadowCritical: "block",
  },
  { provider },
);

new thoth.governance.WebhookSettings(
  "baseline-webhook",
  {
    webhookEnabled: true,
    webhookUrl,
    webhookSecret,
  },
  { provider },
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
  { provider },
);

new thoth.mdm.Sync(
  "jamf-sync",
  {
    providerName: mdmProvider.providerName,
    waitForCompletion: true,
    timeoutSeconds: 180,
  },
  { provider },
);

const standardDlpOpa = new thoth.governance.PolicyBundle(
  "standard-dlp-opa",
  {
    name: "standard-dlp",
    description: "Customer-agnostic purpose/sensitivity DLP baseline",
    framework: "OPA",
    rawPolicy: `package thoth.policies.standard_dlp
default allow := true
allow if { input.principal.id != ""; input.action != ""; input.context.purpose != "" }`,
    enforcementMode: "enforce",
  },
  { provider },
);

const enterpriseStandard = new thoth.governance.PolicyBundle(
  "enterprise-standard",
  {
    name: "global-governance",
    framework: "OPA",
    s3Uri: "s3://atensec-governance-us-west-2/v2.4.1/standard.rego",
    s3VersionId: "<optional-version-id>",
    expectedHash: "sha256:<expected-content-hash>",
    assignments: ["all"],
    enforcementMode: "enforce",
  },
  { provider },
);

const leastPrivilegeCedar = new thoth.governance.PolicyBundle(
  "least-privilege-cedar",
  {
    name: "least-privilege-analyst",
    description: "Least-privilege baseline for selected agents",
    framework: "CEDAR",
    rawPolicy: `permit(principal, action, resource) when { context.purpose != ""; context.action != ""; };`,
    assignments: ["agent:security-analyst-agent", "agent:coding-agent"],
    enforcementMode: "enforce",
  },
  { provider },
);

export const tenant = governanceSettings.tenantId;
export const policyBundleIds = {
  standardDlpOpa: standardDlpOpa.id,
  leastPrivilegeCedar: leastPrivilegeCedar.id,
};
```

Set config values:

```bash
pulumi config set tenantId "<TENANT_ID>"
pulumi config set webhookUrl "https://example.internal/hooks/thoth"
pulumi config set --secret webhookSecret "<WEBHOOK_SECRET>"
pulumi config set --path 'regulatoryRegimes[0]' "soc2"
pulumi config set jamfBaseUrl "https://example.jamfcloud.com"
pulumi config set jamfClientId "<JAMF_CLIENT_ID>"
pulumi config set --secret jamfClientSecret "<JAMF_CLIENT_SECRET>"
```

Deploy:

```bash
export THOTH_API_KEY="<THOTH_ORG_API_KEY>"
export THOTH_TENANT_ID="<TENANT_ID>"
pulumi preview
pulumi up
```

`THOTH_API_KEY` must be an organization-scoped key.

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
pip install pulumi pulumi-thoth==0.1.6
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
)

governance_settings = thoth.governance.GovernanceSettings(
    "baseline-governance",
    compliance_profile="soc2",
    regulatory_regimes=config.get_object("regulatoryRegimes") or ["soc2"],
    shadow_low="allow",
    shadow_medium="step_up",
    shadow_high="block",
    shadow_critical="block",
    opts=pulumi.ResourceOptions(provider=provider),
)

thoth.governance.WebhookSettings(
    "baseline-webhook",
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

standard_dlp_opa = thoth.governance.PolicyBundle(
    "standard-dlp-opa",
    name="standard-dlp",
    description="Customer-agnostic purpose/sensitivity DLP baseline",
    framework="OPA",
    raw_policy=(
        "package thoth.policies.standard_dlp\\n"
        "default allow := true\\n"
        "allow if { input.principal.id != \\\"\\\"; input.action != \\\"\\\"; input.context.purpose != \\\"\\\" }"
    ),
    enforcement_mode="enforce",
    opts=pulumi.ResourceOptions(provider=provider),
)

least_privilege_cedar = thoth.governance.PolicyBundle(
    "least-privilege-cedar",
    name="least-privilege-analyst",
    description="Least-privilege baseline for selected agents",
    framework="CEDAR",
    raw_policy="permit(principal, action, resource) when { context.purpose != \\\"\\\"; context.action != \\\"\\\"; };",
    assignments=["agent:security-analyst-agent", "agent:coding-agent"],
    enforcement_mode="enforce",
    opts=pulumi.ResourceOptions(provider=provider),
)

enterprise_standard = thoth.governance.PolicyBundle(
    "enterprise-standard",
    name="global-governance",
    framework="OPA",
    s3_uri="s3://atensec-governance-us-west-2/v2.4.1/standard.rego",
    s3_version_id="<optional-version-id>",
    expected_hash="sha256:<expected-content-hash>",
    assignments=["all"],
    enforcement_mode="enforce",
    opts=pulumi.ResourceOptions(provider=provider),
)

pulumi.export("tenant", governance_settings.tenant_id)
pulumi.export(
    "policyBundleIds",
    {
        "standardDlpOpa": standard_dlp_opa.id,
        "leastPrivilegeCedar": least_privilege_cedar.id,
    },
)
```

Set config and deploy:

```bash
pulumi config set tenantId "<TENANT_ID>"
pulumi config set webhookUrl "https://example.internal/hooks/thoth"
pulumi config set --secret webhookSecret "<WEBHOOK_SECRET>"
pulumi config set jamfBaseUrl "https://example.jamfcloud.com"
pulumi config set jamfClientId "<JAMF_CLIENT_ID>"
pulumi config set --secret jamfClientSecret "<JAMF_CLIENT_SECRET>"

export THOTH_API_KEY="<THOTH_ORG_API_KEY>"
export THOTH_TENANT_ID="<TENANT_ID>"
pulumi preview
pulumi up
```

Read-only invoice access as JSON from Pulumi invoke output:

```ts
const invoices = thoth.billing.getInvoicesOutput({ limit: 50 }, { provider });
export const billingInvoicesJson = invoices.responseJson;
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
