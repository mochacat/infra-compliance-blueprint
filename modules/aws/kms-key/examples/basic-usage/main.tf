# Minimal usage — encrypt app data with a dedicated, compliant CMK.

module "app_key" {
  source = "../.."

  account_id          = var.account_id
  environment         = var.environment
  region              = "us-east-1"
  data_classification = var.data_classification
  data_residency      = var.data_residency

  kms = {
    alias_prefix   = ""
    description    = "${var.environment} application data key"
    iam_principals = [var.app_role_arn]
    admins         = [var.kms_admin_arn]
  }

  cost_controls = {
    cost_center  = var.cost_center
    project_code = var.project_code
  }
}

# The consuming resource takes the generated key ARN for encryption at rest.
# module "s3_bucket" {
#   source      = "git::.../s3-bucket?ref=v1.0.0"
#   kms_key_arn = module.app_key.key_arn  # <-- Pillar 1
#   ...
# }