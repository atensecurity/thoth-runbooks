// thoth_rule effect=BLOCK action_prefix=tool_call: purpose=customer-facing min_sensitivity=internal reason=Blocked_due_to_purpose_sensitivity_mismatch
// thoth_rule effect=STEP_UP action_prefix=tool_call: purpose=customer-facing min_sensitivity=internal reason=Customer_facing_access_requires_review
// thoth_rule effect=BLOCK min_behavioral_score=0.95 reason=Critical_behavioral_anomaly_block

permit (
  principal,
  action,
  resource
)
when {
  context.principal_id != "" &&
  context.action != "" &&
  context.task_id != ""
};

forbid (
  principal,
  action,
  resource
)
when {
  context.purpose == "customer-facing" &&
  (
    context.sensitivity_label == "internal" ||
    context.sensitivity_label == "confidential" ||
    context.sensitivity_label == "restricted"
  )
};

forbid (
  principal,
  action,
  resource
)
when {
  context.behavioral_score >= 0.95
};
