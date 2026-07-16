# Project Plan

Phases build in order — each phase produces something runnable/checkable before the next starts. Architecture design (diagram + control loop) is done; see `docs/architecture-diagram.html` and `README.md`.

## Phase 1 — Network foundation (Terraform)
- VPC with 3 AZs, public + private subnet pair per AZ
- Internet Gateway, NAT Gateway per AZ, route tables
- Security groups: ALB accepts inbound from internet; EC2 accepts inbound from ALB only

## Phase 2 — Compute + load balancing (Terraform)
- Launch Template: AMI, instance type, user-data bootstrap script
- ALB + target group, health-check thresholds tuned for fast failure detection
- Auto Scaling Group: `min:3 / desired:6 / max:12`, health check type `ELB`
- Lifecycle hooks on the ASG: `EC2_INSTANCE_LAUNCHING`, `EC2_INSTANCE_TERMINATING`
- Known gap: no WAF in front of the ALB yet — see Known Gaps below

## Phase 3 — Lifecycle automation (Terraform + Lambda/Python)
- IAM roles, least-privilege, scoped per function
- EventBridge rules matching ASG lifecycle-event patterns
- Terminate Handler Lambda: deregister target, drain connections, archive logs to S3, `CompleteLifecycleAction`
- Launch Handler Lambda: trigger SSM Automation, `CompleteLifecycleAction`
- SSM Automation document: bootstrap + readiness verification

## Phase 4 — Observability
- CloudWatch alarms: unhealthy host count, CPU, latency
- CloudWatch Logs for lifecycle/app events
- CloudTrail for the audit trail
- SNS topic wired to email/Slack for on-call notification

## Phase 5 — Validation
- Manually kill/degrade an instance; time the full replacement loop against the RTO target (< 3 min)
- Confirm zero dropped requests during replacement (ALB draining working)
- Confirm CloudTrail + logs capture the event end-to-end

## Phase 6 — Write-up
- Finalize README
- Before/after metrics table
- Cost estimate (NAT Gateway is the main line item)
- "What would break this" section

## Known gaps / hardening backlog
- **No WAF in front of the ALB.** The load balancer is currently public-facing with no layer-7 filtering — no protection against SQLi/XSS, bot traffic, or rate abuse. Add AWS WAF (with a managed rule group + rate-based rule) attached to the ALB before treating this as production-grade.
