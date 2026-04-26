# Thoth Headless Pre-POC Testing Runbook

Audience: customer security operators running first validation of Thoth with local agent workflows  
Mode: headless-first (API/CLI-driven), production-isolated tenant

> Public runbook: keep all tenant values, domains, keys, and user data
> redacted. Do not commit live credentials or customer identifiers.

## What This Runbook Proves

Validate that Thoth can:

1. enforce runtime decisions at action time (`ALLOW`, `STEP_UP`, `BLOCK`)
2. emit evidence that is machine-readable and exportable
3. integrate into existing security operations without requiring a net-new console

## Why This Exists

Security teams need empirical proof before a formal pilot:

1. Does it block real kill chains?
2. Can we retrieve evidence quickly for review?
3. Can we operate through API/CLI and existing SIEM/PAM workflows?

This runbook gives you a repeatable way to test all three.

## 1) Provision an Isolated Tenant

Use a dedicated tenant that is isolated from normal production workflows.

Minimum controls:

1. tenant-scoped credentials only
2. explicit test window (start/end time)
3. retained evidence after tenant disablement for audit/review
4. clear key revocation path

## 2) Access Model

Use scoped credentials for three functions:

1. decisioning path (agent runtime calls)
2. policy administration (policy read/write for this tenant)
3. evidence readback (audit/evidence retrieval)

Permission guidance:

1. decisioning keys must include `execute`
2. admin keys should use least privilege (`read` and/or `write` only as needed)

Avoid shared org-wide or environment-wide credentials.

## 3) Pre-Flight

Verify toolchain:

```bash
thoth --version || true
thothctl --version || true
jq --version
```

Set your environment values:

```bash
export THOTH_TENANT_ID="<tenant-id>"
export THOTH_APEX_DOMAIN="<apex-domain>"
export THOTH_GOVAPI_BASE="https://govapi.${THOTH_TENANT_ID}.${THOTH_APEX_DOMAIN}"
export THOTH_AUTH_SESSION_FILE="/path/to/thoth-admin-session.jwt"
```

Set proxy key material using hidden terminal input (recommended):

```bash
thoth set-api-key --api-key
```

For automation only (non-interactive), use:

```bash
thoth set-api-key --api-key-value "<agent-decision-key>"
```

## 3.1) Authenticate `thothctl` as an Admin

Run `thothctl auth login` once to create a local auth session file used by
follow-up CLI commands.

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "<admin@customer-domain>"
```

`--apex-domain` and `--auth-token-file` are optional overrides. Defaults are
`atensecurity.com` and `~/.thoth/admin-token.jwt`.

Optional: add `--customer-domain "<customer-domain>"` if the domain should be
different from the domain in `--admin-email`.

If you already have an auth code, use non-interactive mode:

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "<admin@customer-domain>" \
  --auth-code "<auth-code>"
```

Session behavior:

1. Once authenticated, admins can continue operations with the saved session.
2. Sensitive admin actions use a default freshness window of 6 hours.
3. After token expiry (or stale step-up), re-run `thothctl auth login`.

## 4) Quick Headless Sanity Checks

```bash
thothctl settings get \
  --tenant-id "$THOTH_TENANT_ID" \
  --json
```

```bash
thothctl browser providers list \
  --tenant-id "$THOTH_TENANT_ID" \
  --json
```

```bash
thothctl mdm list \
  --tenant-id "$THOTH_TENANT_ID" \
  --json
```

## 5) Connect Claude Desktop (or an Equivalent Client)

Wrap an existing MCP config:

```bash
thoth wrap-config \
  --tenant-id "$THOTH_TENANT_ID" \
  --enforcement-mode shadow \
  --session-intent testing \
  --output "<path-to-output-config>" \
  "<path-to-input-config>"
```

Optional preflight authorization check for a scoped key (hidden prompt mode):

```bash
thothctl api-keys authorize \
  --tenant-id "$THOTH_TENANT_ID" \
  --key-id "<key-id>" \
  --api-key \
  --permission execute \
  --organization \
  --json
```

Start in `shadow`. Move selected scenarios to `block` after baseline behavior
is confirmed.

## 6) Scenario Pack (Kill-Chain Focus)

Run each scenario through your local personas/agents:

1. prompt-injection-driven secret exfiltration attempt
2. persona privilege escalation attempt
3. out-of-scope filesystem/network tool call
4. unsafe external state-changing action without approval context
5. cross-session context leakage attempt

Expected outcomes:

1. safe/intended calls: `ALLOW`
2. high-impact ambiguous calls: `STEP_UP`
3. policy-violating calls: `BLOCK` and no downstream execution

## 7) Verify Evidence (API-first)

```bash
AUTH="Authorization: Bearer $(cat "$THOTH_AUTH_SESSION_FILE")"
BASE="${THOTH_GOVAPI_BASE}/${THOTH_TENANT_ID}/thoth"

curl -sS -H "$AUTH" "${BASE}/violations?limit=50" | jq .
curl -sS -H "$AUTH" "${BASE}/approvals?limit=50" | jq .
curl -sS -H "$AUTH" "${BASE}/agent-stats" | jq .
curl -sS -H "$AUTH" "${BASE}/alerts?limit=50" | jq .
```

Capture the following for each scenario:

1. attempted action and persona
2. expected decision
3. actual decision
4. policy reference
5. evidence/event identifier

## 7.1) Optional Advanced Metadata Checks

For each blocked or stepped-up request, verify metadata includes:

1. execution lineage fields
2. broker/request correlation identifiers when applicable
3. policy decision reason details

Expected result:

1. runtime-governed events include lineage and decision context
2. correlation fields exist for brokered calls
3. no secret material is logged in clear text

## 8) Pass/Fail Criteria

Treat the pre-POC as successful if:

1. multiple realistic harmful chains are blocked or stepped up as designed
2. evidence is retrievable without dashboard dependency
3. no credential scope or tenant-isolation issues are observed
4. operator can replay tests and reproduce outcomes

## 9) Next Step (Optional)

Promote successful scenarios into a formal pilot acceptance matrix:

1. scenario definition
2. enforcement expectation
3. evidence retrieval requirement
4. SIEM/PAM routing requirement
5. owner sign-off
