# AWS XDR Integration

This Terraform project provisions the AWS resources required for a Cisco Secure Cloud Analytics / XDR integration.

## Overview

The configuration provisions:

- An IAM role and policy that Cisco Secure Cloud Analytics can assume
- A CloudWatch Logs group and supporting IAM permissions for Cisco-managed VPC Flow Log onboarding
- An S3 bucket for VPC Flow Logs
- VPC Flow Logs for a target VPC
- An S3 bucket for CloudTrail logs
- A KMS key and alias for CloudTrail encryption
- A CloudTrail trail for management events

## Files

- `main.tf` contains Terraform resources, variables, and outputs.
- `terraform.tfvars` contains environment-specific values.
- `deploy.sh` imports matching pre-existing AWS resources into Terraform state and then applies changes.

## Configuration

Set the required values in `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
vpc_id     = "vpc-06393f1da0e049d3e"

# Optional: explicitly add more VPCs for flow logs
# additional_vpc_ids = [
#   "vpc-0123456789abcdef0",
#   "vpc-0fedcba9876543210"
# ]
```

Optional overrides include:

- `role_name`
- `additional_vpc_ids`
- `vpc_flow_log_vpc_count`
- `vpc_flow_logs_bucket_name`
- `cloudtrail_bucket_name`
- `external_id`
- `flow_logs_cloudwatch_log_group_name`

For multi-VPC onboarding, the clearest option is to set `additional_vpc_ids` in [terraform.tfvars](/Users/bqamar/work-dev/AWS-XDR-integration/terraform.tfvars). Terraform always includes the primary `vpc_id`, then adds each VPC listed in `additional_vpc_ids`. All selected VPCs write to the same flow log bucket.

`vpc_flow_log_vpc_count` still defaults to `1`, which preserves single-VPC behavior. If `additional_vpc_ids` is empty, you can set `vpc_flow_log_vpc_count` to an integer from `1` to `100` to auto-select more VPCs from the same region. When `additional_vpc_ids` is provided, that explicit list takes precedence.

## Prerequisites

- Terraform installed
- AWS credentials configured for the target account
- At least one existing VPC in the target region
- Globally unique S3 bucket names

## Deployment

From this directory, the recommended command is:

```bash
./deploy.sh
```

`deploy.sh` will:

- Run `terraform init`
- Checks AWS for matching pre-existing resources
- Imports those resources into Terraform state when found
- Creates only the missing resources

You can also run Terraform manually:

```bash
terraform init
terraform plan
terraform apply
```

To skip the interactive approval step:

```bash
terraform apply -auto-approve
```

## Outputs

After `terraform apply`, Terraform prints values commonly needed in Cisco Secure Cloud Analytics, including:

- IAM role ARN
- VPC Flow Logs bucket name
- VPC Flow Log CloudWatch Logs group name
- CloudTrail Logs bucket name
- CloudTrail Logs bucket path

Terraform also writes `python_consumer_outputs.json`.

Example structure:

```json
{
  "aws_credentials": {
    "iam_role_arn": "arn:aws:iam::123456789012:role/obsrvbl-role-custom",
    "external_id": "cisco-explorcorp-earth"
  },
  "cloudtrail": {
    "logs_bucket_name": "example-cloudtrail-logs-bucket",
    "logs_bucket_path": "example-cloudtrail-logs-bucket/cloudtrail",
    "s3_path": "example-cloudtrail-logs-bucket/cloudtrail",
    "prefix": "cloudtrail"
  },
  "vpc_flow_logs": {
    "bucket_name": "example-vpc-flow-logs-bucket",
    "s3_path": "example-vpc-flow-logs-bucket",
    "cloudwatch_log_group": "/aws/vpc/flowlogs/cisco-secure-cloud-analytics",
    "vpc_ids": [
      "vpc-06393f1da0e049d3e"
    ]
  }
}
```

## Cleanup

Warning: `terraform destroy` is destructive. Use it only when you intend to permanently remove the provisioned AWS resources.

To remove the provisioned resources:

```bash
terraform destroy
```

The S3 buckets are configured with `force_destroy = true`, so Terraform will
remove bucket objects and versions during destroy instead of requiring manual
bucket cleanup.
