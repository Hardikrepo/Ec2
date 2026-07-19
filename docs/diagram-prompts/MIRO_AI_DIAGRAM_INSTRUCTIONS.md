# Miro AI Instructions — Self-Healing EC2 Fleet

Use this file to generate an editable technical architecture board in Miro AI. The desired result is a domain-oriented architecture diagram with explicit component communication, not a generic flowchart or mind map.

## Recommended Miro workflow

1. Open a Miro board and choose **Create with AI**.
2. Open **Sidekicks library → Formats → Diagram or mindmap**.
3. Select **Diagram** and use **Advanced processing** when available.
4. Paste the master prompt below.
5. Apply the result to the canvas, then use the refinement prompts in sequence.

Miro AI accepts semantic styling and exact HEX colors. All objects must remain editable Miro diagram objects.

## Master generation prompt

```text
ROLE
You are a senior AWS solutions architect and enterprise technical-diagram designer.

OBJECTIVE
Create a detailed, editable technical architecture diagram titled:
“Self-Healing EC2 Fleet — Technical Architecture”

Subtitle:
“Multi-AZ compute resilience through layered health checks and event-driven lifecycle remediation”

The diagram must explain both the deployed AWS components and how they communicate during normal traffic, failure detection, termination, replacement, bootstrap, readiness verification, and operational notification.

LAYOUT
Use a 16:10 landscape board with a clean white background. Organize the diagram as five numbered vertical domains from left to right. Keep consistent spacing, aligned cards, orthogonal connectors, minimal line crossings, and generous whitespace.

Domain 1 — Users / Operations — muted green #F5FBF6, border #198038
Domain 2 — Edge / Ingress — muted blue #F5F9FF, border #1769AA
Domain 3 — AWS / Multi-AZ Compute Runtime — muted orange #FFF9F2, border #F57C00
Domain 4 — Self-Healing Control Plane — muted purple #FAF7FF, border #6D28D9
Domain 5 — Operations / Notifications — muted red #FFF7F8, border #E11D48

Add a green outcome banner across the lower center and a compact legend along the bottom.

DOMAIN 1 — USERS / OPERATIONS
Add:
- Application Users
- Platform / SRE Team
- Service objectives card:
  - Availability target: 99.95%
  - Replacement RTO: less than 3 minutes
  - Zero-touch instance replacement
- Failure simulation card:
  - terminate an EC2 instance
  - degrade application readiness
  - force target-group health-check failure

DOMAIN 2 — EDGE / INGRESS
Add vertically aligned AWS service cards:
- Amazon Route 53 — DNS resolution
- AWS WAF — show translucent with dashed purple border and label “Production hardening backlog — not currently implemented”
- Application Load Balancer — public, cross-zone, TLS termination, target-group routing, continuous health checks, connection draining
- Security boundary card — “ALB security group accepts public HTTPS; EC2 security group accepts application traffic only from the ALB security group”

DOMAIN 3 — AWS / MULTI-AZ COMPUTE RUNTIME
Create an AWS Region boundary labelled “us-east-1 (N. Virginia)”.
Inside it, create a VPC boundary labelled “10.0.0.0/16”.
Inside the VPC, create three equal Availability Zone columns:

AZ-a:
- Public subnet 10.0.0.0/24 with NAT Gateway
- Private subnet 10.0.10.0/24 with two EC2 instances

AZ-b:
- Public subnet 10.0.1.0/24 with NAT Gateway
- Private subnet 10.0.11.0/24 with two EC2 instances

AZ-c:
- Public subnet 10.0.2.0/24 with NAT Gateway
- Private subnet 10.0.12.0/24 with two EC2 instances

Place one Auto Scaling Group boundary around all six EC2 instances and label it:
“Auto Scaling Group — min 3 / desired 6 / max 12 — ELB health checks”

Add a Launch Template card connected to the Auto Scaling Group and label it:
“Versioned AMI, instance type, security groups, IAM instance profile, user data”

The EC2 instances must have no public IP and accept application traffic only from the ALB security group.

DOMAIN 4 — SELF-HEALING CONTROL PLANE
Add these components as aligned service cards:
- Amazon EventBridge — routes Auto Scaling lifecycle events
- Terminate Handler Lambda — deregister target, drain connections, archive logs/session state
- Launch Handler Lambda — invoke bootstrap and readiness verification
- AWS Systems Manager Automation — runbook for bootstrap, configuration and readiness checks
- Amazon S3 — termination log and session-state archive
- IAM — separate least-privilege execution role for each Lambda
- Decision diamond — “Instance ready?”

Add lifecycle state labels:
- EC2_INSTANCE_TERMINATING
- Terminating:Wait
- EC2_INSTANCE_LAUNCHING
- Pending:Wait
- CompleteLifecycleAction(CONTINUE)

DOMAIN 5 — OPERATIONS / NOTIFICATIONS
Add vertically aligned cards:
- Amazon CloudWatch — CPU, latency, unhealthy host count, lifecycle and application logs
- AWS CloudTrail — management and data-plane API audit trail
- Amazon SNS Ops Topic — self-healing notifications
- On-call Engineer — email / Slack escalation channel

COMPONENT COMMUNICATION
Draw the following connections exactly:

Normal request path:
1. Application Users → Route 53: “HTTPS / DNS lookup”
2. Route 53 → AWS WAF: “planned inspection path”; use a dashed line because WAF is backlog
3. AWS WAF → Application Load Balancer: “HTTPS”
4. Application Load Balancer → EC2 instances across all three AZs: “requests + continuous target health checks”

Failure detection and termination path:
5. Failed ALB target health check → Auto Scaling Group: “target unhealthy”
6. Auto Scaling Group → EventBridge: “EC2_INSTANCE_TERMINATING / Terminating:Wait”
7. EventBridge → Terminate Handler Lambda: “lifecycle event”
8. Terminate Handler Lambda → Application Load Balancer: “deregister target + drain in-flight connections”
9. Terminate Handler Lambda → Amazon S3: “archive logs / session state”
10. Terminate Handler Lambda → Auto Scaling Group: “CompleteLifecycleAction(CONTINUE)”

Replacement and readiness path:
11. Launch Template → Auto Scaling Group: “replacement configuration”
12. Auto Scaling Group → new EC2 instance: “launch replacement”
13. Auto Scaling Group → EventBridge: “EC2_INSTANCE_LAUNCHING / Pending:Wait”
14. EventBridge → Launch Handler Lambda: “lifecycle event”
15. Launch Handler Lambda → Systems Manager Automation: “start automation runbook”
16. Systems Manager Automation → new EC2 instance: “bootstrap + configure + readiness checks”
17. Systems Manager Automation → decision diamond “Instance ready?”
18. Decision YES → Launch Handler Lambda: “ready”
19. Launch Handler Lambda → Auto Scaling Group: “CompleteLifecycleAction(CONTINUE)”
20. Auto Scaling Group → Application Load Balancer target group: “register / InService”
21. Decision NO → Systems Manager Automation: “retry or fail automation”; use a dashed feedback loop

Observability and notification:
22. ALB, Auto Scaling Group, EC2, Lambda and Systems Manager → CloudWatch: “metrics / logs / alarms”; use dotted gray lines
23. AWS API actions → CloudTrail: “audit events”; use dotted gray lines
24. Both Lambda handlers → SNS Ops Topic: “self-healing event notification”; use dashed red lines
25. SNS Ops Topic → On-call Engineer: “email / Slack alert”
26. On-call Engineer → green outcome banner: “operational feedback”; use a dashed green line

OUTCOME BANNER
Add this exact text:
“Self-healing outcome: unhealthy target isolated → connections drained → replacement launched → readiness verified → InService”

VISUAL RULES
- Use official AWS icons where Miro’s AWS shape pack is available.
- Otherwise use consistent rounded service cards with the AWS service name clearly visible.
- Do not use 3D or isometric icons.
- Use one icon style throughout the entire diagram.
- Use black solid arrows for primary request and control flow.
- Use purple dashed arrows for lifecycle and feedback flow.
- Use gray dotted arrows for telemetry and audit.
- Use red dashed arrows for notification and incident flow.
- Use green dashed arrows for validation and operational feedback.
- Keep all labels horizontal and readable at 100% zoom.
- Route connectors orthogonally and avoid crossing domain headings or component labels.
- Do not add services that are not listed.
- Do not depict AWS WAF as implemented.
- Do not place EC2 instances in public subnets.
- Do not place Lambda functions inside the Auto Scaling Group.
- Do not merge CloudWatch and CloudTrail into one component.
- Preserve all subnet CIDRs exactly.

LEGEND
Add a bottom legend for:
- Users / output
- Edge / ingress
- AWS runtime
- Automation / decision
- Operations / notifications
- Primary flow
- Lifecycle / feedback
- Telemetry / audit
- Notification flow
```

## Refinement prompt 1 — fix hierarchy and alignment

```text
Refine the generated diagram without changing its components or communications.

- Make all five numbered domains equal height.
- Keep Domain 3 wider than the other domains.
- Align the three Availability Zone columns precisely.
- Give each AZ one public subnet above one private subnet.
- Keep all six EC2 instances inside the private subnets and inside one Auto Scaling Group boundary.
- Align service cards to a consistent grid with equal dimensions.
- Move connector labels away from shapes and domain headings.
- Remove diagonal connectors where an orthogonal route is possible.
- Preserve all labels, CIDRs and lifecycle states exactly.
```

## Refinement prompt 2 — improve component communication

```text
Audit and refine the communication paths only.

- Ensure arrows have a clear source and target.
- Ensure the normal request path reads left to right.
- Ensure the termination and launch flows are visually distinguishable.
- Show CompleteLifecycleAction(CONTINUE) returning to the Auto Scaling Group from both Lambda handlers.
- Show Systems Manager acting on the replacement EC2 instance.
- Show ALB health checks reaching EC2 targets in all three Availability Zones.
- Keep telemetry lines dotted gray and behind primary flows.
- Keep lifecycle lines dashed purple.
- Keep notification lines dashed red.
- Add line jumps or reroute any unavoidable crossing.
- Do not add or remove components.
```

## Refinement prompt 3 — presentation polish

```text
Polish this as an enterprise architecture review artifact.

- Use a white canvas and accessible muted domain colors.
- Use a consistent professional sans-serif typeface.
- Make the title dominant, domain titles secondary and connector labels compact.
- Maintain generous whitespace.
- Remove decorative elements that do not communicate architecture.
- Keep the AWS WAF card translucent and explicitly labelled as backlog.
- Make the green self-healing outcome banner visually prominent.
- Keep the final diagram readable when exported at 1600 × 1000 pixels.
```

## Communication matrix for manual verification

| Source | Target | Communication | Style |
|---|---|---|---|
| Users | Route 53 | HTTPS / DNS lookup | Solid black |
| Route 53 | WAF | Planned inspection path | Dashed purple |
| WAF | ALB | HTTPS | Dashed purple while backlog |
| ALB | EC2 targets | Requests and health checks | Solid black |
| ASG | EventBridge | Terminating/launching lifecycle events | Dashed purple |
| EventBridge | Terminate Lambda | Termination event | Dashed purple |
| Terminate Lambda | ALB | Deregister and drain target | Dashed purple |
| Terminate Lambda | S3 | Archive logs/session state | Dashed purple |
| Terminate Lambda | ASG | Complete lifecycle action | Dashed purple |
| EventBridge | Launch Lambda | Launch event | Dashed purple |
| Launch Lambda | SSM Automation | Start runbook | Dashed purple |
| SSM Automation | New EC2 | Bootstrap and readiness checks | Dashed purple |
| Launch Lambda | ASG | Complete lifecycle action | Dashed purple |
| ASG | ALB target group | Register replacement / InService | Solid black |
| Platform components | CloudWatch | Metrics, logs and alarms | Dotted gray |
| AWS API actions | CloudTrail | Audit events | Dotted gray |
| Lambda handlers | SNS | Self-healing notification | Dashed red |
| SNS | On-call | Email / Slack | Solid red |

## Acceptance checklist

- [ ] Five numbered domains are present and correctly colored.
- [ ] Region, VPC, three AZs and six subnets are visible.
- [ ] All EC2 instances are inside private subnets.
- [ ] One NAT Gateway exists in every public subnet.
- [ ] The Auto Scaling Group spans all three AZs.
- [ ] Both lifecycle-hook states are shown.
- [ ] Termination and replacement flows can be followed without ambiguity.
- [ ] WAF is marked as backlog, not implemented.
- [ ] CloudWatch, CloudTrail and SNS are separate components.
- [ ] Primary, lifecycle, telemetry and notification lines use different styles.
- [ ] The diagram contains no invented AWS services.
- [ ] All objects remain editable in Miro.

## Miro references

- Miro AI diagrams and semantic color input: https://help.miro.com/hc/en-us/articles/28782102127890-Miro-AI-with-Diagrams-and-mindmaps
- Miro AI prompting guide: https://help.miro.com/hc/en-us/articles/30226743358226-Miro-AI-prompting-guide
- Miro diagrams and AWS shape-pack availability: https://help.miro.com/hc/en-us/articles/4403634496402-Miro-for-mapping-diagramming
