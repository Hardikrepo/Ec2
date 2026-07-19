data "archive_file" "activity_feed" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/activity_feed"
  output_path = "${path.module}/.build/activity_feed.zip"
}

resource "aws_iam_role" "activity_feed_lambda" {
  name               = "self-healing-fleet-activity-feed-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "activity_feed_lambda_basic" {
  role       = aws_iam_role.activity_feed_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "activity_feed_lambda_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeAutoScalingGroups",
    ]
    # Describe-only, read-only actions; the autoscaling API does not support
    # resource-level restriction for these.
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "activity_feed_lambda" {
  name   = "activity-feed-permissions"
  role   = aws_iam_role.activity_feed_lambda.id
  policy = data.aws_iam_policy_document.activity_feed_lambda_permissions.json
}

resource "aws_cloudwatch_log_group" "activity_feed_lambda" {
  name              = "/aws/lambda/self-healing-fleet-activity-feed"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "activity_feed" {
  function_name    = "self-healing-fleet-activity-feed"
  role             = aws_iam_role.activity_feed_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.activity_feed.output_path
  source_code_hash = data.archive_file.activity_feed.output_base64sha256

  environment {
    variables = {
      ASG_NAME = local.asg_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.activity_feed_lambda]
}

resource "aws_lambda_function_url" "activity_feed" {
  function_name      = aws_lambda_function.activity_feed.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["http://${aws_lb.main.dns_name}"]
    allow_methods = ["GET"]
    max_age       = 300
  }
}

# authorization_type = "NONE" on the Function URL alone isn't sufficient —
# Lambda also requires this explicit resource-based permission before
# unauthenticated callers can invoke the URL.
resource "aws_lambda_permission" "activity_feed_public_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.activity_feed.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# As of October 2025, AWS requires a SECOND resource-policy grant for public
# Function URLs: lambda:InvokeFunction, scoped to InvokedViaFunctionUrl=true
# (see https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html). Without
# it, the Function URL 403s even though InvokeFunctionUrl is granted. The
# aws_lambda_permission resource in this provider version (5.100.0) has no
# argument for the InvokedViaFunctionUrl condition, so this calls the AWS CLI
# directly — remove this once the provider adds native support.
resource "null_resource" "activity_feed_invoke_function_permission" {
  triggers = {
    function_name = aws_lambda_function.activity_feed.function_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "aws lambda add-permission --region ${var.aws_region} --function-name ${aws_lambda_function.activity_feed.function_name} --statement-id AllowPublicInvokeViaFunctionUrl --action lambda:InvokeFunction --principal '*' --invoked-via-function-url; exit 0"
  }

  depends_on = [aws_lambda_function.activity_feed]
}
