# AWS XDR Integration

This Terraform project provisions the AWS resources required for a Cisco Secure Cloud Analytics / XDR integration.

## Overview

The configuration provisions:

- An IAM role and policy that Cisco Secure Cloud Analytics can assume
- A CloudWatch Logs group and supporting IAM permissions for Cisco-managed VPC Flow Log onboarding
- An S3 bucket for VPC Flow Logs
- VPC Flow Logs for discovered or explicitly selected VPCs
- An S3 bucket for CloudTrail logs
- A KMS key and alias for CloudTrail encryption
- A CloudTrail trail for management events

## Files

- `main.tf` contains Terraform resources, variables, and outputs.
- `policies/` contains the default JSON policy templates applied to the IAM role, S3 buckets, and CloudTrail KMS key.
- `terraform.tfvars` contains environment-specific values.
- `deploy.sh` imports matching pre-existing AWS resources into Terraform state and then applies changes.

## Quick Start

1. Download or clone this repository to your local machine.
2. Change into the repository directory.
3. Install Terraform using your platform's package manager or the official Terraform installation instructions.
4. Install the AWS CLI using your platform's package manager or the official AWS CLI installation instructions.
5. Verify both tools are available in your terminal:

```bash
terraform version
aws --version
```

6. Authenticate the AWS CLI using your organization's normal login process for the target account, then confirm the current terminal session has valid AWS access:

```bash
aws sts get-caller-identity
```

7. Review `terraform.tfvars` and update any optional overrides you want to use, including `aws_region` if you want to deploy outside the default region.
8. Set `external_id` in `terraform.tfvars` to the customer's Secure Cloud Analytics org name. This value is required.
9. Run `./deploy.sh`.
10. If `external_id` is blank in `terraform.tfvars`, `deploy.sh` will prompt for it in the terminal and use the value you enter for that run only.
11. Wait about 5 minutes for fresh logs to land in S3 before trying the Cisco Secure Cloud Analytics integration.
12. Use the console output or `python_consumer_outputs.json` when entering values in Cisco.

If `deploy.sh` is not executable in your local environment, run:

```bash
chmod +x deploy.sh
```

## Configuration

`terraform.tfvars` is the main place for environment-specific settings and optional overrides. In many cases, the default values are enough and you may not need to change anything beyond the required `external_id`.

You can also override the deployment region here by changing `aws_region`. The AWS provider in [main.tf](/Users/bqamar/work-dev/AWS-XDR-integration/main.tf) uses that value directly, so the deploy script and Terraform resource lookups will follow the region you set.

Example optional overrides:

```hcl
aws_region = "us-east-1"
external_id = "your-sca-org-name"

# Optional override: send flow logs only for these VPCs
# vpc_ids = [
#   "vpc-0123456789abcdef0",
#   "vpc-0fedcba9876543210"
# ]
```

Optional overrides include:

- `aws_region`
- `role_name`
- `vpc_ids`
- `vpc_flow_logs_bucket_name`
- `cloudtrail_bucket_name`
- `flow_logs_cloudwatch_log_group_name`

Required user input:

- `external_id`

Set `external_id` in [terraform.tfvars](/Users/bqamar/work-dev/AWS-XDR-integration/terraform.tfvars) to the customer's Secure Cloud Analytics org name. If you leave it blank and use [deploy.sh](/Users/bqamar/work-dev/AWS-XDR-integration/deploy.sh), the script will prompt for the value and use it only for that run.

By default, Terraform discovers all VPCs visible to the configured AWS credentials in the target region and enables flow logs for up to 100 of them. All selected VPCs write to the same flow log bucket.

If you want to use a specific subset instead, set `vpc_ids` in [terraform.tfvars](/Users/bqamar/work-dev/AWS-XDR-integration/terraform.tfvars). When `vpc_ids` is provided, Terraform uses exactly that list instead of the default discovery behavior. Single-VPC environments still work naturally because the discovered list may contain only one VPC.

Policy customization in `v3` is file-based. The default policies live in `policies/`, and users can modify those checked-in JSON files directly when they need to adjust the permissions applied by Terraform.

## Prerequisites

- Terraform installed and available on `PATH`
- AWS CLI installed and available on `PATH`
- Valid AWS CLI credentials for the target account in the current terminal session
- `external_id` set to the customer's Secure Cloud Analytics org name in `terraform.tfvars`, or provided interactively when `./deploy.sh` prompts for it
- AWS permissions to create, update, and destroy the IAM, S3, KMS, CloudTrail, CloudWatch Logs, and EC2 Flow Log resources used by this deployment
- At least one existing VPC in the target region
- Globally unique S3 bucket names

## Deployment

From this directory, the recommended command is:

```bash
./deploy.sh
```

`deploy.sh` will:

- Run `terraform init`
- Check AWS for matching pre-existing resources
- Import those resources into Terraform state when found
- Create only the missing resources

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

If you customize any files in `policies/`, review the diff carefully before applying so you understand exactly which permissions will change.

After a fresh deploy or redeploy, wait about 5 minutes before trying the Cisco Secure Cloud Analytics integration. This gives AWS time to deliver fresh VPC Flow Log and CloudTrail objects so Cisco validation does not fail on timing alone.

## Outputs

Running `./deploy.sh` gives you two output formats for the provisioned integration details:

- a console summary with the key Terraform outputs needed for Cisco Secure Cloud Analytics
- a structured JSON file, `python_consumer_outputs.json`, for copy/paste or automation

The console output includes values commonly needed in Cisco Secure Cloud Analytics, including:

- IAM role ARN
- VPC Flow Logs bucket name
- VPC Flow Log CloudWatch Logs group name
- Selected VPC IDs
- CloudTrail Logs bucket name
- CloudTrail Logs bucket path

The JSON file groups the same information into sections for:

- `aws_credentials`
- `cloudtrail`
- `vpc_flow_logs`

Example structure:

```json
{
  "aws_credentials": {
    "iam_role_arn": "arn:aws:iam::123456789012:role/obsrvbl-role-custom",
    "external_id": "your-sca-org-name"
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
