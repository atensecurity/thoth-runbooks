package thoth.policies.least_privilege_analyst

# thoth_rule effect=STEP_UP action_prefix=tool_call:query_ purpose=internal min_sensitivity=confidential reason=High_sensitivity_query_requires_step_up
# thoth_rule effect=BLOCK action_prefix=tool_call:query_ purpose=customer-facing min_sensitivity=internal reason=Customer_facing_query_blocked_for_non_public_data

default allow := false

# Allow only specific analyst-oriented tool classes.
allow if {
  input.principal.id != ""
  startswith(input.action, "tool_call:query_")
  input.context.purpose == "internal"
  input.context.sensitivity_label == "internal"
}

allow if {
  input.principal.id != ""
  startswith(input.action, "tool_call:search_")
  input.context.purpose == "internal"
}

# Escalate when confidential data is requested even for internal use.
deny[msg] if {
  input.principal.id != ""
  startswith(input.action, "tool_call:query_")
  input.context.purpose == "internal"
  input.context.sensitivity_label == "confidential"
  msg := "confidential analyst query requires step-up review"
}
