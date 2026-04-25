# Thoth Headless Pre-POC Testing Runbook

Audience: customer security operators running first validation of Thoth with local agent workflows  
Mode: headless-first (API/CLI-driven), production-isolated tenant

> This is the standard runbook for all external customer sandboxes and pilots.
> Delta Arc is the first production customer sandbox using this flow, and the
> same steps apply to Rightway, Reddit, and future tenants.

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

Environment apex domains:

1. dev: `cawlo.dev`
2. staging: `nommos.space`
3. prod: `atensecurity.com`

## 3.1) Generate the admin token used by `thothctl`

`thothctl` admin operations require a valid WorkOS access token with admin role
for the target tenant org.

### Recommended model for external customer pilots

Aten issues a short-lived admin JWT for the customer sandbox and sends it
securely (1Password/shared secret). Customers do not need WorkOS API keys.

```bash
mkdir -p "$(dirname "$THOTH_ADMIN_BEARER_TOKEN_FILE")"
chmod 700 "$(dirname "$THOTH_ADMIN_BEARER_TOKEN_FILE")"
# write token to file, then:
chmod 600 "$THOTH_ADMIN_BEARER_TOKEN_FILE"
```

### Self-service model (operator-run) for any tenant

Use this only if you operate the WorkOS app credentials for the environment.

1. Set WorkOS values:

```bash
export WORKOS_CLIENT_ID="<client_id>"
export WORKOS_API_KEY="<api_key>"
export WORKOS_ORGANIZATION_ID="<org_id>"
export WORKOS_REDIRECT_URI="http://localhost:4587/callback"
```

2. Build and open authorization URL:

```bash
AUTH_URL="https://api.workos.com/user_management/authorize?client_id=${WORKOS_CLIENT_ID}&provider=authkit&response_type=code&organization_id=${WORKOS_ORGANIZATION_ID}&redirect_uri=$(python3 - <<'PY'
import urllib.parse, os
print(urllib.parse.quote(os.environ['WORKOS_REDIRECT_URI'], safe=''))
PY
)"

echo "$AUTH_URL"
```

3. Sign in as tenant admin, then copy `code` from callback URL.

4. Exchange code for access token and write token file:

```bash
read -r -p "Paste WorkOS authorization code: " WORKOS_AUTH_CODE

curl -sS https://api.workos.com/user_management/authenticate \
  -H "Content-Type: application/json" \
  -d "{\"client_id\":\"${WORKOS_CLIENT_ID}\",\"client_secret\":\"${WORKOS_API_KEY}\",\"grant_type\":\"authorization_code\",\"code\":\"${WORKOS_AUTH_CODE}\"}" \
  | jq -r '.access_token' > "$THOTH_ADMIN_BEARER_TOKEN_FILE"

chmod 600 "$THOTH_ADMIN_BEARER_TOKEN_FILE"
```

5. Validate token before use:

```bash
jq -R 'split(".") | .[1] | @base64d | fromjson' < "$THOTH_ADMIN_BEARER_TOKEN_FILE" | jq '{sub, org_id, exp, role, org_role, thoth_role}'
```

Token requirements:

1. `org_id` matches tenant WorkOS org.
2. role includes admin privileges (`role`, `org_role`, or `thoth_role`).
3. token is unexpired (`exp`).

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

## 7.1) Phase 1 Metadata Checks (Lineage + Broker)

For each blocked/stepped-up request, verify the event metadata includes:

1. `process_lineage.ancestor_hash` and top-level `lineage_hash`
2. `process_lineage.parent_pid` and top-level `lineage_parent_pid`
3. `secrets_broker.request_id` and top-level `broker_request_id`
4. `secrets_broker.target_host` and top-level `broker_destination_host`
5. `secrets_broker.injection_eligible` and `secrets_broker.host_allowed`

Quick check:

```bash
curl -sS -H "$AUTH" "${BASE}/violations?limit=200" | jq -r '
  .items[]? // .[]? |
  {
    event_id: (.event_id // .id // "n/a"),
    lineage_hash: (.metadata.lineage_hash // "missing"),
    lineage_parent_pid: (.metadata.lineage_parent_pid // "missing"),
    broker_request_id: (.metadata.broker_request_id // "missing"),
    broker_destination_host: (.metadata.broker_destination_host // "missing"),
    broker_host_allowed: (.metadata.secrets_broker.host_allowed // "missing"),
    broker_eligible: (.metadata.secrets_broker.injection_eligible // "missing")
  }'
```

Expected outcome:

1. all runtime-governed tool-call events include lineage fields
2. broker fields are present when target host is parsed
3. no credential values are present in any metadata field

## 7.2) Phase 2 Predicate Checks (Lineage + Intent Guardrails)

Enable deterministic preflight predicates in your test shell:

```bash
export THOTH_BLOCKED_LINEAGE_ANCESTOR_TOKENS="openclaw,banned_mcp"
export THOTH_BLOCKED_LINEAGE_UPSTREAM_BINARIES="openclaw"
export THOTH_INTENT_TOOL_ALLOWLIST="calendar_management=read_calendar|list_events,ticket_triage=create_ticket|update_ticket"
```

Then validate:

1. calls with blocked lineage ancestry return `BLOCK` with reason `lineage_ancestor_blocked`
2. calls with blocked upstream binary return `BLOCK` with reason `lineage_upstream_binary_blocked`
3. calls outside configured session-intent tool allowlist return `BLOCK` with reason `tool_not_allowed_for_session_intent`

Evidence query:

```bash
curl -sS -H "$AUTH" "${BASE}/violations?limit=200" | jq -r '
  .items[]? // .[]? |
  select(
    (.metadata.decision_reason_code // "") == "lineage_ancestor_blocked" or
    (.metadata.decision_reason_code // "") == "lineage_upstream_binary_blocked" or
    (.metadata.decision_reason_code // "") == "tool_not_allowed_for_session_intent"
  ) |
  {
    event_id: (.event_id // .id // "n/a"),
    reason: (.metadata.decision_reason_code // "missing"),
    lineage_hash: (.metadata.lineage_hash // "missing"),
    lineage_upstream_binary: (.metadata.lineage_upstream_binary // "missing"),
    session_intent: (.session_intent // .metadata.session_intent // "missing"),
    tool_name: (.tool_name // "missing")
  }'
```

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
