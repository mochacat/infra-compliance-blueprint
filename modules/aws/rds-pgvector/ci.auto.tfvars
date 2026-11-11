environment         = "dev"
name                = "sample-pgvector"
region              = "us-east-1"
kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:app-db-creds"
data_classification = "internal"
network = {
  vpc_id       = "vpc-0a1b2c3d4e5f67890"
  subnet_ids   = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
  private_only = true
}
allowed_regions    = ["us-east-1", "us-west-2"]
default_tags       = {}
