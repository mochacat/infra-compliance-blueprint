# ─────────────────────────────────────────────────────────────────────────────
# Member Accounts — worked example (greenfield only)
#
# This file is a REFERENCE showing how member accounts are provisioned into the
# OU structure created by main.tf. It is intentionally commented out because
# it is greenfield-specific and account-specific:
#
#   * aws_organizations_account requires a REAL, UNIQUE email address per
#     account. Each account receives an invitation at that address and must be
#     able to accept it — you cannot apply this with placeholder emails.
#   * Creating an account cannot be undone without closing it (a 90-day
#     process), so each entry should be deliberate, not automatic.
#   * The management account (the one tofu runs from) is already the org root —
#     it is NOT created here.
#
# To use as a worked example (greenfield teams only):
#   1. Decide your account inventory. The default layout provisions 9 accounts:
#      - infra-control-plane/    -> aws-security, aws-log-archive (Log Archive)
#      - infra-control-plane/network -> aws-network-hub
#      - production/             -> platform, research, data-platform
#      - pre-production/         -> platform, research
#      - development/            -> platform, research
#      - sandbox                 -> sandbox
#   2. Set up email aliases you control, e.g.:
#      aws-security@yourdomain.com, aws-log-archive@yourdomain.com,
#      aws-network-hub@yourdomain.com, production-platform@yourdomain.com, ...
#   3. Each entry's `parent_id` places it under the OU from main.tf; it then
#      inherits that OU's SCPs automatically (see the policy table in README.md).
#   4. Uncomment the resources you want and `tofu apply`. Start with security
#      and log-archive, then network-hub, then workload accounts.
#
# Teams that ALREADY have an organization should NOT uncomment these — see the
# "Greenfield only" note in the bootstrap README for the adopt/skip path.
# ─────────────────────────────────────────────────────────────────────────────

# ── Infra-Control-Plane ──

# resource "aws_organizations_account" "security" {
#   name                       = "security"
#   email                      = local.email["security"]
#   parent_id                  = aws_organizations_organizational_unit.infra_control_plane.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "log_archive" {
#   name                       = "log-archive"
#   email                      = local.email["log-archive"]
#   parent_id                  = aws_organizations_organizational_unit.infra_control_plane.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "network" {
#   name                       = "network-hub"
#   email                      = local.email["network"]
#   parent_id                  = aws_organizations_organizational_unit.infra_control_plane_network.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# ── Production ──

# resource "aws_organizations_account" "production_platform" {
#   name                       = "production-platform"
#   email                      = local.email["production-platform"]
#   parent_id                  = aws_organizations_organizational_unit.prod_platform.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "production_research" {
#   name                       = "production-research"
#   email                      = local.email["production-research"]
#   parent_id                  = aws_organizations_organizational_unit.prod_research.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "production_data" {
#   name                       = "production-data-platform"
#   email                      = local.email["production-data"]
#   parent_id                  = aws_organizations_organizational_unit.prod_data.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# ── Pre-Production ──

# resource "aws_organizations_account" "preprod_platform" {
#   name                       = "preprod-platform"
#   email                      = local.email["preprod-platform"]
#   parent_id                  = aws_organizations_organizational_unit.preprod_platform.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "preprod_research" {
#   name                       = "preprod-research"
#   email                      = local.email["preprod-research"]
#   parent_id                  = aws_organizations_organizational_unit.preprod_research.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# ── Development ──

# resource "aws_organizations_account" "dev_platform" {
#   name                       = "dev-platform"
#   email                      = local.email["development-platform"]
#   parent_id                  = aws_organizations_organizational_unit.dev_platform.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_organizations_account" "dev_research" {
#   name                       = "dev-research"
#   email                      = local.email["development-research"]
#   parent_id                  = aws_organizations_organizational_unit.dev_research.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# ── Sandbox ──

# resource "aws_organizations_account" "sandbox" {
#   name                       = "sandbox"
#   email                      = local.email["sandbox"]
#   parent_id                  = aws_organizations_organizational_unit.sandbox.id
#   role_name                  = "OrganizationAccountAccessRole"
#   iam_user_access_to_billing = "DENY"
#   tags                       = local.default_tags
#   lifecycle {
#     prevent_destroy = true
#   }
# }
