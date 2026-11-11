# CIDR overlap test — standalone file
#
# Tests that the VPC module rejects overlapping CIDRs at plan time via its
# lifecycle precondition on aws_vpc. This is a precondition error, not an
# expect_failures check, so it lives in its own file to isolate the expected
# "fail" status from the other compliance tests.
#
# The "fail" status IS the verification: tofu test reports "fail" because the
# precondition error terminates the plan, which is exactly the behavior we
# want for overlapping CIDRs.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

run "fail_cidr_overlap_with_spoke" {
  command = plan

  variables {
    environment        = "prod"
    name               = "network-hub"
    region             = "us-east-1"
    data_classification = "internal"
    vpc_cidr           = "10.0.0.0/16"  # overlaps with dev-platform
    transit_gateway_id = "tgw-0123456789abcdef0"
    spoke_cidrs = [
      { name = "dev-platform", cidr = "10.0.0.0/16" },
    ]
  }
}
