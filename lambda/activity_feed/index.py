import json
import os

import boto3

autoscaling = boto3.client("autoscaling")

ASG_NAME = os.environ["ASG_NAME"]

CORS_HEADERS = {
    "Content-Type": "application/json",
}


def _serialize(activity):
    return {
        "activityId": activity["ActivityId"],
        "description": activity.get("Description", ""),
        "cause": activity.get("Cause", ""),
        "statusCode": activity.get("StatusCode", ""),
        "statusMessage": activity.get("StatusMessage", ""),
        "startTime": activity["StartTime"].isoformat(),
        "endTime": activity["EndTime"].isoformat() if "EndTime" in activity else None,
        "progress": activity.get("Progress"),
    }


def handler(event, context):
    response = autoscaling.describe_scaling_activities(
        AutoScalingGroupName=ASG_NAME,
        MaxRecords=25,
    )
    activities = [_serialize(a) for a in response.get("Activities", [])]

    return {
        "statusCode": 200,
        "headers": CORS_HEADERS,
        "body": json.dumps({"activities": activities}),
    }
