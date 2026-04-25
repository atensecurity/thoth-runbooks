# thoth-runbooks

Operational runbooks for running Thoth in headless deployments and integrations.

## Public Safety Rules

- Never include live customer names, tenant IDs, domains, or emails.
- Never include real secrets, tokens, API keys, callback secrets, or JWTs.
- Use placeholders for all environment-specific values.
- Keep internal break-glass or privileged operator procedures out of this repo.

## Contents

- `siem/` — ingestion, routing, and alert enrichment runbooks
- `pam/` — step-up and approval-control runbooks
- `soar/` — incident orchestration runbooks
- `onboarding/` — headless pre-POC and operator onboarding runbooks

## Audience

- Security engineering
- SecOps / SOC teams
- Platform teams operating Thoth via GitOps and APIs
