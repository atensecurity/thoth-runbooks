# Fintech two-agent pilot template

Use this for early SOC2-oriented pilots with two scoped workflows:

- Security analyst agent (SIEM triage)
- Coding agent (bug-fix workflow)

## Files

- `principals.yaml` defines pilot principals and human roles.
- `resources.yaml` declares governed resources and default sensitivity labels.
- `grants.yaml` maps principals to resources, purposes, and deterministic controls.

## Notes

- Replace all placeholders before applying.
- Keep names generic and policy-as-code changes reviewable.
- This template avoids proprietary scoring internals; it only exposes tunable controls.
