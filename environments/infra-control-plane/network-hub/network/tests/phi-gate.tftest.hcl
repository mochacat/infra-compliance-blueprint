# phi-gate tests — PHI without sovereign_only is rejected (Pillar 7)
#
# The VPC module's lifecycle precondition fires. The run is expected to
# "fail" — which is the verification.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment        = "prod"
    name               = "network-hub"
    region             = "us-east-1"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
    vpc_cidr           = "100.64.0.0/24"
    transit_gateway_id = "tgw-0123456789abcdef0"
    spoke_cidrs        = []
  }
}
