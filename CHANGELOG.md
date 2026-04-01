# Changelog

## v3 - 2026-04-01

- Moved the default Terraform-applied policies into checked-in JSON templates under `policies/`.
- Kept the IAM trust policy Terraform-native while externalizing the main Cisco role policy, VPC Flow Logs bucket policy, CloudTrail bucket policy, and CloudTrail KMS key policy.
- Updated Terraform to render those policy files with live account, region, ARN, and prefix values through `templatefile(...)`.
- Updated the README to document file-based policy customization and the new `policies/` layout.

## v2 - 2026-04-01

- Renamed the Cisco integration role to `obsrvbl-role-custom` and updated the generated outputs to use it consistently.
- Added support for Cisco-managed VPC flow log onboarding, including CloudWatch Logs permissions and helper log group output.
- Expanded IAM access for S3-backed flow log and CloudTrail validation, including S3 object reads and CloudTrail KMS decrypt permissions.
- Reorganized `python_consumer_outputs.json` into intuitive `aws_credentials`, `cloudtrail`, and `vpc_flow_logs` sections for Cisco copy/paste workflows.
- Added an explicit `additional_vpc_ids` input so multi-VPC onboarding is configured by listing exact VPC IDs instead of relying only on auto-selection by count.
- Improved destroy behavior so versioned S3 buckets are emptied and deleted automatically during `terraform destroy`.
