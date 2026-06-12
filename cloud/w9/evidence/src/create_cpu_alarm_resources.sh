#!/usr/bin/env bash
set -euo pipefail

# Required inputs:
#   export ALERT_EMAIL="you@example.com"
#   export INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"
#
# Optional inputs:
#   export AWS_REGION="us-east-1"
#   export AWS_PROFILE_NAME="monitoring"
#   export TOPIC_NAME="w9-cpu-alarm-topic"
#   export ALARM_NAME="w9-ec2-cpu-high-80"

AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-monitoring}"
AWS_REGION="${AWS_REGION:-us-east-1}"
TOPIC_NAME="${TOPIC_NAME:-w9-cpu-alarm-topic}"
ALARM_NAME="${ALARM_NAME:-w9-ec2-cpu-high-80}"
THRESHOLD="${THRESHOLD:-80}"
PERIOD_SECONDS="${PERIOD_SECONDS:-300}"
EVALUATION_PERIODS="${EVALUATION_PERIODS:-1}"
DATAPOINTS_TO_ALARM="${DATAPOINTS_TO_ALARM:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-evidence/cli-output}"

if [[ -z "${ALERT_EMAIL:-}" ]]; then
  echo "ERROR: ALERT_EMAIL is required. Example: export ALERT_EMAIL='you@example.com'" >&2
  exit 1
fi

if [[ -z "${INSTANCE_ID:-}" ]]; then
  echo "ERROR: INSTANCE_ID is required. Example: export INSTANCE_ID='i-0123456789abcdef0'" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Checking AWS identity with profile ${AWS_PROFILE_NAME}..."
aws sts get-caller-identity \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/01-sts-get-caller-identity.json"

echo "Creating SNS topic ${TOPIC_NAME} in ${AWS_REGION}..."
TOPIC_ARN="$(
  aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_NAME" \
    --query 'TopicArn' \
    --output text
)"
printf '%s\n' "$TOPIC_ARN" | tee "$OUTPUT_DIR/02-sns-topic-arn.txt"

echo "Creating email subscription for ${ALERT_EMAIL}..."
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$ALERT_EMAIL" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/03-sns-subscribe.json"

echo "Creating CloudWatch CPU alarm ${ALARM_NAME} for ${INSTANCE_ID}..."
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "W9 evidence: send SNS email when EC2 CPUUtilization is greater than ${THRESHOLD}% for ${PERIOD_SECONDS} seconds." \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period "$PERIOD_SECONDS" \
  --threshold "$THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
  --evaluation-periods "$EVALUATION_PERIODS" \
  --datapoints-to-alarm "$DATAPOINTS_TO_ALARM" \
  --alarm-actions "$TOPIC_ARN" \
  --unit Percent \
  --treat-missing-data missing \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME" \
  --output json | tee "$OUTPUT_DIR/04-describe-alarm.json"

cat <<EOF | tee "$OUTPUT_DIR/05-next-steps.txt"
Created resources:
- SNS topic: ${TOPIC_ARN}
- CloudWatch alarm: ${ALARM_NAME}
- Email subscription target: ${ALERT_EMAIL}

Next steps:
1. Open ${ALERT_EMAIL} inbox and confirm the SNS subscription email.
2. Capture AWS Console screenshots listed in evidence/evidence-pack.md.
3. Optional email test after confirmation:
   aws cloudwatch set-alarm-state --alarm-name ${ALARM_NAME} --state-value ALARM --state-reason "W9 evidence test" --region ${AWS_REGION} --profile ${AWS_PROFILE_NAME}
EOF
