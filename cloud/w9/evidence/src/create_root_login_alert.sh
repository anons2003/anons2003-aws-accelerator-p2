#!/usr/bin/env bash
set -euo pipefail

# Root account login alert via CloudTrail -> CloudWatch Logs metric filter -> Alarm -> SNS email.
#
# Required:
#   export ALERT_EMAIL="truclt0311@gmail.com"
#
# Optional:
#   export AWS_PROFILE_NAME="monitoring"
#   export AWS_REGION="ap-southeast-1"

AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-monitoring}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ALERT_EMAIL="${ALERT_EMAIL:-truclt0311@gmail.com}"

TRAIL_NAME="${TRAIL_NAME:-w9-root-login-trail}"
LOG_GROUP_NAME="${LOG_GROUP_NAME:-/aws/cloudtrail/w9-root-login}"
ROLE_NAME="${ROLE_NAME:-w9-cloudtrail-cloudwatch-role}"
TOPIC_NAME="${TOPIC_NAME:-w9-root-login-alert-topic}"
FILTER_NAME="${FILTER_NAME:-w9-root-account-login}"
METRIC_NAMESPACE="${METRIC_NAMESPACE:-Security}"
METRIC_NAME="${METRIC_NAME:-RootAccountLoginCount}"
ALARM_NAME="${ALARM_NAME:-w9-root-account-login-alert}"
OUTPUT_DIR="${OUTPUT_DIR:-evidence/cli-output}"

mkdir -p "$OUTPUT_DIR"

echo "Checking AWS identity..."
ACCOUNT_ID="$(
  aws sts get-caller-identity \
    --profile "$AWS_PROFILE_NAME" \
    --query Account \
    --output text
)"
aws sts get-caller-identity \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/01-sts-get-caller-identity.json"

BUCKET_NAME="${BUCKET_NAME:-w9-cloudtrail-${ACCOUNT_ID}-${AWS_REGION}}"
TRAIL_ARN="arn:aws:cloudtrail:${AWS_REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME}"

echo "Creating SNS topic and email subscription..."
TOPIC_ARN="$(
  aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_NAME" \
    --query TopicArn \
    --output text
)"
printf '%s\n' "$TOPIC_ARN" | tee "$OUTPUT_DIR/02-sns-topic-arn.txt"

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$ALERT_EMAIL" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/03-sns-subscribe.json"

echo "Preparing S3 bucket for CloudTrail: ${BUCKET_NAME}"
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE_NAME" >/dev/null 2>&1; then
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE_NAME" \
      --output json | tee "$OUTPUT_DIR/04-create-bucket.json"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}" \
      --profile "$AWS_PROFILE_NAME" \
      --output json | tee "$OUTPUT_DIR/04-create-bucket.json"
  fi
fi

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile "$AWS_PROFILE_NAME"

cat > "$OUTPUT_DIR/cloudtrail-bucket-policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${TRAIL_ARN}"
        }
      }
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "AWS:SourceArn": "${TRAIL_ARN}"
        }
      }
    }
  ]
}
POLICY

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy "file://${OUTPUT_DIR}/cloudtrail-bucket-policy.json" \
  --profile "$AWS_PROFILE_NAME"

echo "Preparing CloudWatch Logs log group..."
aws logs create-log-group \
  --log-group-name "$LOG_GROUP_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" >/dev/null 2>&1 || true

aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days 30 \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

LOG_GROUP_ARN="$(
  aws logs describe-log-groups \
    --log-group-name-prefix "$LOG_GROUP_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_NAME" \
    --query "logGroups[?logGroupName=='${LOG_GROUP_NAME}'].arn | [0]" \
    --output text
)"
printf '%s\n' "$LOG_GROUP_ARN" | tee "$OUTPUT_DIR/05-log-group-arn.txt"
LOG_GROUP_ARN_BASE="${LOG_GROUP_ARN%:*}"

echo "Preparing IAM role for CloudTrail to write CloudWatch Logs..."
cat > "$OUTPUT_DIR/cloudtrail-trust-policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

if ! aws iam get-role --role-name "$ROLE_NAME" --profile "$AWS_PROFILE_NAME" >/dev/null 2>&1; then
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${OUTPUT_DIR}/cloudtrail-trust-policy.json" \
    --profile "$AWS_PROFILE_NAME" \
    --output json | tee "$OUTPUT_DIR/06-create-role.json"
fi

ROLE_ARN="$(
  aws iam get-role \
    --role-name "$ROLE_NAME" \
    --profile "$AWS_PROFILE_NAME" \
    --query 'Role.Arn' \
    --output text
)"

cat > "$OUTPUT_DIR/cloudtrail-logs-role-policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "${LOG_GROUP_ARN_BASE}:log-stream:${ACCOUNT_ID}_CloudTrail_*"
    }
  ]
}
POLICY

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "${ROLE_NAME}-logs-policy" \
  --policy-document "file://${OUTPUT_DIR}/cloudtrail-logs-role-policy.json" \
  --profile "$AWS_PROFILE_NAME"

sleep 10

echo "Creating or updating CloudTrail trail..."
if aws cloudtrail describe-trails \
  --trail-name-list "$TRAIL_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --query 'trailList[0].Name' \
  --output text 2>/dev/null | grep -q "^${TRAIL_NAME}$"; then
  aws cloudtrail update-trail \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$BUCKET_NAME" \
    --is-multi-region-trail \
    --include-global-service-events \
    --cloud-watch-logs-log-group-arn "${LOG_GROUP_ARN_BASE}:*" \
    --cloud-watch-logs-role-arn "$ROLE_ARN" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_NAME" \
    --output json | tee "$OUTPUT_DIR/07-upsert-trail.json"
else
  aws cloudtrail create-trail \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$BUCKET_NAME" \
    --is-multi-region-trail \
    --include-global-service-events \
    --cloud-watch-logs-log-group-arn "${LOG_GROUP_ARN_BASE}:*" \
    --cloud-watch-logs-role-arn "$ROLE_ARN" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_NAME" \
    --output json | tee "$OUTPUT_DIR/07-upsert-trail.json"
fi

aws cloudtrail start-logging \
  --name "$TRAIL_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws cloudtrail get-trail-status \
  --name "$TRAIL_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/08-trail-status.json"

echo "Creating CloudWatch Logs metric filter..."
FILTER_PATTERN='{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }'
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --metric-transformations "metricName=${METRIC_NAME},metricNamespace=${METRIC_NAMESPACE},metricValue=1" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/09-metric-filter.json"

echo "Creating CloudWatch alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "W9 evidence: alert when root account activity is detected by CloudTrail." \
  --metric-name "$METRIC_NAME" \
  --namespace "$METRIC_NAMESPACE" \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --alarm-actions "$TOPIC_ARN" \
  --treat-missing-data notBreaching \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/10-alarm.json"

cat <<EOF | tee "$OUTPUT_DIR/11-summary.txt"
Created or updated root login alert resources:
- Account: ${ACCOUNT_ID}
- Region: ${AWS_REGION}
- SNS topic: ${TOPIC_ARN}
- SNS email endpoint: ${ALERT_EMAIL}
- S3 bucket: ${BUCKET_NAME}
- CloudTrail trail: ${TRAIL_NAME}
- CloudWatch Logs log group: ${LOG_GROUP_NAME}
- Metric filter: ${FILTER_NAME}
- Metric: ${METRIC_NAMESPACE}/${METRIC_NAME}
- Alarm: ${ALARM_NAME}

Next steps:
1. Confirm the SNS subscription email sent to ${ALERT_EMAIL}.
2. Capture the screenshots listed in evidence/evidence-pack.md.
3. For a safe alarm-delivery test, use CloudWatch set-alarm-state before doing any real root-account login test:
   aws cloudwatch set-alarm-state --alarm-name ${ALARM_NAME} --state-value ALARM --state-reason "W9 evidence test" --region ${AWS_REGION} --profile ${AWS_PROFILE_NAME}
EOF
