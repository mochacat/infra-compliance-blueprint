# ─────────────────────────────────────────────────────────────────────────────
# policies/ssm-contract.rego — OPA: SSM cross-layer contract enforcement
#
# Evaluated against a tofu plan JSON (--input) with the ssm-contract.yaml
# loaded as OPA data (--data). Prevents destroying an SSM parameter resource
# that downstream layers still depend on.
#
# Usage:
#   python3 -c "import yaml,json; print(json.dumps(yaml.safe_load(open('ssm-contract.yaml'))))" > /tmp/ssm-contract.json
#   opa eval --format pretty \
#     --data policies/ssm-contract.rego \
#     --data /tmp/ssm-contract.json \
#     --input plan.json \
#     "data.terraform.deny[x]"
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import future.keywords.if
import future.keywords.in

# ── Build a set of all SSM parameter paths that have downstream consumers ───

# Consumer paths from environment/BU entries.
# data.environments is a map of env_name → [bu_entry, ...].
# Each bu_entry has business_unit and layers (both casing as in YAML).
consumer_paths[path] if {
	some env_name, bu_entries in data.environments
	some bu_entry in bu_entries
	bu_name := bu_entry.business_unit

	some layer_name in bu_entry.layers
	template := data.template[layer_name]
	some consumed_key in template.consumes

	path := sprintf("/environments/%s/%s/%s", [env_name, bu_name, consumed_key])
}

# Consumer paths from infrastructure entries
consumer_paths[path] if {
	some infra_name, infra_data in data.infrastructure
	some layer_name, layer_data in infra_data

	some consumed_key in layer_data.consumes
	path := sprintf("/infrastructure/%s/%s", [infra_name, consumed_key])
}

# ── Deny rules ─────────────────────────────────────────────────────────────

# Deny destroying an SSM parameter resource if it's still consumed downstream
# Uses resource.change.before.name — when a resource is being deleted,
# .after is null/absent but .before.name still holds the parameter name.
deny[msg] if {
	some resource in input.resource_changes
	resource.change.actions[_] == "delete"
	resource.type == "aws_ssm_parameter"
	param_name := resource.change.before.name

	# Direct set lookup — same package, no data.terraform. prefix needed
	consumer_paths[param_name]

	msg := sprintf(
		"❌ Cannot delete SSM parameter '%s' — still consumed by downstream layer(s). See ssm-contract.yaml.",
		[param_name]
	)
}

# Also catch the case where after.name is non-null (update-with-recreate scenarios)
deny[msg] if {
	some resource in input.resource_changes
	resource.change.actions[_] == "delete"
	resource.type == "aws_ssm_parameter"
	param_name := resource.change.after.name

	consumer_paths[param_name]

	msg := sprintf(
		"❌ Cannot delete SSM parameter '%s' — still consumed by downstream layer(s). See ssm-contract.yaml.",
		[param_name]
	)
}
