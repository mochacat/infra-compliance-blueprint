# region-gate tests — unapproved region is rejected (Pillar 4)
#
# Both the check block (region_approved) and the VPC module's lifecycle
# precondition fire. The run is expected to "fail" — which is the verification.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

run "fail_unapproved_region" {
  command = plan

  variables {
    environment        = "prod"
    name               = "network-hub"
    region             = "us-east-2"
    data_classification = "internal"
    vpc_cidr           = "100.64.0.0/24"
    transit_gateway_id = "tgw-0123456789abcdef0"
    spoke_cidrs        = []
  }
}
