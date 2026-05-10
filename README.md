# thoth-runbooks

Operational runbooks for running Thoth in headless deployments and integrations.

## Public Safety Rules

- Never include live customer names, tenant IDs, domains, or emails.
- Never include real secrets, tokens, API keys, callback secrets, or JWTs.
- Use placeholders for all environment-specific values.
- Keep internal break-glass or privileged operator procedures out of this repo.
- Keep detailed production cutover and incident-response procedures in internal docs only.

## Contents

- `siem/` — ingestion, routing, and alert enrichment runbooks
  - `siem/microsoft-sentinel.md`
  - `siem/splunk.md`
- `pam/` — step-up and approval-control runbooks
  - `pam/approval-gates.md`
- `soar/` — incident orchestration runbooks
  - `soar/incident-orchestration.md`
- `onboarding/` — getting started and deployment-pattern runbooks
  - `onboarding/customer-environment-initialization.md`
  - `onboarding/thothctl-quickstart.md`
  - `onboarding/headless-prepoc-testing.md`
  - `onboarding/choose-deployment-pattern.md`
  - `onboarding/terraform-quickstart.md`
  - `onboarding/pulumi-quickstart.md`
  - `onboarding/kubernetes-operator.md`
  - `onboarding/kubernetes-operator-production.md`
- `operations/` — day-2 governance lifecycle runbooks
  - `operations/policy-lifecycle-management.md`
- `policy-templates/` — public-safe starter policy bundles for early pilots
  - `policy-templates/fintech-two-agent-pilot/`
  - `policy-templates/healthcare-two-agent-pilot/`
  - `policy-templates/sidecar-starter-packs/`

## Audience

- Security engineering
- SecOps / SOC teams
- Platform teams operating Thoth via GitOps and APIs
