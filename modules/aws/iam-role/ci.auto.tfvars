environment         = "dev"
name                = "app-role"
data_classification = "internal"
trust_policy        = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
policy_statements = [
  {
    sid       = "S3Read"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
  }
]
cost_controls = {
  cost_center  = "sec"
  project_code = "demo"
}
allowed_regions    = ["us-east-1", "us-west-2"]
default_tags       = {}
