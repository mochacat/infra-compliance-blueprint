environment         = "dev"
region              = "us-east-1"
account_id          = "111111111111"
data_classification = "internal"
kms = {
  iam_principals = ["arn:aws:iam::111111111111:role/app-role"]
  admins         = ["arn:aws:iam::111111111111:role/app-admin"]
  alias_prefix   = "app-"
  description    = "test key"
}
data_residency = {
  sovereign_only = false
}
cost_controls = {
  cost_center  = "sec"
  project_code = "demo"
}
allowed_regions    = ["us-east-1", "us-west-2"]
default_tags       = {}
