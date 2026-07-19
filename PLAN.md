# Project Plan

Phases build in order — each phase produces something runnable/checkable before the next starts. Architecture design (diagram + control loop) is done; see `docs/colorful-self-healing-app.html` and `README.md`.

## Phase 1 — Network foundation (Terraform) ✅
- VPC with 3 AZs, public + private subnet pair per AZ
- Internet Gateway, NAT Gateway per AZ, route tables
- Security groups: ALB accepts inbound from internet; EC2 accepts inbound from ALB only

Implemented in `terraform/network.tf`, `terraform/security_groups.tf`.

## Phase 2 — Compute + load balancing (Terraform) ✅
- Launch Template: AMI, instance type, user-data bootstrap script
- ALB + target group, health-check thresholds tuned for fast failure detection
- Auto Scaling Group: `min:3 / desired:6 / max:12`, health check type `ELB`
- Lifecycle hooks on the ASG: `EC2_INSTANCE_LAUNCHING`, `EC2_INSTANCE_TERMINATING`
- Target-tracking scaling policy on `ALBRequestCountPerTarget` (target 50/min/target) so load actually drives scale-out — see "Load testing" below
- Known gap: no WAF in front of the ALB yet — see Known Gaps below

Implemented in `terraform/compute.tf`, `terraform/alb.tf`.

## Phase 3 — Lifecycle automation (Terraform + Lambda/Python) ✅
- IAM roles, least-privilege, scoped per function
- EventBridge rules matching ASG lifecycle-event patterns
- Terminate Handler Lambda: deregister target, drain connections, archive logs to S3, `CompleteLifecycleAction`
- Launch Handler Lambda: trigger SSM Automation, `CompleteLifecycleAction`
- SSM Automation document: bootstrap + readiness verification

Implemented in `terraform/iam.tf`, `terraform/lambda.tf`, `terraform/eventbridge.tf`, `terraform/ssm.tf`, `lambda/terminate_handler/index.py`, `lambda/launch_handler/index.py`.

## Phase 4 — Observability ✅
- CloudWatch alarms: unhealthy host count, CPU, latency
- CloudWatch Logs for lifecycle/app events
- CloudTrail for the audit trail
- SNS topic wired to email/Slack for on-call notification

Implemented in `terraform/observability.tf`. Email subscription is optional (`notification_email` variable); Slack would need an SNS→Lambda or Chatbot integration, not yet added.

## Phase 5 — Validation
- Manually kill/degrade an instance; time the full replacement loop against the RTO target (< 3 min)
- Confirm zero dropped requests during replacement (ALB draining working)
- Confirm CloudTrail + logs capture the event end-to-end
- Run the load test (below) and confirm the fleet scales out under load and back in afterward

**First live run (2026-07-16):** deployed the full stack (73 resources) and ran the k6 load test — 7,487 requests over 5 min, 96% success (300 requests failed, p95 latency 1.97s, max 9.5s during the scale-out transient). The scaling policy fired correctly (desired capacity 6→12), and the activity feed showed it live. Two findings from this run, both now fixed/documented:
- The activity-feed Function URL 403'd until a **second** resource-policy grant (`lambda:InvokeFunction`, scoped via `InvokedViaFunctionUrl`) was added — AWS started requiring this in addition to `lambda:InvokeFunctionUrl` as of October 2025; see the comment in `terraform/activity_feed.tf`.
- Scale-out stalled at 8 instances instead of the requested 12 — the account's EC2 vCPU quota for this instance family is 16 (8× t3.micro's 2 vCPUs each). See Known Gaps below.

## Phase 6 — Write-up
- Finalize README
- Before/after metrics table
- Cost estimate (NAT Gateway is the main line item)
- "What would break this" section

## Load testing & live activity dashboard ✅
- `aws_autoscaling_policy` (target-tracking, `ALBRequestCountPerTarget`) so a load test actually drives scaling, not just static desired-capacity
- `load-test/k6-script.js`: staged-VU ramp against the ALB
- `lambda/activity_feed/index.py` + `terraform/activity_feed.tf`: read-only Lambda (`describe_scaling_activities`) behind a public Function URL, CORS-locked to the ALB's own origin
- `activity.html`/`activity.js` (written by `terraform/templates/user_data.sh.tftpl`) polls the Function URL every 5s and shows recent ASG activity live on the site itself

## Known gaps / hardening backlog
- **No WAF in front of the ALB.** The load balancer is currently public-facing with no layer-7 filtering — no protection against SQLi/XSS, bot traffic, or rate abuse. Add AWS WAF (with a managed rule group + rate-based rule) attached to the ALB before treating this as production-grade.
- **HTTP-only listener.** No ACM certificate/HTTPS listener yet; add before any real traffic touches this.
- **Local Terraform state only.** No S3+DynamoDB (or Terraform Cloud) remote backend configured yet — fine solo, but needed before more than one person touches this.
- **Activity-feed Function URL is unauthenticated.** `authorization_type = "NONE"`, CORS-restricted to the ALB's origin. Acceptable since it only exposes read-only scaling-activity metadata (no secrets), but anyone who finds the URL directly (bypassing CORS, e.g. via curl) can call it — add an API-key/API-Gateway layer before this is anything but a demo.
- **EC2 vCPU service quota (16 for this instance family in this account) caps real scale-out below `max_size: 12`.** Confirmed during the first live load test — the ASG could only reach 8× t3.micro (16 vCPUs) before further launches failed with `InsufficientInstanceCapacity`-style quota errors. Request a quota increase (Service Quotas console, EC2 → "Running On-Demand Standard instances") before relying on the full `max_size` in a real test or demo.
