# ─────────────────────────────────────────────────────────────────────────────
# Organization
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Enable AWS service access for services that need it at org level
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "s3.amazonaws.com",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Organizational Units
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_organizations_organizational_unit" "infra_control_plane" {
  name      = "Infra-Control-Plane"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "infra_control_plane_network" {
  name      = "Network"
  parent_id = aws_organizations_organizational_unit.infra_control_plane.id
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "prod_platform" {
  name      = "Platform"
  parent_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_organizational_unit" "prod_research" {
  name      = "Research"
  parent_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_organizational_unit" "prod_data" {
  name      = "DataPlatform"
  parent_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_organizational_unit" "preprod" {
  name      = "Pre-Production"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "preprod_platform" {
  name      = "Platform"
  parent_id = aws_organizations_organizational_unit.preprod.id
}

resource "aws_organizations_organizational_unit" "preprod_research" {
  name      = "Research"
  parent_id = aws_organizations_organizational_unit.preprod.id
}

resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "dev_platform" {
  name      = "Platform"
  parent_id = aws_organizations_organizational_unit.development.id
}

resource "aws_organizations_organizational_unit" "dev_research" {
  name      = "Research"
  parent_id = aws_organizations_organizational_unit.development.id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}