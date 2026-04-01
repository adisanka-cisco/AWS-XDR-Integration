aws_region = "us-east-1"
vpc_id     = "vpc-06393f1da0e049d3e"

# Optional overrides
# Preferred multi-VPC option: list the exact extra VPC IDs you want to onboard.
# additional_vpc_ids = [
#   "vpc-0123456789abcdef0",
#   "vpc-0fedcba9876543210"
# ]
#
# Legacy auto-select option: set this to an integer from 1 to 100 to enable
# flow logs for more VPCs discovered in the same region. This is only used when
# additional_vpc_ids is empty.
# vpc_flow_log_vpc_count = 5
role_name                 = "obsrvbl-role-custom"
vpc_flow_logs_bucket_name = "xdranalyticsflowlogsbucket"
cloudtrail_bucket_name    = "aws-cloudtrail-logs-933833866075-1168ac82"
external_id               = "cisco-explorcorp-earth"
