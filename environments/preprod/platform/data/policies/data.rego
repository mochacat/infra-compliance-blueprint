# ─────────────────────────────────────────────────────────────────────────────
# Data terraservice — OPA rules
#
# Pillar 1: KMS CMK required for all data stores.
# Pillar 6: deletion_protection must be true.
# ─────────────────────────────────────────────────────────────────────────────

package terraform.deny.data

default deny = false

# deletion_protection must be true in prod
deny = "deletion_protection must be true in prod" {
  input.terraform_config.variable.environment.value == "prod"
  input.terraform_config.variable.backup.value.deletion_protection == false
}
