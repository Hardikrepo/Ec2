# Architecture

## 1. Purpose

A self-healing compute tier: an EC2 fleet that automatically detects unhealthy instances, drains and replaces them, and re-verifies readiness before returning to service — without human intervention. Built around Auto Scaling lifecycle hooks paired with ALB health checks.

## 2. AWS services

Route 53 · Internet Gateway · Application Load Balancer (+ target group) · NAT Gateway · EC2 (behind an Auto Scaling Group) · Launch Template · EventBridge · AWS Lambda (two functions) · Systems Manager Automation · S3 · IAM · CloudWatch (Alarms + Logs) · CloudTrail · SNS

## 3. Connections / data flow

- Client → Route 53 → Internet Gateway → ALB
- ALB → EC2 targets in the ASG (request traffic + continuous target-group health checks)
- ASG → EventBridge (fires `EC2_INSTANCE_TERMINATING` / `EC2_INSTANCE_LAUNCHING` lifecycle events)
- EventBridge → Terminate Handler Lambda → deregisters target from ALB, drains connections, archives logs/session state to S3, then `CompleteLifecycleAction` back to the ASG
- EventBridge → Launch Handler Lambda → triggers SSM Automation to bootstrap + verify the new instance, then `CompleteLifecycleAction` back to the ASG
- Lambda functions → SNS → on-call (Slack/email)
- ASG, Lambdas, SSM → CloudWatch Logs/Alarms and CloudTrail (telemetry/audit, passive)

## 4. Network layout

- Region: `us-east-1`
- Single VPC: `10.0.0.0/16`
- 3 Availability Zones, each with a public + private subnet pair:
  - Public: `10.0.0.0/24`, `10.0.1.0/24`, `10.0.2.0/24` (ALB, NAT Gateway)
  - Private: `10.0.10.0/24`, `10.0.11.0/24`, `10.0.12.0/24` (EC2/ASG)

## 5. External actors

- End users/clients — HTTPS traffic through Route 53/ALB
- On-call engineer/ops team — receives SNS notifications
- No third-party APIs or on-premises systems are in scope currently.

## 6. Security / operations

- IAM: least-privilege execution role per Lambda, scoped individually
- Security groups: ALB accepts inbound from the internet; EC2 accepts inbound from the ALB security group only, nothing else
- CloudWatch Alarms: unhealthy host count, CPU, latency
- CloudWatch Logs: lifecycle + application events
- CloudTrail: management/data-plane API audit trail
- S3: log/session archive on instance termination

**Known gap:** no WAF in front of the ALB — the load balancer is public-facing with no layer-7 filtering (no protection against SQLi/XSS/bot traffic/rate abuse). Tracked in `PLAN.md`.

## 7. Output format

Current diagram is hand-built inline **SVG** (embedded in an HTML artifact, theme-aware, [`docs/colorful-self-healing-app.html`](docs/colorful-self-healing-app.html)). Editable draw.io variants are archived in [`docs/diagrams/archive/`](docs/diagrams/archive/).

## 8. Style / detail level

Detailed, production-oriented — not a simple box overview. Includes subnet CIDRs, explicit lifecycle-hook states (`Terminating:Wait`, `Pending:Wait`), IAM scoping, and a numbered 10-step control loop.
