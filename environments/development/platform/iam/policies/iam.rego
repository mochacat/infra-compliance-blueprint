# ─────────────────────────────────────────────────────────────────────────────
# IAM terraservice — OPA rules
#
# Pillar 2: Every role must have scoped policies, permissions boundary in prod.
# Pillar 9: compliance_controls output must reflect environment.
# ─────────────────────────────────────────────────────────────────────────────

package terraform.deny.iam

default deny = false

# Fail if no permissions boundary in prod
deny = "Permissions boundary is required for prod IAM roles" {
  input.terraform_config.resource.aws_iam_role[name]
  input.terraform_config.variable.environment.value == "prod"
  not input.terraform_config.variable.permissions_boundary_arn.value
}
