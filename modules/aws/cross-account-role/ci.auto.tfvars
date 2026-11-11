environment         = "dev"
name                = "log-reader"
source_account_arns = ["arn:aws:iam::111111111111:root"]
data_classification = "internal"
policy_statements = [
  {
    sid       = "ReadLogs"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::log-archive/*"]
  }
]
cost_controls = {
  cost_center  = "sec"
  project_code = "demo"
}
allowed_regions    = ["us-east-1", "us-west-2"]
default_tags       = {}
