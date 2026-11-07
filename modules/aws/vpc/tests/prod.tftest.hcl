# Production plan test — strictest inputs. Flow logs enabled to an immutable
# cross-account audit bucket, PHI data with sovereign residency.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "prod"
  name        = "prod-vpc"
  region      = "us-east-1"
  cidr_block  = "10.10.0.0/16"
  # An existing hub/peer CIDR that does NOT overlap 10.10.0.0/16.
  reserved_cidrs      = ["10.0.0.0/16"]
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "prod-app"
  }
  flow_log_destination = {
    bucket_arn              = "arn:aws:s3:::org-audit-log-archive"
    bucket_owner_account_id = "012345678901"
  }
  subnets = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
    }
    tgw = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]
    }
  }
}

run "test_flow_log_enabled" {
  command = plan

  assert {
    condition     = length(aws_flow_log.vpc) == 1
    error_message = "Flow log must be created when a destination is set."
  }
  assert {
    condition     = aws_flow_log.vpc[0].traffic_type == "ALL"
    error_message = "Flow log must capture ALL traffic (Pillar 5 — Observability)."
  }
  # The dedicated flow-log IAM role must be provisioned alongside the flow log.
  # (flow_log_id / flow_log_role_arn outputs are plan-unknown ids, so assert on
  # the deterministic resource wiring and compliance_controls instead.)
  assert {
    condition     = length(aws_iam_role.flow_log) == 1
    error_message = "Flow log must have a dedicated IAM role."
  }
  assert {
    condition     = output.compliance_controls.flow_log_destination == "immutable-s3"
    error_message = "compliance_controls must report immutable-s3 flow log wiring."
  }
}

run "test_flow_log_parquet_destination" {
  command = plan

  assert {
    condition     = aws_flow_log.vpc[0].destination_options[0].file_format == "parquet"
    error_message = "Flow log must write parquet for Athena querying (Pillar 5 — Observability / Pillar 8 — Auditability & Immutability)."
  }
  assert {
    condition     = aws_flow_log.vpc[0].log_destination == "arn:aws:s3:::org-audit-log-archive"
    error_message = "Flow log must point at the immutable audit bucket."
  }
}

run "test_phi_sovereign_passes" {
  command = plan

  # PHI + sovereign_only=true must NOT trip the residency precondition.
  assert {
    condition     = output.compliance_controls.data_classification == "phi"
    error_message = "compliance_controls must reflect phi."
  }
  assert {
    condition     = output.compliance_controls.flow_log_destination == "immutable-s3"
    error_message = "Flow log state must report immutable-s3 when destination set."
  }
}

run "test_iam_role_scoped_to_bucket" {
  command = plan

  # The flow-log IAM policy must scope s3:PutObject to exactly the destination
  # bucket ARN — no bare "*" resources on the delivery statement.
  assert {
    condition     = !strcontains(aws_iam_role_policy.flow_log_s3[0].policy, "\"Resource\": \"*\"")
    error_message = "Flow log role policy must not use a wildcard S3 resource."
  }
}