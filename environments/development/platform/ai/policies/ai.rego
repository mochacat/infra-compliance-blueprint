# ─────────────────────────────────────────────────────────────────────────────
# AI terraservice — OPA rules
#
# Pillar 3: SageMaker must always be VpcOnly (no public access).
# ─────────────────────────────────────────────────────────────────────────────

package terraform.deny.ai

default deny = false

# The sagemaker-domain module enforces VpcOnly internally, but this rule
# catches any attempt to set public access at the terraservice level.
deny = "SageMaker Domain must be VpcOnly" {
  input.terraform_config.variable.sagemaker_domain.value != "VpcOnly"
}
