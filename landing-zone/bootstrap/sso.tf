# ─────────────────────────────────────────────────────────────────────────────
# IAM Identity Center (SSO) — optional
#
# Enabled only when var.sso_instance_arn is set. The instance itself must be
# created out-of-band (AWS CLI or console) because it requires an identity
# store that cannot be provisioned via tofu without additional setup.
#
#   aws sso-admin list-instances --query 'Instances[0].InstanceArn'
#
# This permission set is a bootstrap convenience for getting into new accounts.
# Replace it with least-privilege permission sets before onboarding a team —
# see landing-zone/reference/ARCHITECTURE.md.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "admin" {
  count = var.sso_instance_arn != null ? 1 : 0

  name             = "Admin"
  description      = "Bootstrap full admin access. Replace with least-privilege sets."
  instance_arn     = var.sso_instance_arn
  session_duration = "PT4H"
  tags             = local.default_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  count = var.sso_instance_arn != null ? 1 : 0

  instance_arn       = var.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin[0].arn
}