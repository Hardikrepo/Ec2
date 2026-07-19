resource "aws_cloudwatch_event_rule" "terminating" {
  name        = "self-healing-fleet-terminating"
  description = "Routes ASG EC2_INSTANCE_TERMINATING lifecycle events to the terminate handler."

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-terminate Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.main.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "terminating" {
  rule = aws_cloudwatch_event_rule.terminating.name
  arn  = aws_lambda_function.terminate_handler.arn
}

resource "aws_cloudwatch_event_rule" "launching" {
  name        = "self-healing-fleet-launching"
  description = "Routes ASG EC2_INSTANCE_LAUNCHING lifecycle events to the launch handler."

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-launch Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.main.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "launching" {
  rule = aws_cloudwatch_event_rule.launching.name
  arn  = aws_lambda_function.launch_handler.arn
}
