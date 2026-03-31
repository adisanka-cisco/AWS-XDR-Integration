#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

# Expired shell credentials caused earlier runs to fail, so the wrapper always
# falls back to the working AWS CLI configuration on disk.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE

# Ignore any machine-wide Terraform mirror override and use a temporary empty
# CLI config so provider installation behaves consistently.
tmp_tf_cli_config="$(mktemp)"
trap 'rm -f "$tmp_tf_cli_config"' EXIT
export TF_CLI_CONFIG_FILE="$tmp_tf_cli_config"

tf_var() {
  terraform console -var-file=terraform.tfvars <<< "var.$1" | tr -d '"' | tr -d '\r'
}

has_state() {
  terraform state show "$1" >/dev/null 2>&1
}

in_state() {
  terraform state show "$1" >/dev/null 2>&1
}

import_if_missing() {
  local address="$1"
  local import_id="$2"

  if in_state "$address"; then
    echo "State already contains $address"
    return
  fi

  echo "Importing existing resource into state: $address"
  terraform import "$address" "$import_id"
}

echo "Initializing Terraform..."
terraform init -input=false

role_name="$(tf_var role_name)"
policy_name="$(tf_var policy_name)"
aws_region="$(tf_var aws_region)"
cloudtrail_name="$(tf_var cloudtrail_name)"
cloudtrail_kms_alias_name="$(tf_var cloudtrail_kms_alias_name)"
cloudtrail_bucket_name="$(tf_var cloudtrail_bucket_name)"
vpc_flow_logs_bucket_name="$(tf_var vpc_flow_logs_bucket_name)"
vpc_id="$(tf_var vpc_id)"
vpc_flow_log_vpc_count="$(tf_var vpc_flow_log_vpc_count)"

echo "Checking AWS for existing resources..."

# Import matching AWS resources into Terraform state before apply so repeated
# runs adopt what already exists instead of trying to recreate it.
if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
  import_if_missing "aws_iam_role.sca_role" "$role_name"
fi

policy_arn="$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$policy_name'].Arn | [0]" --output text 2>/dev/null || true)"
if [[ -n "$policy_arn" && "$policy_arn" != "None" ]]; then
  import_if_missing "aws_iam_policy.sca_policy" "$policy_arn"
fi

if [[ -n "$policy_arn" && "$policy_arn" != "None" ]]; then
  attached_policy_arn="$(aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='$policy_arn'].PolicyArn | [0]" --output text 2>/dev/null || true)"
  if [[ -n "$attached_policy_arn" && "$attached_policy_arn" != "None" ]]; then
    import_if_missing "aws_iam_role_policy_attachment.sca_policy_attach" "${role_name}/${policy_arn}"
  fi
fi

if aws s3api head-bucket --bucket "$cloudtrail_bucket_name" >/dev/null 2>&1; then
  import_if_missing "aws_s3_bucket.cloudtrail" "$cloudtrail_bucket_name"
fi

if aws s3api head-bucket --bucket "$vpc_flow_logs_bucket_name" >/dev/null 2>&1; then
  import_if_missing "aws_s3_bucket.vpc_flow_logs" "$vpc_flow_logs_bucket_name"
fi

kms_key_id="$(aws --region "$aws_region" kms describe-key --key-id "$cloudtrail_kms_alias_name" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || true)"
if [[ -n "$kms_key_id" && "$kms_key_id" != "None" ]]; then
  import_if_missing "aws_kms_key.cloudtrail" "$kms_key_id"
  import_if_missing "aws_kms_alias.cloudtrail" "$cloudtrail_kms_alias_name"
fi

trail_arn="$(aws --region "$aws_region" cloudtrail describe-trails --trail-name-list "$cloudtrail_name" --query 'trailList[0].TrailARN' --output text 2>/dev/null || true)"
if [[ -n "$trail_arn" && "$trail_arn" != "None" ]]; then
  import_if_missing "aws_cloudtrail.this" "$trail_arn"
fi

all_vpc_ids=()
while IFS= read -r discovered_vpc_id; do
  all_vpc_ids+=("$discovered_vpc_id")
done < <(
  aws --region "$aws_region" ec2 describe-vpcs --query 'Vpcs[].VpcId' --output text 2>/dev/null |
    tr '\t' '\n' |
    awk 'NF' |
    sort
)

selected_vpc_ids=("$vpc_id")
for candidate_vpc_id in "${all_vpc_ids[@]}"; do
  if [[ "$candidate_vpc_id" == "$vpc_id" ]]; then
    continue
  fi

  if (( ${#selected_vpc_ids[@]} >= vpc_flow_log_vpc_count )); then
    break
  fi

  selected_vpc_ids+=("$candidate_vpc_id")
done

if has_state "aws_flow_log.vpc_flow_logs" && ! has_state "aws_flow_log.vpc_flow_logs[0]"; then
  terraform state mv "aws_flow_log.vpc_flow_logs" "aws_flow_log.vpc_flow_logs[0]"
fi

for index in "${!selected_vpc_ids[@]}"; do
  current_vpc_id="${selected_vpc_ids[$index]}"
  flow_log_id="$(aws --region "$aws_region" ec2 describe-flow-logs --query "FlowLogs[?ResourceId=='$current_vpc_id' && LogDestinationType=='s3' && contains(LogDestination, '$vpc_flow_logs_bucket_name')].FlowLogId | [0]" --output text 2>/dev/null || true)"

  if [[ -n "$flow_log_id" && "$flow_log_id" != "None" ]]; then
    import_if_missing "aws_flow_log.vpc_flow_logs[$index]" "$flow_log_id"
  fi
done

echo "Applying Terraform..."
terraform apply -auto-approve
