# Self-Healing EC2 Fleet

Capstone project — a compute tier that detects, drains, and replaces unhealthy EC2 instances automatically, using Auto Scaling lifecycle hooks and layered health checks.

## Status

Terraform + Lambda implementation of Phases 1-4 (network, compute/ALB, lifecycle automation, observability), plus a target-tracking scaling policy, a k6 load-test script, and a live ASG activity feed on the site, is in `terraform/`, `lambda/`, and `load-test/`. Validated with `terraform validate` and a clean `terraform plan` (73 resources, 0 errors); not yet applied to a live account. `prototype.yaml` is an earlier CloudFormation prototype that assumes an existing VPC — kept for reference.

## Architecture

**Live diagram:** https://hardikrepo.github.io/Ec2/colorful-self-healing-app.html (animated, hosted via GitHub Pages) — or open [`docs/colorful-self-healing-app.html`](docs/colorful-self-healing-app.html) locally in a browser.

Editable draw.io variants (base, AWS 3D/isometric, technical-architecture, enterprise) are archived in [`docs/diagrams/archive/`](docs/diagrams/archive/) for reference. The prompts used to generate them via Miro AI/MCP are in [`docs/diagram-prompts/`](docs/diagram-prompts/).

**Stack:** Route 53 → ALB (multi-AZ) → Auto Scaling Group (private subnets, 3 AZs) → EventBridge → Lambda (terminate/launch handlers) → SSM Automation, with CloudWatch/CloudTrail/SNS for observability.

**Control loop:**
1. ALB target-group health checks continuously probe every instance.
2. A failed check marks the instance unhealthy; the ASG fires `EC2_INSTANCE_TERMINATING` and enters `Terminating:Wait`.
3. EventBridge routes the event to a Terminate Handler Lambda, which deregisters the target, drains connections, and archives logs/session state to S3.
4. The Lambda calls `CompleteLifecycleAction(CONTINUE)`; the ASG terminates the old instance and launches a replacement from the current Launch Template.
5. The new instance fires `EC2_INSTANCE_LAUNCHING` (`Pending:Wait`); EventBridge routes it to a Launch Handler Lambda.
6. That Lambda runs an SSM Automation runbook to bootstrap the instance and verify readiness, then completes the lifecycle action.
7. The instance passes health checks, goes `InService`, and rejoins the target group. SNS notifies on-call; CloudWatch Logs/CloudTrail hold the audit trail.

**Targets:** RTO < 3 min per instance replacement, 99.95% availability (multi-AZ, min 3 instances).

## Terraform

```
cd terraform
terraform init
terraform plan    # review before applying — creates real, billable AWS resources
terraform apply
```

Optional variables (see `terraform/variables.tf` for the full list): `notification_email`, `domain_name` + `hosted_zone_id` (Route 53 alias), `instance_type`, `asg_min_size`/`asg_desired_capacity`/`asg_max_size`.

**Known gaps** (see `PLAN.md`): no WAF in front of the ALB; HTTP-only listener (no ACM/HTTPS yet); local Terraform state only (no remote backend); the activity-feed Function URL is unauthenticated (read-only, non-sensitive data, CORS-locked to the ALB's own origin).

## Load testing & live activity dashboard

The fleet scales on ALB request count per target (not CPU — the placeholder nginx app is nearly CPU-free), so a load test actually needs to move that metric to see scale-out happen:

```
k6 run load-test/k6-script.js -e TARGET_URL=http://$(terraform output -raw alb_dns_name)
```

While it runs, open `http://<alb_dns_name>/activity.html` — it polls a small Lambda (via a Function URL) every 5s and shows the ASG's recent scaling activities (launches, terminations, lifecycle status) live, so you can watch the fleet scale out under load and back in afterward without leaving the site or opening the AWS console.

## Next steps

- [x] Terraform: VPC, subnets, ALB, ASG + Launch Template, lifecycle hooks
- [x] Lambda: terminate handler (drain/deregister/archive)
- [x] Lambda: launch handler (SSM trigger + `CompleteLifecycleAction`)
- [x] SSM Automation document for bootstrap/readiness checks
- [x] EventBridge rules wiring ASG lifecycle events to both Lambdas
- [x] CloudWatch alarms + SNS topic for on-call notification
- [ ] Deploy to a live account and validate the RTO/availability targets (Phase 5)
- [ ] Cost estimate + before/after write-up (Phase 6)
