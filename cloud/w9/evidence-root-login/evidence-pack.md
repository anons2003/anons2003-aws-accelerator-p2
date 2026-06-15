# W9 Evidence Pack - Alert on AWS Root Account Login

## Objective

Build the monitoring flow for the lab:

- Enable CloudTrail and deliver CloudTrail events to CloudWatch Logs.
- Create a CloudWatch Logs metric filter for root account usage.
- Create a CloudWatch alarm when root activity count is greater than or equal to `1`.
- Notify by SNS email.
- Use AWS CLI with profile `monitoring`.

This pack uses CLI because the assignment asks for CLI-based creation. Terraform is better for repeatable production IaC, but for this evidence lab the CLI gives a clean command-by-command audit trail and matches the requested workflow.

## Confirmed Identity

Run:

```bash
aws sts get-caller-identity --profile monitoring
```

Expected:

```json
{
  "UserId": "459858400912",
  "Account": "459858400912",
  "Arn": "arn:aws:iam::459858400912:root"
}
```

## Evidence Folder

```text
evidence-root-login/
  evidence-pack.md
  screenshots/
    00-requirement-reference.png
    01-cli-identity.png
    02-sns-topic-and-subscription.png
    03-sns-email-confirmed.png
    04-cloudtrail-trail-enabled.png
    05-cloudwatch-log-group.png
    06-metric-filter-root-login.png
    07-cloudwatch-alarm.png
    08-alarm-sns-action.png
    09-alarm-test-state.png
    10-email-alert-received.png
  src/
    create_root_login_alert.sh
  cli-output/
    01-sts-get-caller-identity.json
    02-sns-topic-arn.txt
    03-sns-subscribe.json
    04-create-bucket.json
    05-log-group-arn.txt
    06-create-role.json
    07-upsert-trail.json
    08-trail-status.json
    09-metric-filter.json
    10-alarm.json
    11-summary.txt
```

## CLI Source

Script:

```bash
evidence-root-login/src/create_root_login_alert.sh
```

Make executable:

```bash
chmod +x evidence-root-login/src/create_root_login_alert.sh
```

Set inputs:

```bash
export AWS_PROFILE_NAME="monitoring"
export AWS_REGION="ap-southeast-1"
export ALERT_EMAIL="truclt0311@gmail.com"
```

Run:

```bash
./evidence-root-login/src/create_root_login_alert.sh
```

The script creates or updates:

- SNS topic `w9-root-login-alert-topic`.
- SNS email subscription for `truclt0311@gmail.com`.
- S3 bucket for CloudTrail logs.
- CloudWatch Logs log group `/aws/cloudtrail/w9-root-login`.
- IAM role for CloudTrail to write to CloudWatch Logs.
- Multi-region CloudTrail trail `w9-root-login-trail`.
- CloudWatch Logs metric filter `w9-root-account-login`.
- CloudWatch alarm `w9-root-account-login-alert`.

Important: confirm the SNS email subscription before testing alarm notification delivery.

## Important Filter Pattern

CloudWatch Logs metric filter pattern:

```text
{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }
```

Metric:

```text
Namespace: Security
Metric name: RootAccountLoginCount
Metric value: 1
Statistic: Sum
Period: 5 minutes
Threshold: >= 1
```

## Manual CLI Commands

Use this section if you need to explain the CLI flow in the submission.

```bash
export AWS_PROFILE_NAME="monitoring"
export AWS_REGION="ap-southeast-1"
export ALERT_EMAIL="truclt0311@gmail.com"

aws sts get-caller-identity --profile "$AWS_PROFILE_NAME"
```

Create the full lab:

```bash
chmod +x evidence-root-login/src/create_root_login_alert.sh
./evidence-root-login/src/create_root_login_alert.sh
```

Check CloudTrail:

```bash
aws cloudtrail get-trail-status \
  --name w9-root-login-trail \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

Check metric filter:

```bash
aws logs describe-metric-filters \
  --log-group-name /aws/cloudtrail/w9-root-login \
  --filter-name-prefix w9-root-account-login \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

Check alarm:

```bash
aws cloudwatch describe-alarms \
  --alarm-names w9-root-account-login-alert \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

Safe notification test after confirming SNS email:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name w9-root-account-login-alert \
  --state-value ALARM \
  --state-reason "W9 evidence test" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

Reset state:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name w9-root-account-login-alert \
  --state-value OK \
  --state-reason "W9 evidence reset" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

## Screenshot Instructions

Save every screenshot under:

```text
evidence-root-login/screenshots/
```

### 00 - Requirement Reference

Already saved:

```text
evidence-root-login/screenshots/00-requirement-reference.png
```

Show the lab title: `Alert on AWS Root Account Login`.

### 01 - CLI Identity

Run:

```bash
aws sts get-caller-identity --profile monitoring
```

Save:

```text
evidence-root-login/screenshots/01-cli-identity.png
```

Must show account `459858400912` and ARN `arn:aws:iam::459858400912:root`.

### 02 - SNS Topic and Subscription

Console:

```text
Amazon SNS -> Topics -> w9-root-login-alert-topic
Amazon SNS -> Subscriptions
```

Save:

```text
evidence-root-login/screenshots/02-sns-topic-and-subscription.png
```

Must show topic ARN, protocol `email`, and endpoint `truclt0311@gmail.com`.

### 03 - SNS Email Confirmed

Open the email from AWS Notifications and click the confirmation link.

Save:

```text
evidence-root-login/screenshots/03-sns-email-confirmed.png
```

Must show either the confirmation success page or subscription status `Confirmed`.

### 04 - CloudTrail Trail Enabled

Console:

```text
CloudTrail -> Trails -> w9-root-login-trail
```

Save:

```text
evidence-root-login/screenshots/04-cloudtrail-trail-enabled.png
```

Must show:

- Trail name.
- Logging enabled.
- Multi-region trail enabled.
- CloudWatch Logs integration points to `/aws/cloudtrail/w9-root-login`.

### 05 - CloudWatch Log Group

Console:

```text
CloudWatch -> Logs -> Log groups -> /aws/cloudtrail/w9-root-login
```

Save:

```text
evidence-root-login/screenshots/05-cloudwatch-log-group.png
```

Must show log group name and CloudTrail log streams after events arrive.

### 06 - Metric Filter Root Login

Console:

```text
CloudWatch -> Logs -> Log groups -> /aws/cloudtrail/w9-root-login -> Metric filters
```

Save:

```text
evidence-root-login/screenshots/06-metric-filter-root-login.png
```

Must show:

- Filter name `w9-root-account-login`.
- Filter pattern for `$.userIdentity.type = "Root"`.
- Metric namespace `Security`.
- Metric name `RootAccountLoginCount`.

### 07 - CloudWatch Alarm

Console:

```text
CloudWatch -> Alarms -> All alarms -> w9-root-account-login-alert
```

Save:

```text
evidence-root-login/screenshots/07-cloudwatch-alarm.png
```

Must show:

- Alarm name.
- Metric `Security / RootAccountLoginCount`.
- Statistic `Sum`.
- Period `5 minutes`.
- Threshold `>= 1`.

### 08 - Alarm SNS Action

In the alarm detail page, open the actions/notifications section.

Save:

```text
evidence-root-login/screenshots/08-alarm-sns-action.png
```

Must show SNS topic action for `w9-root-login-alert-topic`.

### 09 - Alarm Test State

After confirming the email subscription, run:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name w9-root-account-login-alert \
  --state-value ALARM \
  --state-reason "W9 evidence test" \
  --region ap-southeast-1 \
  --profile monitoring
```

Save:

```text
evidence-root-login/screenshots/09-alarm-test-state.png
```

Must show the terminal command or CloudWatch alarm state `In alarm`.

### 10 - Email Alert Received

Open Gmail inbox for `truclt0311@gmail.com`.

Save:

```text
evidence-root-login/screenshots/10-email-alert-received.png
```

Must show:

- Email from AWS Notifications.
- Alarm name `w9-root-account-login-alert`.
- New state `ALARM`.

## Cleanup

Run cleanup only after evidence is captured.

```bash
export AWS_PROFILE_NAME="monitoring"
export AWS_REGION="ap-southeast-1"

aws cloudwatch delete-alarms \
  --alarm-names w9-root-account-login-alert \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws logs delete-metric-filter \
  --log-group-name /aws/cloudtrail/w9-root-login \
  --filter-name w9-root-account-login \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"

aws cloudtrail stop-logging \
  --name w9-root-login-trail \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE_NAME"
```

Do not delete the CloudTrail S3 bucket until you no longer need audit logs for the submission.

## References

- AWS Security Blog: receive notifications when AWS root credentials are used.
- AWS Security Hub CloudWatch.1: metric filter and alarm should exist for root user usage.
