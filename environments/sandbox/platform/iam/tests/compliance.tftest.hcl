# sandbox/platform/iam — compliance gate tests

run "plan_without_boundary" {
  command = plan

  variables {
    business_unit            = "platform"
    environment              = "dev"
    region                   = "us-east-1"
    permissions_boundary_arn = null
    data_classification      = "internal"
  }

  # The iam-role module does not require a permissions boundary in dev (only prod)
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == false
    error_message = "Permissions boundary should be null in dev"
  }
}
