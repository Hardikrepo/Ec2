locals {
  # A literal, not a resource attribute reference, so the activity-feed
  # Lambda (which the launch template's user_data depends on, via the
  # Function URL) doesn't create a dependency cycle back through the ASG.
  asg_name = "self-healing-fleet-asg"
}
