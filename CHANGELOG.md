# Changelog

## v2 - 2026-04-01

- Renamed the Cisco integration role to `obsrvbl-role-custom` and updated the generated outputs to use it consistently.
- Added support for Cisco-managed VPC flow log onboarding, including CloudWatch Logs permissions and helper log group output.
- Expanded IAM access for S3-backed flow log and CloudTrail validation, including S3 object reads and CloudTrail KMS decrypt permissions.
- Reorganized `python_consumer_outputs.json` into intuitive `aws_credentials`, `cloudtrail`, and `vpc_flow_logs` sections for Cisco copy/paste workflows.
- Improved destroy behavior so versioned S3 buckets are emptied and deleted automatically during `terraform destroy`.
