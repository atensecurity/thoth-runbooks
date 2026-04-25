# Thoth Headless Pre-POC Testing Runbook

Audience: customer security operators running first validation of Thoth with local agent workflows  
Mode: headless-first (API/CLI-driven), production-isolated tenant

> Public runbook: keep all tenant values, domains, keys, and user data
> redacted. Do not commit live credentials or customer identifiers.

## Goal

Validate that Thoth can:

1. enforce runtime decisions at action time (`ALLOW`, `STEP_UP`, `BLOCK`)
2. emit evidence that is machine-readable and exportable
3. integrate into existing security operations without requiring a net-new console

## Why this runbook exists

Security teams need empirical proof before a formal pilot:

1. Does it block real kill chains?
2. Can we retrieve evidence quickly for review?
3. Can we operate through API/CLI and existing SIEM/PAM workflows?

This runbook answers those questions with reproducible tests.

## 1) Provision an Isolated Tenant

Use a dedicated production-isolated tenant for the pre-POC.

Minimum controls:

1. tenant-scoped credentials only
2. explicit time-box for test window
3. retained evidence after tenant disablement for audit/review
4. revocation path for all issued keys

## 2) Access Model

Issue scoped credentials for three functions:

1. decisioning path (agent runtime calls)
2. policy administration (policy read/write for this tenant)
3. evidence readback (audit/evidence retrieval)

Do not use shared org-wide or environment-wide credentials.

## 3) Pre-Flight

Verify toolchain:

```bash
thoth --version || true
thothctl --version || true
jq --version
```

Set environment values:

```bash
export THOTH_TENANT_ID="<tenant-id>"
export THOTH_APEX_DOMAIN="<apex-domain>"
export THOTH_GOVAPI_BASE="https://govapi.${THOTH_TENANT_ID}.${THOTH_APEX_DOMAIN}"
export THOTH_ADMIN_BEARER_TOKEN_FILE="/path/to/admin-token.jwt"
```

## 3.1) Generate the admin token used by `thothctl`

`thothctl` admin operations require a valid admin bearer token for the target
tenant org.

### Default customer flow (no WorkOS secrets on operator machine)
Do not distribute identity-provider service secrets to customer operators.

`thothctl auth login` is the required auth path:

1. `POST /:tenant-id/thoth/auth/cli/start` to get signed state + authorize URL
2. browser sign-in
3. `POST /:tenant-id/thoth/auth/cli/exchange` to mint admin token
4. token verification via `/:tenant-id/thoth/auth/check`
5. token persisted to `--auth-token-file`

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "<admin@customer-domain>" \
  --apex-domain "$THOTH_APEX_DOMAIN" \
  --auth-token-file "$THOTH_ADMIN_BEARER_TOKEN_FILE"
```

Optional: add `--customer-domain "<customer-domain>"` if you need to override
the domain inferred from `--admin-email`.

Optional non-interactive mode (pre-captured auth code):

```bash
thothctl auth login \
  --tenant-id "$THOTH_TENANT_ID" \
  --admin-email "<admin@customer-domain>" \
  --auth-code "<auth-code>" \
  --apex-domain "$THOTH_APEX_DOMAIN" \
  --auth-token-file "$THOTH_ADMIN_BEARER_TOKEN_FILE"
```

### Internal fallback (non-public)
Internal break-glass auth procedures are intentionally omitted from this public
runbook.

Token requirements:

1. `org_id` matches tenant WorkOS org.
2. role includes admin privileges (`role`, `org_role`, or `thoth_role`).
3. token is unexpired (`exp`).

Default operator session behavior:

1. Once authenticated, admins can continue operations with the minted token.
2. Sensitive admin actions use a default freshness window of 6 hours.
3. After token expiry (or stale step-up), re-run `thothctl auth login`.

## 4) Headless Sanity Checks

```bash
thothctl settings get \
  --tenant-id "$THOTH_TENANT_ID" \
  --apex-domain "$THOTH_APEX_DOMAIN" \
  --auth-token-file "$THOTH_ADMIN_BEARER_TOKEN_FILE" \
  --json
```

```bash
thothctl browser providers list \
  --tenant-id "$THOTH_TENANT_ID" \
  --apex-domain "$THOTH_APEX_DOMAIN" \
  --auth-token-file "$THOTH_ADMIN_BEARER_TOKEN_FILE" \
  --json
```

```bash
thothctl mdm list \
  --tenant-id "$THOTH_TENANT_ID" \
  --apex-domain "$THOTH_APEX_DOMAIN" \
  --auth-token-file "$THOTH_ADMIN_BEARER_TOKEN_FILE" \
  --json
```

## 5) Connect Claude Desktop (or equivalent local client)

Wrap an existing MCP config:

```bash
thoth wrap-config \
  --tenant-id "$THOTH_TENANT_ID" \
  --api-key "<agent-decision-key>" \
  --enforcement-mode shadow \
  --session-intent testing \
  --output "<path-to-output-config>" \
  "<path-to-input-config>"
```

Start in `shadow`, then move selected scenarios to `block` after baseline behavior is understood.

## 6) Scenario Pack (Kill-Chain Focus)

Run each scenario through local personas/agents:

1. prompt-injection-driven secret exfiltration attempt
2. persona privilege escalation attempt
3. out-of-scope filesystem/network tool call
4. unsafe external state-changing action without approval context
5. cross-session context leakage attempt

Expected behavior:

1. safe/intended calls: `ALLOW`
2. high-impact ambiguous calls: `STEP_UP`
3. policy-violating calls: `BLOCK` and no downstream execution

## 7) Evidence Verification (API-first)

```bash
AUTH="Authorization: Bearer $(cat "$THOTH_ADMIN_BEARER_TOKEN_FILE")"
BASE="${THOTH_GOVAPI_BASE}/${THOTH_TENANT_ID}/thoth"

curl -sS -H "$AUTH" "${BASE}/violations?limit=50" | jq .
curl -sS -H "$AUTH" "${BASE}/approvals?limit=50" | jq .
curl -sS -H "$AUTH" "${BASE}/agent-stats" | jq .
curl -sS -H "$AUTH" "${BASE}/alerts?limit=50" | jq .
```

Capture per scenario:

1. attempted action and persona
2. expected decision
3. actual decision
4. policy reference
5. evidence/event identifier

## 7.1) Advanced Metadata Checks

For each blocked or stepped-up request, verify metadata includes:

1. execution lineage fields
2. broker/request correlation identifiers when applicable
3. policy decision reason details

Expected outcome:

1. runtime-governed events include lineage and decision context
2. correlation fields exist for brokered calls
3. no secret material is logged in clear text

## 8) Pass/Fail Criteria

Pre-POC passes if:

1. multiple realistic harmful chains are blocked or stepped up as designed
2. evidence is retrievable without dashboard dependency
3. no credential scope or tenant-isolation issues are observed
4. operator can replay tests and reproduce outcomes

## 9) Optional Next Step

Promote successful scenarios into a formal pilot acceptance matrix:

1. scenario definition
2. enforcement expectation
3. evidence retrieval requirement
4. SIEM/PAM routing requirement
5. owner sign-off
