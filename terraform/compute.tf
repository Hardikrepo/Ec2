data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "self-healing-fleet-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.instance.id]

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    activity_feed_url = aws_lambda_function_url.activity_feed.function_url
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "self-healing-fleet"
    }
  }
}

resource "aws_autoscaling_group" "main" {
  name                      = local.asg_name
  vpc_zone_identifier       = aws_subnet.private[*].id
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  health_check_type         = "ELB"
  health_check_grace_period = 120
  target_group_arns         = [aws_lb_target_group.main.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  tag {
    key                 = "Name"
    value               = "self-healing-fleet"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    # The target-tracking scaling policy below adjusts desired_capacity
    # directly; ignore drift here so a later `terraform apply` doesn't fight
    # the policy's own scaling decisions.
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "request_count_tracking" {
  name                   = "self-healing-fleet-request-count-tracking"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.main.arn_suffix}"
    }
    # Requests/min per target; the nginx placeholder app is nearly CPU-free,
    # so request count (not CPU) is what actually drives scale-out under a
    # load test.
    target_value = 50
  }
}

resource "aws_autoscaling_lifecycle_hook" "launching" {
  name                   = "self-healing-fleet-launching-hook"
  autoscaling_group_name = aws_autoscaling_group.main.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 240
  default_result         = "ABANDON"
}

resource "aws_autoscaling_lifecycle_hook" "terminating" {
  name                   = "self-healing-fleet-terminating-hook"
  autoscaling_group_name = aws_autoscaling_group.main.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 150
  default_result         = "CONTINUE"
}
