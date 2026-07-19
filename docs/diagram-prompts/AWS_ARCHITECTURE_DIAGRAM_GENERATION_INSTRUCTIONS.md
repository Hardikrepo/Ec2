# AWS Architecture Diagram Generation Instructions

Use this document with Miro MCP, Miro AI, Draw.io AI, or another diagram agent. It is intentionally written to prevent the generator from producing a flowchart.

## Artifact type

Create a **deployment and infrastructure architecture diagram**, not a flowchart, workflow, mind map, UML activity diagram, or business-process diagram.

The primary visual grammar must be:

- Nested infrastructure boundaries
- AWS service icons or architecture cards
- Deployed-resource relationships
- Network and security boundaries
- Availability Zone and subnet placement
- Labeled communication connectors

The main diagram answers these questions:

1. Where is each component deployed?
2. Which infrastructure boundary contains it?
3. Which components communicate?
4. What protocol, event, or AWS API connects them?
5. How does the fleet recover when an instance becomes unhealthy?

## Strict anti-flowchart rules

These rules are mandatory:

- Do not use Start, End, Process, Input/Output, or generic workflow symbols.
- Do not arrange components as a single chain of procedural steps.
- Do not use decision diamonds in the infrastructure view.
- Do not number service components as sequential workflow steps.
- Do not repeat the same AWS component at multiple stages of a process.
- Do not place sentences or implementation paragraphs inside service nodes.
- Do not use swimlanes to represent AWS infrastructure boundaries.
- Do not represent Availability Zones or subnets as ordinary process boxes.
- Do not invent components that cannot be verified from the project documentation.
- Do not mix the detailed recovery sequence into the primary request path.

If behavioral detail is needed, create a separate sequence diagram beside the architecture diagram. Do not convert the main architecture into a flowchart.

## Source of truth

Analyze these project files before generating the diagram:

- `README.md`
- `PLAN.md`
- `ARCHITECTURE.md`
- Infrastructure source files present in the repository

Classify every resource as one of:

- **Implemented**: verified in infrastructure or application source
- **Planned**: described in project documentation but not implemented
- **External**: actor or system outside AWS

Use a dashed border and a visible `PLANNED` label for planned resources. Never present a planned resource as deployed.

## Required canvas and hierarchy

Use a 16:9 landscape canvas with a white background. Build the hierarchy from the outside inward:

```text
External actors
  AWS Cloud
    AWS Region: us-east-1
      VPC: 10.0.0.0/16
        Edge and ingress
        Availability Zone A
          Public subnet: 10.0.0.0/24
          Private subnet: 10.0.10.0/24
        Availability Zone B
          Public subnet: 10.0.1.0/24
          Private subnet: 10.0.11.0/24
        Availability Zone C
          Public subnet: 10.0.2.0/24
          Private subnet: 10.0.12.0/24
        Regional self-healing and operations services
  Operations and notification recipients
  Infrastructure delivery
```

Containment communicates deployment. Connectors communicate interaction. Do not use connector chains to simulate containment.

## Required architecture composition

### Left: external access and delivery

Place outside the AWS Cloud boundary:

- Application Users
- Platform / SRE Team
- Terraform or CI/CD deployment workstation, if verified

### Center: AWS workload topology

Inside the AWS Cloud and Region boundaries, show:

- Amazon Route 53
- Internet Gateway
- Application Load Balancer
- ALB listener and target group as compact child labels or attached cards
- VPC and three Availability Zones
- Public and private subnet pairs
- NAT Gateway in each public subnet when verified
- Auto Scaling Group spanning the three private subnets
- EC2 instances distributed across private subnets
- Launch Template attached to the Auto Scaling Group
- ALB security group and EC2 security group as compact security annotations

The Auto Scaling Group must be one logical boundary spanning all three Availability Zones. EC2 instances must remain inside private subnets and must not have public IP addresses.

### Bottom: regional control and observability plane

Place these below the workload topology, inside the Region but outside all subnets unless the implementation proves otherwise:

- Amazon EventBridge
- Terminate Handler Lambda
- Launch Handler Lambda
- AWS Systems Manager Automation
- Amazon S3 archive
- Amazon CloudWatch
- AWS CloudTrail
- Amazon SNS
- IAM execution roles as attached security annotations

Do not place Lambda, EventBridge, CloudWatch, CloudTrail, SNS, IAM, or S3 inside the Auto Scaling Group.

### Right: operational outcome

Place outside the AWS Cloud boundary:

- On-call Engineer / Operations Team
- Recovery outcome annotation

## Architecture relationships

Draw direct, labeled relationships. Each connector must have exactly one source and one target.

### Request traffic

- Application Users -> Route 53: `DNS lookup`
- Application Users / Internet -> Application Load Balancer: `HTTPS 443`
- Application Load Balancer -> Target Group: `listener forwards request`
- Target Group -> EC2 fleet: `application traffic`
- Application Load Balancer -> EC2 fleet: `target health checks`

### Fleet configuration

- Launch Template -> Auto Scaling Group: `AMI, instance type, IAM, user data`
- Auto Scaling Group -> EC2 instances: `maintains desired capacity`
- Auto Scaling Group -> Target Group: `registers and deregisters targets`

### Termination lifecycle

- Auto Scaling Group -> EventBridge: `EC2_INSTANCE_TERMINATING / Terminating:Wait`
- EventBridge -> Terminate Handler Lambda: `matched lifecycle event`
- Terminate Handler Lambda -> Target Group: `deregister target and drain`
- Terminate Handler Lambda -> Amazon S3: `archive logs / session state`
- Terminate Handler Lambda -> Auto Scaling Group: `CompleteLifecycleAction(CONTINUE)`

### Replacement lifecycle

- Auto Scaling Group -> EC2 fleet: `launch replacement`
- Auto Scaling Group -> EventBridge: `EC2_INSTANCE_LAUNCHING / Pending:Wait`
- EventBridge -> Launch Handler Lambda: `matched lifecycle event`
- Launch Handler Lambda -> Systems Manager Automation: `start automation runbook`
- Systems Manager Automation -> replacement EC2 instance: `bootstrap, configure, verify readiness`
- Launch Handler Lambda -> Auto Scaling Group: `CompleteLifecycleAction(CONTINUE)`
- Auto Scaling Group -> Target Group: `register healthy replacement`

### Observability and notification

- ALB, Auto Scaling Group, EC2, Lambda, and Systems Manager -> CloudWatch: `metrics, logs, alarms`
- AWS management API activity -> CloudTrail: `audit events`
- Lambda handlers -> SNS: `recovery notification`
- SNS -> On-call Engineer: `email / ChatOps alert`

## Connector language

- Solid dark line: user request or data-plane traffic
- Dashed purple line: lifecycle event or remediation control
- Dotted gray line: telemetry, logging, or audit
- Dashed red line: alarm or operational notification
- Dashed blue line: deployment or management access

Use orthogonal connectors with arrowheads. Route telemetry behind primary traffic. Avoid diagonal lines, crossings, and connectors passing through cards or headings.

## Visual system

- Title: `Self-Healing EC2 Fleet - AWS Technical Architecture`
- Subtitle: `Multi-AZ compute resilience using ALB health checks and Auto Scaling lifecycle automation`
- Use official AWS Architecture Icons when the tool supports them.
- Use one AWS icon generation consistently; do not mix AWS 3D, AWS4, legacy and generic icon styles.
- Use AWS orange for compute and lifecycle emphasis.
- Use green outlines for VPC and subnet boundaries.
- Use blue for ingress and management.
- Use purple for automation.
- Use red only for alerts and security restrictions.
- Keep cards white with subtle borders and short labels.
- Use consistent padding, card dimensions, typography and grid alignment.
- Put details such as CIDRs, ports and lifecycle states in secondary labels.
- Include a compact legend at the bottom.

## Miro MCP master prompt

Replace the board URL before submitting.

```text
Analyze C:\Users\hardi\self-healing-ec2-fleet and read
docs/AWS_ARCHITECTURE_DIAGRAM_GENERATION_INSTRUCTIONS.md completely.

Use Miro MCP diagram_create to create the diagram on:
https://miro.com/app/board/REPLACE_WITH_BOARD_ID/

The requested artifact is an AWS deployment and infrastructure architecture
diagram. It is explicitly NOT a flowchart, workflow, mind map, or UML activity
diagram.

Follow the document's containment hierarchy, component placement, relationship
list, connector language, visual system, and anti-flowchart rules exactly.
First model the AWS Cloud, Region, VPC, Availability Zones, subnets, and Auto
Scaling Group as nested architecture boundaries. Then place each service once
in its correct boundary. Finally add labeled communication connectors.

Use official AWS icons when available. Keep all objects editable. Use a 16:9
landscape layout, consistent grid alignment, generous whitespace, orthogonal
connectors, and no crossed lines.

If Miro diagram_create cannot express the required nested architecture cleanly,
use layout_create with frames, shapes, icons/images, text, and connectors. Do not
fall back to a procedural flowchart.

After creation, read the diagram back, verify it against the acceptance checklist,
and correct containment, alignment, labels, overlaps, and connector crossings.
```

## Draw.io master prompt

```text
Read docs/AWS_ARCHITECTURE_DIAGRAM_GENERATION_INSTRUCTIONS.md completely and
create an editable Draw.io AWS deployment architecture diagram.

Do not generate a flowchart. Use containers for AWS Cloud, Region, VPC,
Availability Zones, public/private subnets, and the Auto Scaling Group. Use
connectors only for component communication, never for infrastructure hierarchy.

Use the mxgraph.aws4.* shape library for AWS services and use native Draw.io
container shapes for network boundaries. Use one service icon per logical AWS
resource, orthogonal connectors, labeled protocols/events, consistent spacing,
and a 16:9 landscape canvas. Follow every component, relationship, placement,
style, and anti-flowchart requirement in the instruction document.

Return an editable .drawio diagram, not a flattened image.
```

## Refinement prompt

Run this after the first generation:

```text
Audit the existing diagram as an AWS architecture reviewer. Do not redesign it
as a flowchart and do not add new services.

Verify that containment represents deployment and arrows represent communication.
Correct every misplaced service. Align the three Availability Zones and subnet
pairs. Ensure the Auto Scaling Group spans the private subnets. Make the normal
request path visually dominant and keep lifecycle automation below it. Remove
crossed or diagonal connectors, shorten labels, standardize card sizes, increase
whitespace, and preserve all verified architecture relationships.
```

## Acceptance checklist

- [ ] The result is immediately recognizable as an AWS infrastructure architecture diagram.
- [ ] AWS Cloud, Region, VPC, Availability Zones, subnets, and Auto Scaling Group are nested boundaries.
- [ ] No Start/End nodes, process boxes, decision diamonds, or sequential flowchart numbering exist.
- [ ] Every logical AWS service appears only once.
- [ ] EC2 instances are inside private subnets and the Auto Scaling Group.
- [ ] Regional managed services are outside subnets unless source code proves otherwise.
- [ ] Request, lifecycle, telemetry, notification, and deployment connectors have distinct styles.
- [ ] Every connector is labeled and has an unambiguous source and target.
- [ ] Primary traffic reads left to right.
- [ ] The self-healing control loop is visible without dominating the infrastructure topology.
- [ ] Planned resources are visibly marked and are not presented as deployed.
- [ ] No connector crosses a component label or boundary heading.
- [ ] All generated objects remain editable.

