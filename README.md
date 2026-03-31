# AWS XDR Integration

This Terraform project provisions the AWS-side resources needed for a Cisco Secure Cloud Analytics / XDR integration.

It creates:

- An IAM role and policy that Cisco Secure Cloud Analytics can assume
- An S3 bucket for VPC Flow Logs
- VPC Flow Logs for a target VPC
- An S3 bucket for CloudTrail logs
- A KMS key and alias for CloudTrail encryption
- A CloudTrail trail for management events

## Files

- `main.tf`: Terraform resources, variables, and outputs
- `terraform.tfvars`: Environment-specific variable values
- `deploy.sh`: Imports matching pre-existing AWS resources into Terraform state, then applies changes

## Required Inputs

Update `terraform.tfvars` with values for your environment:

```hcl
aws_region = "us-east-1"
vpc_id     = "vpc-06393f1da0e049d3e"
```

You can also override optional values such as:

- `vpc_flow_logs_bucket_name`
- `cloudtrail_bucket_name`
- `external_id`

## Prerequisites

- Terraform installed
- AWS credentials configured for the target account
- An existing VPC in the target region
- Globally unique S3 bucket names

## Usage

From this directory, the safest option is:

```bash
./deploy.sh
```

That script:

- Runs `terraform init`
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

After `terraform apply`, Terraform prints values you can use in Cisco Secure Cloud Analytics, including:

- IAM role ARN
- VPC Flow Log S3 bucket path
- CloudTrail S3 path
- CloudTrail bucket name and prefix

## Cleanup

To remove the provisioned resources:

```bash
terraform destroy
```
