environment         = "dev"
region              = "us-east-1"
name                = "demo-s3-bucket"
kms_key_arn         = "arn:aws:kms:us-east-1:111111111111:key/aaaa-bbbb-cccc-dddd"
data_classification = "internal"
data_residency      = {}
cost_controls       = { cost_center = "sec", project_code = "demo" }
allowed_regions    = ["us-east-1", "us-west-2"]
default_tags       = {}
