# production/data-platform/iam — compliance gate tests
#
# Verifies that a prod config, when given a permissions boundary, reports it
# in compliance_controls (Pillar 2 / Pillar 9). The iam-role module enforces
# the boundary via a lifecycle precondition (prod without a boundary fails at
# plan time); the deterministic role-name plan is covered by defaults.tftest.hcl.

run "prod_with_boundary_reports_it" {
  command = plan

  variables {
    business_unit            = "data-platform"
    environment              = "prod"
    region                   = "us-east-1"
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/ci-boundary"
    data_classification      = "internal"
  }

  assert {
    condition     = output.compliance_controls.permissions_boundary_set == true
    error_message = "compliance_controls must report the permissions boundary is set in prod"
  }
}
