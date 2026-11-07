# Minimal usage — a compliant multi-AZ private VPC with flow logs to an
# immutable audit bucket and a clear signal of which network the compute/data
# layers should use.

module "workload_vpc" {
  source = "../.."

  environment         = var.environment
  name                = var.name
  region              = var.region
  cidr_block          = var.cidr_block
  reserved_cidrs      = var.reserved_cidrs
  data_classification = var.data_classification
  data_residency      = var.data_residency

  # Flow logs are enabled only when an immutable audit bucket is wired up.
  flow_log_destination = var.audit_bucket_arn != null ? {
    bucket_arn              = var.audit_bucket_arn
    bucket_owner_account_id = "123456789012"
  } : null

  subnets = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.60.1.0/24", "10.60.2.0/24", "10.60.3.0/24"]
    }
    data = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.60.4.0/24", "10.60.5.0/24", "10.60.6.0/24"]
    }
  }

  cost_controls = {
    cost_center  = var.cost_center
    project_code = var.project_code
  }
}

# Downstream compute/data/GenAI modules consume private placement:
#   module "compute" { source = "git:..."; subnet_ids = module.workload_vpc.subnet_ids }