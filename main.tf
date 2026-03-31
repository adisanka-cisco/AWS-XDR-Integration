terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
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
}

variable "vpc_id" {
  description = "ID of the VPC to enable flow logs on"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role to be assumed by Secure Cloud Analytics"
  type        = string
  default     = "obsrvbl-role"
}

variable "policy_name" {
  description = "Name of the managed IAM policy attached to the Secure Cloud Analytics role"
  type        = string
  default     = "CustomXDRAnalyticsRole"
}

variable "trusted_account_id" {
  description = "Cisco Secure Cloud Analytics AWS account ID"
  type        = string
  default     = "757972810156"
}

variable "external_id" {
  description = "Secure Cloud Analytics portal name used as the IAM External ID"
  type        = string
  default     = "cisco-explorcorp-earth"
}

variable "vpc_flow_logs_bucket_name" {
  description = "Name of the S3 bucket used to store VPC Flow Logs"
  type        = string
  default     = "xdranalyticsflowlogsbucket"
}

variable "cloudtrail_bucket_name" {
  description = "Dedicated S3 bucket name for CloudTrail logs"
  type        = string
  default     = "xdranalyticscloudtrailbucket"
}

variable "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "xdranalyticscloudtrail"
}

variable "cloudtrail_kms_alias_name" {
  description = "Alias name for the KMS key used by CloudTrail"
  type        = string
  default     = "alias/xdranalyticscloudtrail"
}

variable "cloudtrail_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
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

data "aws_vpc" "target" {
  id = var.vpc_id
}

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
}

locals {
  custom_xdr_analytics_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:Describe*",
          "cloudtrail:LookupEvents",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "ec2:Describe*",
          "ecs:List*",
          "ecs:Describe*",
          "elasticache:Describe*",
          "elasticache:List*",
          "elasticloadbalancing:Describe*",
          "guardduty:Get*",
          "guardduty:List*",
          "iam:Get*",
          "iam:List*",
          "inspector:*",
          "rds:Describe*",
          "rds:List*",
          "redshift:Describe*",
          "workspaces:Describe*",
          "route53:List*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:Describe*",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:PutSubscriptionFilter",
          "logs:DeleteSubscriptionFilter"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "CloudCompliance"
        Action = [
          "access-analyzer:ListAnalyzers",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTags",
          "cloudwatch:DescribeAlarmsForMetric",
          "config:Get*",
          "config:Describe*",
          "ec2:GetEbsEncryptionByDefault",
          "iam:GenerateCredentialReport",
          "kms:GetKeyRotationStatus",
          "kms:ListKeys",
          "logs:DescribeMetricFilters",
          "organizations:ListPolicies",
          "s3:GetAccelerateConfiguration",
          "s3:GetAccessPoint",
          "s3:GetAccessPointPolicy",
          "s3:GetAccessPointPolicyStatus",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetAnalyticsConfiguration",
          "s3:GetBucket*",
          "s3:GetEncryptionConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetMetricsConfiguration",
          "s3:GetObjectAcl",
          "s3:GetObjectVersionAcl",
          "s3:GetReplicationConfiguration",
          "s3:ListAccessPoints",
          "s3:ListAllMyBuckets",
          "securityhub:Get*",
          "sns:ListSubscriptionsByTopic"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  }
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
  name        = var.policy_name
  policy      = jsonencode(local.custom_xdr_analytics_role_policy)

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

########################################
# Step 2 - VPC Flow Logs bucket + policy + flow log
########################################

resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = var.vpc_flow_logs_bucket_name

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

data "aws_iam_policy_document" "vpc_flow_logs_bucket_policy" {
  statement {
    sid    = "AllowBucketAccessFromSpecificIPs"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.vpc_flow_logs.arn
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = var.sca_allowed_source_ips
    }
  }

  statement {
    sid    = "AllowObjectAccessFromSpecificIPs"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.vpc_flow_logs.arn}/*"
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = var.sca_allowed_source_ips
    }
  }

  statement {
    sid    = "AWSLogDeliveryCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.vpc_flow_logs.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.vpc_flow_logs.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_bucket_policy.json
}

resource "aws_flow_log" "vpc_flow_logs" {
  vpc_id               = data.aws_vpc.target.id
  traffic_type         = var.flow_log_traffic_type
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.vpc_flow_logs.arn

  tags = {
    Name        = "vpc-flowlogs-${data.aws_vpc.target.id}"
    ManagedBy   = "Terraform"
    Destination = aws_s3_bucket.vpc_flow_logs.bucket
    Integration = "Cisco Secure Cloud Analytics"
  }
}

########################################
# Step 3 - CloudTrail bucket + KMS + trail
########################################

resource "aws_s3_bucket" "cloudtrail" {
  bucket = var.cloudtrail_bucket_name

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

data "aws_iam_policy_document" "cloudtrail_kms" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailToGenerateDataKeys"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.cloudtrail_name}"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
      ]
    }
  }
}

resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail trail ${var.cloudtrail_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cloudtrail_kms.json

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

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.cloudtrail.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.cloudtrail_name}"
      ]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/${var.cloudtrail_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.cloudtrail_name}"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

resource "aws_cloudtrail" "this" {
  depends_on = [aws_s3_bucket_policy.cloudtrail]

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

output "role_arn" {
  description = "Paste into Secure Cloud Analytics > Settings > Integrations > AWS > Credentials"
  value       = aws_iam_role.sca_role.arn
}

output "vpc_flow_log_s3_path" {
  description = "Paste into Secure Cloud Analytics > AWS > VPC Flow Logs > S3 Path"
  value       = aws_s3_bucket.vpc_flow_logs.bucket
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

output "target_vpc_id" {
  description = "Target VPC ID"
  value       = data.aws_vpc.target.id
}
