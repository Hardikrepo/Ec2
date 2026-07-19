data "archive_file" "terminate_handler" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/terminate_handler"
  output_path = "${path.module}/.build/terminate_handler.zip"
}

data "archive_file" "launch_handler" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/launch_handler"
  output_path = "${path.module}/.build/launch_handler.zip"
}

resource "aws_cloudwatch_log_group" "terminate_lambda" {
  name              = "/aws/lambda/self-healing-fleet-terminate-handler"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "launch_lambda" {
  name              = "/aws/lambda/self-healing-fleet-launch-handler"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "terminate_handler" {
  function_name    = "self-healing-fleet-terminate-handler"
  role             = aws_iam_role.terminate_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 130
  filename         = data.archive_file.terminate_handler.output_path
  source_code_hash = data.archive_file.terminate_handler.output_base64sha256

  environment {
    variables = {
      TARGET_GROUP_ARN = aws_lb_target_group.main.arn
      ARCHIVE_BUCKET   = aws_s3_bucket.archive.bucket
      TOPIC_ARN        = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.terminate_lambda]
}

resource "aws_lambda_function" "launch_handler" {
  function_name    = "self-healing-fleet-launch-handler"
  role             = aws_iam_role.launch_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 220
  filename         = data.archive_file.launch_handler.output_path
  source_code_hash = data.archive_file.launch_handler.output_base64sha256

  environment {
    variables = {
      READINESS_DOCUMENT_NAME = aws_ssm_document.readiness.name
      TOPIC_ARN               = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.launch_lambda]
}

resource "aws_lambda_permission" "terminate_from_eventbridge" {
  statement_id  = "AllowEventBridgeInvokeTerminate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terminate_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.terminating.arn
}

resource "aws_lambda_permission" "launch_from_eventbridge" {
  statement_id  = "AllowEventBridgeInvokeLaunch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.launch_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.launching.arn
}
