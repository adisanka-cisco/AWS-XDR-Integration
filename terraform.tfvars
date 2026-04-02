# User-editable environment settings for this deployment.
# Update this file to choose the AWS region and optional overrides such as
# explicit VPC selection, role naming, and log bucket names.

aws_region = "us-east-1"

# Optional overrides
# Optional override: send flow logs only for these VPCs instead of using the
# default discovered VPC list for the configured region.
# vpc_ids = [
#   "vpc-0123456789abcdef0",
#   "vpc-0fedcba9876543210"
# ]
role_name                 = "obsrvbl-role-custom"
vpc_flow_logs_bucket_name = "xdranalyticsflowlogsbucket"
cloudtrail_bucket_name    = "aws-cloudtrail-logs-933833866075-1168ac82"
# Required: set this to your Secure Cloud Analytics org name.
external_id               = ""
