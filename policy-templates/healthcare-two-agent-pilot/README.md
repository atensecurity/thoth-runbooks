# Healthcare two-agent pilot template

Use this for early healthcare pilots where strict purpose boundaries and confidential-data handling are required.

Scoped workflows:

- Security analyst agent (incident triage)
- Coding agent (internal remediation)

## Files

- `principals.yaml` defines pilot principals and role mappings.
- `resources.yaml` classifies sources and defines purpose sensitivity.
- `grants.yaml` defines least-privilege access and deterministic controls.

## Notes

- Replace placeholders before applying.
- Keep patient/member data in `confidential` classes.
- Treat `customer-facing` outputs as `public` only.
