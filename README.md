# Self-Healing EC2 Fleet

Capstone project — a compute tier that detects, drains, and replaces unhealthy EC2 instances automatically, using Auto Scaling lifecycle hooks and layered health checks.

## Status

Planning stage. Architecture is designed (see below); Terraform/Lambda implementation not started yet.

## Architecture

Full diagram: [`docs/architecture-diagram.html`](docs/architecture-diagram.html) (open in a browser).

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

## Next steps

- [ ] Terraform: VPC, subnets, ALB, ASG + Launch Template, lifecycle hooks
- [ ] Lambda: terminate handler (drain/deregister/archive)
- [ ] Lambda: launch handler (SSM trigger + `CompleteLifecycleAction`)
- [ ] SSM Automation document for bootstrap/readiness checks
- [ ] EventBridge rules wiring ASG lifecycle events to both Lambdas
- [ ] CloudWatch alarms + SNS topic for on-call notification
