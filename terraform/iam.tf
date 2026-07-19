# --- EC2 instance role -------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "self-healing-fleet-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the terminate-handler Lambda's fire-and-forget SSM command (running
# under this instance role, not the Lambda's role) archive logs before the
# instance is terminated.
data "aws_iam_policy_document" "ec2_archive_put" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.archive.arn}/*"]
  }
}

resource "aws_iam_role_policy" "ec2_archive_put" {
  name   = "archive-bucket-put"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_archive_put.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "self-healing-fleet-ec2-profile"
  role = aws_iam_role.ec2.name
}

# --- Lambda execution roles ---------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "terminate_lambda" {
  name               = "self-healing-fleet-terminate-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "terminate_lambda_basic" {
  role       = aws_iam_role.terminate_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "terminate_lambda_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["autoscaling:CompleteLifecycleAction"]
    resources = [aws_autoscaling_group.main.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = [aws_lb_target_group.main.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.aws_region}:*:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Name"
      values   = ["self-healing-fleet"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notifications.arn]
  }
}

resource "aws_iam_role_policy" "terminate_lambda" {
  name   = "terminate-handler-permissions"
  role   = aws_iam_role.terminate_lambda.id
  policy = data.aws_iam_policy_document.terminate_lambda_permissions.json
}

resource "aws_iam_role" "launch_lambda" {
  name               = "self-healing-fleet-launch-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "launch_lambda_basic" {
  role       = aws_iam_role.launch_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "launch_lambda_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["autoscaling:CompleteLifecycleAction"]
    resources = [aws_autoscaling_group.main.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:StartAutomationExecution"]
    resources = [aws_ssm_document.readiness.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetAutomationExecution",
      "ssm:StopAutomationExecution",
    ]
    # Automation execution ARNs are generated per-run and unknown ahead of
    # time; SSM does not support scoping these further than the resource type.
    resources = ["*"]
  }

  # The readiness Automation document's aws:runCommand step executes with
  # this role's permissions (no AutomationAssumeRole is configured), so it
  # needs to be able to send and read back the underlying Run Command.
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.aws_region}:*:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Name"
      values   = ["self-healing-fleet"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notifications.arn]
  }
}

resource "aws_iam_role_policy" "launch_lambda" {
  name   = "launch-handler-permissions"
  role   = aws_iam_role.launch_lambda.id
  policy = data.aws_iam_policy_document.launch_lambda_permissions.json
}
