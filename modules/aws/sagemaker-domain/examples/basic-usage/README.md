# SageMaker Domain (basic) — OpenTofu
#
# Usage:
#   tofu init
#   tofu plan  -var="kms_key_arn=arn:aws:kms:us-east-1:123456789012:key/xxx" \
#               -var="vpc_id=vpc-xxx" -var='subnet_ids=["subnet-1","subnet-2"]'
#
# This example is illustrative; the module is consumed via a
# `git::...?ref=vX.Y.Z` source in a real environment.