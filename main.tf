########################################
# Primary Terraform configuration
# Edit this file when changing managed AWS resources, outputs, or how the
# policy templates are wired into the deployment.
########################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

########################################
# Variables
########################################

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region must be a non-empty AWS region string such as us-east-1."
  }
}

variable "vpc_ids" {
  description = "Optional explicit list of VPC IDs to enable flow logs on instead of using the default discovered VPC list"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.vpc_ids : can(regex("^vpc-[0-9a-f]+$", id))
    ])
    error_message = "vpc_ids must contain only valid AWS VPC IDs, for example vpc-0123456789abcdef0."
  }

  validation {
    condition     = length(distinct(var.vpc_ids)) == length(var.vpc_ids)
    error_message = "vpc_ids must not contain duplicates."
  }

  validation {
    condition     = length(var.vpc_ids) <= 100
    error_message = "vpc_ids can contain at most 100 VPC IDs."
  }
}

variable "role_name" {
  description = "Name of the IAM role to be assumed by Secure Cloud Analytics"
  type        = string
  default     = "obsrvbl-role-custom"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "role_name must be 1 to 64 characters and use only valid IAM role name characters."
  }
}

variable "policy_name" {
  description = "Name of the managed IAM policy attached to the Secure Cloud Analytics role"
  type        = string
  default     = "CustomXDRAnalyticsRole"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.policy_name))
    error_message = "policy_name must be 1 to 128 characters and use only valid IAM policy name characters."
  }
}

variable "trusted_account_id" {
  description = "Cisco Secure Cloud Analytics AWS account ID"
  type        = string
  default     = "757972810156"
}

variable "external_id" {
  description = "Secure Cloud Analytics org name used as the IAM External ID"
  type        = string

  validation {
    condition     = length(trimspace(var.external_id)) > 0
    error_message = "external_id must be a non-empty string."
  }
}

variable "vpc_flow_logs_bucket_name" {
  description = "Name of the S3 bucket used to store VPC Flow Logs"
  type        = string
  default     = "xdranalyticsflowlogsbucket"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.vpc_flow_logs_bucket_name))
    error_message = "vpc_flow_logs_bucket_name must be a valid S3 bucket name using lowercase letters, numbers, dots, and hyphens."
  }
}

variable "cloudtrail_bucket_name" {
  description = "Dedicated S3 bucket name for CloudTrail logs"
  type        = string
  default     = "xdranalyticscloudtrailbucket"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.cloudtrail_bucket_name))
    error_message = "cloudtrail_bucket_name must be a valid S3 bucket name using lowercase letters, numbers, dots, and hyphens."
  }
}

variable "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "xdranalyticscloudtrail"

  validation {
    condition     = length(trimspace(var.cloudtrail_name)) > 0
    error_message = "cloudtrail_name must be a non-empty string."
  }
}

variable "cloudtrail_kms_alias_name" {
  description = "Alias name for the KMS key used by CloudTrail"
  type        = string
  default     = "alias/xdranalyticscloudtrail"

  validation {
    condition     = can(regex("^alias/[A-Za-z0-9/_-]+$", var.cloudtrail_kms_alias_name))
    error_message = "cloudtrail_kms_alias_name must start with alias/ and contain only valid KMS alias characters."
  }
}

variable "cloudtrail_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"

  validation {
    condition     = length(trimspace(var.cloudtrail_prefix)) > 0 && !startswith(var.cloudtrail_prefix, "/")
    error_message = "cloudtrail_prefix must be a non-empty relative prefix and must not start with a slash."
  }
}

variable "cloudtrail_is_multi_region" {
  description = "Whether to create a multi-Region CloudTrail trail"
  type        = bool
  default     = true
}

variable "cloudtrail_include_global_service_events" {
  description = "Whether to include global service events in the trail"
  type        = bool
  default     = true
}

variable "flow_log_traffic_type" {
  description = "Traffic type for VPC Flow Logs"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be one of ACCEPT, REJECT, or ALL."
  }
}

variable "flow_logs_cloudwatch_log_group_name" {
  description = "CloudWatch Logs group name to support Cisco-managed VPC Flow Log onboarding"
  type        = string
  default     = "/aws/vpc/flowlogs/cisco-secure-cloud-analytics"

  validation {
    condition     = length(trimspace(var.flow_logs_cloudwatch_log_group_name)) > 0
    error_message = "flow_logs_cloudwatch_log_group_name must be a non-empty CloudWatch Logs group name."
  }
}

variable "flow_logs_cloudwatch_retention_in_days" {
  description = "Retention period for the CloudWatch Logs group used during Cisco-managed VPC Flow Log onboarding"
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096,
      1827, 2192, 2557, 2922, 3288, 3653
    ], var.flow_logs_cloudwatch_retention_in_days)
    error_message = "flow_logs_cloudwatch_retention_in_days must be a valid CloudWatch Logs retention value."
  }
}

variable "lifecycle_rule_name" {
  description = "Lifecycle rule name applied to both buckets"
  type        = string
  default     = "Expire after 1 day"
}

variable "sca_allowed_source_ips" {
  description = "Cisco Secure Cloud Analytics public IPs allowed to read from the flow log bucket"
  type        = list(string)
  default = [
    "3.105.113.178/32",
    "3.106.86.62/32",
    "13.236.79.226/32",
    "18.184.151.221/32",
    "18.184.200.206/32",
    "18.196.240.228/32",
    "44.225.21.192/32",
    "52.4.96.105/32",
    "52.37.150.195/32",
    "52.43.232.80/32",
    "52.44.231.95/32",
    "52.54.41.7/32",
    "52.55.87.127/32",
    "52.55.92.19/32",
    "52.88.92.109/32",
    "52.205.26.61/32"
  ]
}

########################################
# Data sources
########################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_vpcs" "available" {}

########################################
# Step 1 - IAM Role and Policy
########################################

data "aws_iam_policy_document" "sca_trust" {
  statement {
    sid     = "AllowCiscoSecureCloudAnalyticsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.trusted_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }

  # Cisco can assume this role to manage onboarding, and the VPC Flow Logs
  # service can also assume it when Cisco creates a CloudWatch-backed flow log
  # and passes this role as the delivery role.
  statement {
    sid     = "AllowVPCFlowLogsServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
      ]
    }
  }
}

locals {
  discovered_vpc_ids = slice(
    sort(data.aws_vpcs.available.ids),
    0,
    min(100, length(data.aws_vpcs.available.ids))
  )

  selected_vpc_ids = length(var.vpc_ids) > 0 ? var.vpc_ids : local.discovered_vpc_ids

  sca_role_policy = templatefile("${path.module}/policies/sca-role-policy.json", {
    account_id               = data.aws_caller_identity.current.account_id
    cloudtrail_bucket_arn    = aws_s3_bucket.cloudtrail.arn
    cloudtrail_kms_key_arn   = aws_kms_key.cloudtrail.arn
    partition                = data.aws_partition.current.partition
    role_name                = var.role_name
    vpc_flow_logs_bucket_arn = aws_s3_bucket.vpc_flow_logs.arn
  })

  vpc_flow_logs_bucket_policy = templatefile("${path.module}/policies/vpc-flow-logs-bucket-policy.json", {
    account_id               = data.aws_caller_identity.current.account_id
    partition                = data.aws_partition.current.partition
    region                   = data.aws_region.current.region
    source_ips               = var.sca_allowed_source_ips
    vpc_flow_logs_bucket_arn = aws_s3_bucket.vpc_flow_logs.arn
  })

  cloudtrail_kms_policy = templatefile("${path.module}/policies/cloudtrail-kms-policy.json", {
    account_id      = data.aws_caller_identity.current.account_id
    cloudtrail_name = var.cloudtrail_name
    partition       = data.aws_partition.current.partition
    region          = data.aws_region.current.region
    sca_role_arn    = aws_iam_role.sca_role.arn
  })

  cloudtrail_bucket_policy = templatefile("${path.module}/policies/cloudtrail-bucket-policy.json", {
    account_id            = data.aws_caller_identity.current.account_id
    cloudtrail_bucket_arn = aws_s3_bucket.cloudtrail.arn
    cloudtrail_name       = var.cloudtrail_name
    cloudtrail_prefix     = var.cloudtrail_prefix
    partition             = data.aws_partition.current.partition
    region                = data.aws_region.current.region
  })
}

resource "aws_iam_role" "sca_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.sca_trust.json

  tags = {
    Name        = var.role_name
    ManagedBy   = "Terraform"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

resource "aws_iam_policy" "sca_policy" {
  name   = var.policy_name
  policy = local.sca_role_policy

  tags = {
    Name        = var.policy_name
    ManagedBy   = "Terraform"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

resource "aws_iam_role_policy_attachment" "sca_policy_attach" {
  role       = aws_iam_role.sca_role.name
  policy_arn = aws_iam_policy.sca_policy.arn
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = var.flow_logs_cloudwatch_log_group_name
  retention_in_days = var.flow_logs_cloudwatch_retention_in_days

  tags = {
    Name        = var.flow_logs_cloudwatch_log_group_name
    ManagedBy   = "Terraform"
    Purpose     = "Cisco Secure Cloud Analytics VPC Flow Log Onboarding"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

########################################
# Step 2 - VPC Flow Logs bucket + policy + flow log
########################################

resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket        = var.vpc_flow_logs_bucket_name
  force_destroy = true

  # Flow log delivery can write late-arriving objects during teardown. Empty
  # all object versions immediately before bucket deletion so destroy succeeds
  # without a manual cleanup step.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE
      bucket="${self.bucket}"

      while true; do
        tmp="$(mktemp)"
        aws s3api list-object-versions --bucket "$bucket" --output json \
          | jq '{Objects: (((.Versions // []) + (.DeleteMarkers // []))[:1000] | map({Key, VersionId})), Quiet: true}' > "$tmp"

        if [ "$(jq '.Objects | length' "$tmp")" -eq 0 ]; then
          rm -f "$tmp"
          break
        fi

        aws s3api delete-objects --bucket "$bucket" --delete "file://$tmp" >/dev/null
        rm -f "$tmp"
      done
    EOT
  }

  tags = {
    Name        = var.vpc_flow_logs_bucket_name
    ManagedBy   = "Terraform"
    Purpose     = "Cisco Secure Cloud Analytics VPC Flow Logs"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

resource "aws_s3_bucket_versioning" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  policy = local.vpc_flow_logs_bucket_policy
}

resource "aws_flow_log" "vpc_flow_logs" {
  count                = length(local.selected_vpc_ids)
  vpc_id               = local.selected_vpc_ids[count.index]
  traffic_type         = var.flow_log_traffic_type
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.vpc_flow_logs.arn

  tags = {
    Name        = "vpc-flowlogs-${local.selected_vpc_ids[count.index]}"
    ManagedBy   = "Terraform"
    Destination = aws_s3_bucket.vpc_flow_logs.bucket
    Integration = "Cisco Secure Cloud Analytics"
  }

  lifecycle {
    precondition {
      condition     = length(local.selected_vpc_ids) > 0
      error_message = "No VPCs were selected for flow log creation. Ensure the AWS credentials can discover at least one VPC in the configured region or set vpc_ids in terraform.tfvars."
    }
  }
}

moved {
  from = aws_flow_log.vpc_flow_logs
  to   = aws_flow_log.vpc_flow_logs[0]
}

########################################
# Step 3 - CloudTrail bucket + KMS + trail
########################################

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = var.cloudtrail_bucket_name
  force_destroy = true

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE
      bucket="${self.bucket}"

      while true; do
        tmp="$(mktemp)"
        aws s3api list-object-versions --bucket "$bucket" --output json \
          | jq '{Objects: (((.Versions // []) + (.DeleteMarkers // []))[:1000] | map({Key, VersionId})), Quiet: true}' > "$tmp"

        if [ "$(jq '.Objects | length' "$tmp")" -eq 0 ]; then
          rm -f "$tmp"
          break
        fi

        aws s3api delete-objects --bucket "$bucket" --delete "file://$tmp" >/dev/null
        rm -f "$tmp"
      done
    EOT
  }

  tags = {
    Name        = var.cloudtrail_bucket_name
    ManagedBy   = "Terraform"
    Purpose     = "CloudTrail Logs"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail trail ${var.cloudtrail_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = local.cloudtrail_kms_policy

  tags = {
    Name        = var.cloudtrail_name
    ManagedBy   = "Terraform"
    Purpose     = "CloudTrail Encryption"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = var.cloudtrail_kms_alias_name
  target_key_id = aws_kms_key.cloudtrail.key_id
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = local.cloudtrail_bucket_policy
}

resource "aws_cloudtrail" "this" {
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  # This trail captures management events and writes them to the S3 bucket
  # and KMS key defined above, whether those resources were created or adopted.
  name                          = var.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = var.cloudtrail_prefix
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  include_global_service_events = var.cloudtrail_include_global_service_events
  is_multi_region_trail         = var.cloudtrail_is_multi_region
  enable_log_file_validation    = true
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name        = var.cloudtrail_name
    ManagedBy   = "Terraform"
    Purpose     = "CloudTrail"
    Integration = "Cisco Secure Cloud Analytics"
  }
}

########################################
# Step 4 - Lifecycle rules
########################################

resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    # Only noncurrent object versions expire automatically. Current log objects
    # remain available until a separate retention rule is added.
    id     = var.lifecycle_rule_name
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    # Only noncurrent object versions expire automatically. Current log objects
    # remain available until a separate retention rule is added.
    id     = var.lifecycle_rule_name
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

########################################
# Outputs
########################################

locals {
  python_consumer_outputs = {
    aws_credentials = {
      iam_role_arn = aws_iam_role.sca_role.arn
      external_id  = var.external_id
    }
    cloudtrail = {
      logs_bucket_name = aws_s3_bucket.cloudtrail.bucket
      logs_bucket_path = "${aws_s3_bucket.cloudtrail.bucket}/${var.cloudtrail_prefix}"
      s3_path          = "${aws_s3_bucket.cloudtrail.bucket}/${var.cloudtrail_prefix}"
      prefix           = var.cloudtrail_prefix
    }
    vpc_flow_logs = {
      bucket_name          = aws_s3_bucket.vpc_flow_logs.bucket
      s3_path              = aws_s3_bucket.vpc_flow_logs.bucket
      cloudwatch_log_group = aws_cloudwatch_log_group.vpc_flow_logs.name
      vpc_ids              = local.selected_vpc_ids
    }
  }
}

resource "local_file" "python_outputs" {
  filename = "${path.module}/python_consumer_outputs.json"
  content  = jsonencode(local.python_consumer_outputs)
}

output "role_arn" {
  description = "Paste into Secure Cloud Analytics > Settings > Integrations > AWS > Credentials"
  value       = aws_iam_role.sca_role.arn
}

output "vpc_flow_log_s3_path" {
  description = "Paste into Secure Cloud Analytics > AWS > VPC Flow Logs > S3 Path"
  value       = aws_s3_bucket.vpc_flow_logs.bucket
}

output "vpc_flow_log_cloudwatch_log_group_name" {
  description = "CloudWatch Logs group available if Cisco onboarding verifies or creates CloudWatch-backed flow logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "cloudtrail_s3_path" {
  description = "Paste into Secure Cloud Analytics > AWS > CloudTrail > S3 Path"
  value       = "${aws_s3_bucket.cloudtrail.bucket}/${var.cloudtrail_prefix}"
}

output "cloudtrail_log_bucket_name" {
  description = "CloudTrail log bucket name"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_log_prefix" {
  description = "CloudTrail log prefix"
  value       = var.cloudtrail_prefix
}

output "policy_arn" {
  description = "Managed IAM policy ARN attached to the Secure Cloud Analytics role"
  value       = aws_iam_policy.sca_policy.arn
}

output "target_vpc_ids" {
  description = "All VPC IDs selected for flow log creation"
  value       = local.selected_vpc_ids
}
