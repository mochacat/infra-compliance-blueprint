# Basic usage — attach a workload VPC to the Network Hub Transit Gateway.
#
# This example assumes a `vpc` module already produced the VPC + TGW-tier
# subnets, and that the Network Hub terraservice has already created the
# Transit Gateway in the network-hub account.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# The workload VPC (from the vpc module — shown for reference).
module "vpc" {
  source = "../../vpc"

  environment         = var.environment
  name                = var.vpc_name
  region              = var.region
  cidr_block          = var.vpc_cidr_block
  data_classification = var.data_classification
  subnets = {
    tgw = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.40.100.0/24", "10.40.101.0/24"]
    }
  }
}

# The TGW attachment — connects this workload VPC to the hub.
module "tgw_attachment" {
  source = "../../transit-gateway-attachment"

  environment         = var.environment
  name                = "${var.environment}-${var.vpc_name}-tgw"
  region              = var.region
  transit_gateway_id  = var.transit_gateway_id
  vpc_id              = module.vpc.vpc_id
  subnet_ids = [
    module.vpc.subnet_ids["tgw-us-east-1a"],
    module.vpc.subnet_ids["tgw-us-east-1b"],
  ]

  # In prod, enable centralized network inspection:
  #   appliance_mode_support = "enable"
  #   default_route_table_association = false
  #   transit_gateway_route_table_id  = var.inspection_route_table_id

  data_classification = var.data_classification
  cost_controls = {
    cost_center  = var.cost_center
    project_code = var.project_code
  }
}