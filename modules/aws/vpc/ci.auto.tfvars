environment         = "dev"
name                = "sample-vpc"
region              = "us-east-1"
cidr_block          = "10.0.0.0/16"
data_classification = "internal"
data_residency = {
  sovereign_only = false
}
cost_controls = {
  cost_center  = "sec"
  project_code = "demo"
}
subnets = {
  app = {
    availability_zones = ["us-east-1a", "us-east-1b"]
    cidrs              = ["10.0.1.0/24", "10.0.2.0/24"]
  }
  data = {
    availability_zones = ["us-east-1a", "us-east-1b"]
    cidrs              = ["10.0.3.0/24", "10.0.4.0/24"]
  }
}
allowed_regions = ["us-east-1", "us-west-2"]
default_tags    = {}
