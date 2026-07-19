import json
import os
import time

import boto3

autoscaling = boto3.client("autoscaling")
elbv2 = boto3.client("elbv2")
ssm = boto3.client("ssm")
sns = boto3.client("sns")

TARGET_GROUP_ARN = os.environ["TARGET_GROUP_ARN"]
ARCHIVE_BUCKET = os.environ["ARCHIVE_BUCKET"]
TOPIC_ARN = os.environ["TOPIC_ARN"]

# Must stay comfortably under the terminating lifecycle hook's heartbeat
# timeout (150s) so CompleteLifecycleAction always has time to run.
DRAIN_POLL_BUDGET_SECONDS = 100
DRAIN_POLL_INTERVAL_SECONDS = 5


def _wait_for_drain(instance_id):
    deadline = time.time() + DRAIN_POLL_BUDGET_SECONDS
    while time.time() < deadline:
        health = elbv2.describe_target_health(
            TargetGroupArn=TARGET_GROUP_ARN,
            Targets=[{"Id": instance_id}],
        )
        descriptions = health.get("TargetHealthDescriptions", [])
        if not descriptions:
            return
        state = descriptions[0]["TargetHealth"]["State"]
        if state in ("unused", "unavailable"):
            return
        time.sleep(DRAIN_POLL_INTERVAL_SECONDS)


def _archive_logs(instance_id):
    # Fire-and-forget: archiving is best-effort telemetry, not a blocker to
    # replacing the instance, so failures here are swallowed rather than
    # delaying CompleteLifecycleAction.
    try:
        ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={
                "commands": [
                    "tar -czf /tmp/archive.tar.gz /var/log || true",
                    f"aws s3 cp /tmp/archive.tar.gz s3://{ARCHIVE_BUCKET}/{instance_id}/archive.tar.gz || true",
                ]
            },
        )
    except Exception as exc:  # noqa: BLE001 - best-effort, never blocks termination
        print(f"archive send_command failed for {instance_id}: {exc}")


def handler(event, context):
    detail = event["detail"]
    instance_id = detail["EC2InstanceId"]
    hook_name = detail["LifecycleHookName"]
    asg_name = detail["AutoScalingGroupName"]
    action_token = detail["LifecycleActionToken"]

    elbv2.deregister_targets(
        TargetGroupArn=TARGET_GROUP_ARN,
        Targets=[{"Id": instance_id}],
    )
    _wait_for_drain(instance_id)
    _archive_logs(instance_id)

    autoscaling.complete_lifecycle_action(
        LifecycleHookName=hook_name,
        AutoScalingGroupName=asg_name,
        LifecycleActionToken=action_token,
        LifecycleActionResult="CONTINUE",
    )

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="Self-healing fleet: instance terminating",
        Message=json.dumps(
            {
                "instance": instance_id,
                "transition": detail.get("LifecycleTransition"),
                "result": "CONTINUE",
            }
        ),
    )

    return {"statusCode": 200, "result": "CONTINUE"}
