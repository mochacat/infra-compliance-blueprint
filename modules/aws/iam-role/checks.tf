# ─────────────────────────────────────────────────────────────────────────────
# Run-time check: wildcard resource validation
#
# The variable validation block can't reference other variables, so this
# check block evaluates at plan time instead. It produces a warning-level
# status rather than blocking plan entirely.
#
# The allowed_resource_wildcards variable lists SIDs that are intentionally
# allowed to use "*" in their resources (e.g. aoss:APIAccessAll scoped at
# the collection access policy level rather than IAM).
# ─────────────────────────────────────────────────────────────────────────────

check "wildcard_resources" {
  assert {
    condition = alltrue([
      for st in var.policy_statements :
      contains(st.resources, "*") ? (
        var.allowed_resource_wildcards != null && contains(var.allowed_resource_wildcards, st.sid)
      ) : true
    ])
    error_message = "Wildcard Resource (*) found in policy_statements without being listed in allowed_resource_wildcards (Pillar 2)."
  }
}
