import json
import os
import time

import boto3

autoscaling = boto3.client("autoscaling")
ssm = boto3.client("ssm")
sns = boto3.client("sns")

READINESS_DOCUMENT_NAME = os.environ["READINESS_DOCUMENT_NAME"]
TOPIC_ARN = os.environ["TOPIC_ARN"]

# Must stay comfortably under the launching lifecycle hook's heartbeat
# timeout (240s) so CompleteLifecycleAction always has time to run.
AUTOMATION_POLL_BUDGET_SECONDS = 200
AUTOMATION_POLL_INTERVAL_SECONDS = 5

TERMINAL_STATES = {"Success", "Failed", "Cancelled", "TimedOut"}


def _run_readiness_check(instance_id):
    start = ssm.start_automation_execution(
        DocumentName=READINESS_DOCUMENT_NAME,
        Parameters={"InstanceId": [instance_id]},
    )
    execution_id = start["AutomationExecutionId"]

    deadline = time.time() + AUTOMATION_POLL_BUDGET_SECONDS
    status = "InProgress"
    while time.time() < deadline:
        execution = ssm.get_automation_execution(AutomationExecutionId=execution_id)
        status = execution["AutomationExecution"]["AutomationExecutionStatus"]
        if status in TERMINAL_STATES:
            break
        time.sleep(AUTOMATION_POLL_INTERVAL_SECONDS)

    return status == "Success"


def handler(event, context):
    detail = event["detail"]
    instance_id = detail["EC2InstanceId"]
    hook_name = detail["LifecycleHookName"]
    asg_name = detail["AutoScalingGroupName"]
    action_token = detail["LifecycleActionToken"]

    is_ready = _run_readiness_check(instance_id)
    # ABANDON causes the ASG to terminate this instance and launch another
    # in its place, i.e. self-healing applies to bad launches too, not just
    # instances that fail health checks after going InService.
    result = "CONTINUE" if is_ready else "ABANDON"

    autoscaling.complete_lifecycle_action(
        LifecycleHookName=hook_name,
        AutoScalingGroupName=asg_name,
        LifecycleActionToken=action_token,
        LifecycleActionResult=result,
    )

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="Self-healing fleet: instance launching",
        Message=json.dumps(
            {
                "instance": instance_id,
                "transition": detail.get("LifecycleTransition"),
                "result": result,
            }
        ),
    )

    return {"statusCode": 200, "result": result}
