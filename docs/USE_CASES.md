# 100 Real-World Use Cases

Each entry maps a concrete failure mode to how the fleet's control loop (ALB health check → ASG lifecycle hook → terminate/launch Lambda → SSM verify → SNS notify) resolves it without human intervention.

## E-Commerce & Retail

1. **Black Friday traffic spike** — one instance chokes under load and starts failing health checks while the rest of the fleet holds; it's cycled out instead of dragging down the whole tier.
2. **Checkout service memory leak** — a Node/Java checkout process degrades over days; `/health` times out, instance is drained (in-flight carts preserved) and replaced.
3. **Bad third-party payment SDK update** — one instance's outbound calls to a payment gateway start hanging, tying up threads until health checks fail; auto-replaced before it backs up the whole queue.
4. **Product search index corruption on one node** — a single instance serves stale/broken search results; if wired to an app-level health check, it's pulled from rotation.
5. **Flash-sale bot traffic overwhelming a subset of instances** — targeted load skews unevenly across the ASG; unhealthy nodes are replaced while WAF (once added) blocks the bots.
6. **Cart session store connection exhaustion** — an instance runs out of DB connections and stops responding; drained and replaced, session state archived to S3 first.
7. **Regional inventory sync failure** — an instance pinned to a broken read replica serves wrong stock counts; caught by a custom health check and cycled.
8. **Post-deploy canary instance going bad** — a rolling deploy pushes a crashing build to a subset; those instances fail health checks and get replaced (with alerting so the deploy itself still gets caught).
9. **Holiday-season kernel/OS-level host degradation** — underlying AWS hardware issue causes EC2 status check failures independent of app health; ASG replaces the instance automatically.
10. **Multi-AZ failover during a zone-level event** — one AZ degrades; min-3-instance multi-AZ config keeps 99.95% availability while unhealthy nodes in the affected AZ are replaced.

## SaaS / B2B Platforms

11. **Tenant-specific workload causing noisy-neighbor CPU starvation** — one instance pegged at 100% CPU by a single heavy tenant fails health checks and is replaced, isolating the blast radius.
12. **Background job worker deadlock** — a queue-consuming instance hangs on a poison message; health check fails, instance recycled, message requeued.
13. **License/auth token expiry bug on one node** — a stale cached credential causes 500s from one instance only; auto-replaced, fresh instance pulls a valid token via bootstrap.
14. **API gateway backend instance running out of file descriptors** — long-running process leaks FDs over weeks; self-healing resets the clock without a scheduled maintenance window.
15. **Customer-reported "random 502s"** — intermittent failures traced to one flapping instance; ALB health checks catch what ad-hoc monitoring missed, and it's replaced before the next support ticket.
16. **SaaS trial-tier abuse causing resource exhaustion** — one instance absorbs disproportionate free-tier traffic and degrades; cycled out while rate-limiting is fixed upstream.
17. **Feature-flag rollout crash-looping a subset of instances** — flag causes a startup crash on some but not all instances (race condition); crash-looping ones are auto-replaced and paged for investigation.
18. **Multi-tenant DB connection pool starvation** — an instance holds stale/leaked pooled connections; replaced, new instance starts with a clean pool.
19. **SSO integration outage on one node's cached IdP metadata** — stale metadata causes auth failures from one instance; replacement bootstrap pulls fresh config via SSM.
20. **Log-forwarding agent crash silently degrading an instance** — sidecar crash causes upstream health probe timeouts; instance replaced, logs preserved via S3 archive first.

## Fintech & Banking

21. **Mid-transaction instance failure during ACH batch processing** — graceful drain (not hard kill) ensures in-flight transactions complete or are cleanly requeued, critical for financial consistency.
22. **Fraud-scoring service instance hangs on a malformed payload** — health check fails, instance replaced, malformed request logged to CloudTrail for audit.
23. **PCI-DSS compliance requirement for prompt patching** — SSM Automation bootstrap on every replacement ensures new instances always launch with the latest AMI/patch level, satisfying continuous-compliance audits.
24. **Ledger-service instance clock drift causing reconciliation errors** — health check (or custom NTP-drift check) catches the node before it writes bad timestamps; replaced.
25. **Regulatory audit trail requirement** — CloudTrail + CloudWatch Logs capture every lifecycle event (who/what/when an instance was cycled), satisfying SOC 2 / audit evidence requests.
26. **Trading-hours SLA (sub-3-minute recovery)** — RTO < 3 min target ensures a degraded instance during market hours is replaced before it materially affects order execution.
27. **Session-token leakage prevention on terminated instances** — drain step archives/scrubs session state to S3 rather than letting a terminated instance's local disk (with tokens in memory) just vanish uncleanly.
28. **KYC document-processing instance stuck on a corrupt upload** — health check timeout catches the hang; instance replaced, stuck job requeued to a healthy node.
29. **Wire-transfer approval service failover** — multi-AZ + auto-replace ensures no single points of failure in a workflow where downtime has direct financial/legal consequences.
30. **Insider-threat/config-drift detection** — if an instance's config diverges from the Launch Template baseline (manual SSH changes), it can be flagged and cycled back to a known-good state.

## Healthcare & Life Sciences

31. **Patient portal instance degrading during appointment booking windows** — self-healing keeps the portal available during peak morning booking traffic without manual scaling intervention.
32. **HL7/FHIR interface engine instance memory bloat** — long-running message-processing node leaks memory over a shift; replaced automatically before it drops messages.
33. **HIPAA audit logging requirement** — CloudTrail records every instance lifecycle action, supporting HIPAA technical safeguards documentation.
34. **Telehealth session-handling instance failure mid-visit** — drain-before-terminate reduces (though doesn't eliminate) risk of abrupt session drops during a live video consult.
35. **Lab-results processing pipeline node stuck on a malformed HL7 message** — health check catches the hang, instance replaced, poison message isolated for manual review.
36. **After-hours on-call reduction for clinical IT staff** — routine instance failures at 3am are resolved automatically; SNS notifies but doesn't require action, reducing burnout for a small ops team.
37. **Disaster-recovery drill for a hospital system** — multi-AZ self-healing fleet is the baseline building block demonstrated in DR tabletop exercises.
38. **Patch compliance for a legacy Windows EC2 fleet running clinical software** — every replacement re-bootstraps from a patched AMI via SSM, avoiding manual patch-Tuesday fleet-wide reboots.
39. **PHI data residency enforcement** — instances always relaunch in approved subnets/AZs per the Launch Template, preventing accidental cross-region drift.
40. **Insurance-claims batch job instance crash** — mid-batch failure triggers drain + S3 archive of partial state, replacement instance resumes from checkpoint.

## Media, Streaming & Gaming

41. **Live-stream ingest node overload during a major sports event** — unhealthy ingest instances are cycled out in real time as viewership spikes.
42. **Game server instance desync causing player disconnects** — health check (custom TCP/game-protocol probe) detects a desynced server and replaces it, with graceful player-session draining.
43. **Video transcoding worker stuck on a corrupt input file** — health check timeout catches the hang; job requeued to a fresh instance.
44. **CDN origin server instance serving stale cache** — cycled automatically if cache-invalidation health checks fail.
45. **Esports tournament infrastructure reliability** — self-healing fleet is the resilience layer behind a match server pool where downtime during a broadcast is highly visible and reputationally costly.
46. **Ad-insertion service instance failure mid-stream** — replaced without interrupting the broader stream, since only the failed instance's segment is affected.
47. **User-generated content upload service instance disk-full condition** — health check (disk-space-aware) catches it before uploads start failing, instance replaced with clean storage.
48. **Matchmaking service instance queue backup** — a hung matchmaking node is detected via custom health metric and cycled, preventing player queue times from silently growing.
49. **Post-launch day-one patch traffic surge** — new game release causes massive concurrent load; self-healing keeps unhealthy nodes from compounding an already-stressed fleet.
50. **Regional latency degradation on one instance** — CloudWatch alarm on p99 latency triggers investigation/replacement even before hard health-check failure.

## Travel & Hospitality

51. **Airline booking engine instance hang during a fare-sale event** — high-concurrency booking traffic degrades one node; replaced before it causes double-bookings or timeouts.
52. **Hotel PMS integration instance losing connectivity to a property system** — health check catches the broken integration, instance cycled, connection re-established on the fresh node.
53. **Flight-status API instance serving stale data during an IRROPS event** (irregular operations, e.g., mass cancellations) — self-healing ensures the API tier stays responsive when it matters most.
54. **Loyalty-points calculation service instance crash mid-batch** — drain + S3 archive preserves partial calculation state for reprocessing.
55. **Check-in kiosk backend instance overload during a holiday travel peak** — unhealthy backend nodes replaced automatically ahead of a known traffic pattern (paired with scheduled scaling).
56. **Dynamic pricing engine instance stuck in a bad state** — serving incorrect prices; custom health check catches logical (not just network) failures.
57. **Multi-region DR for a booking platform** — self-healing fleet in each region is the unit of resilience that a broader multi-region failover strategy builds on top of.
58. **Third-party GDS (global distribution system) connector instance timeout cascade** — one instance's hung GDS connections are isolated and replaced before they exhaust a shared connection pool.

## Logistics & Supply Chain

59. **Warehouse management system instance losing sync with barcode scanners** — health check (custom) detects desync, instance replaced during a shift change window.
60. **Route-optimization batch job instance running out of memory on a large job** — replaced, job requeued to a fresh instance with clean memory.
61. **Real-time package-tracking API instance degradation during peak shipping season** (e.g., holiday e-commerce surge) — self-healing keeps tracking updates flowing.
62. **EDI (Electronic Data Interchange) processing node stuck on a malformed file** — health check timeout isolates the hang, instance replaced, bad file quarantined.
63. **Fleet-telemetry ingestion instance overload from IoT sensor burst** — unhealthy ingestion nodes cycled as sensor data volume spikes.
64. **Cold-chain monitoring alert service instance failure** — critical for pharma/food logistics; self-healing minimizes the window where temperature-breach alerts could be missed.
65. **Customs/compliance document processing instance crash** — drain preserves in-flight document state before replacement.

## Government & Public Sector

66. **Citizen services portal instance failure during tax season or benefits enrollment period** — self-healing absorbs predictable seasonal load spikes without manual intervention.
67. **FedRAMP/continuous-monitoring patch compliance** — every instance replacement launches from an approved, patched AMI, supporting continuous ATO (Authority to Operate) requirements.
68. **Emergency alert system backend instance degradation** — high-availability requirement (life-safety adjacent) makes automatic sub-3-minute recovery directly relevant.
69. **Public records request processing instance stuck on a large query** — health check catches the hang, instance replaced, query killed and logged.
70. **Election-night results reporting infrastructure** — a highly visible, short-duration, high-traffic event where self-healing under load is the difference between "site is fine" and "site is down" headlines.
71. **Unemployment benefits portal surge during an economic downturn** — self-healing fleet plus ASG scaling handles unpredictable demand spikes without a war-room scaling event.

## AdTech, Marketing & Data

72. **Real-time bidding (RTB) instance latency degradation** — ad exchanges have strict SLA latency requirements (~100ms); an instance breaching that is caught by a latency-based CloudWatch alarm and cycled before it hurts the exchange relationship.
73. **Marketing email-send worker stuck mid-batch** — health check timeout catches the hang, batch resumes on a fresh instance, avoiding duplicate sends.
74. **Clickstream ingestion instance dropping events under load** — unhealthy ingestion nodes replaced, minimizing data loss for downstream analytics.
75. **A/B testing assignment service instance serving inconsistent variants** — custom health check on assignment-consistency catches a logic-level failure, not just a network one.
76. **Attribution pipeline instance crash during a campaign launch** — drain preserves partial attribution data before replacement.
77. **Customer data platform (CDP) instance connection pool exhaustion during a major campaign send** — replaced automatically instead of manually paged at 2am.

## Internal DevOps / Enterprise IT

78. **CI/CD runner instance stuck on a hung build** — health check timeout recycles the runner, unblocking the pipeline without manual intervention.
79. **Internal wiki/Confluence-alternative instance degradation** — lower-stakes but still benefits from the same pattern, demonstrating the architecture generalizes beyond customer-facing systems.
80. **VPN/bastion host instance failure** — self-healing keeps internal remote-access infrastructure available (with tighter security-group scoping than public-facing tiers).
81. **Internal API gateway instance memory leak from a chatty microservice** — cycled automatically before it degrades other internal consumers.
82. **Monitoring/observability stack self-hosting (e.g., self-hosted Prometheus/Grafana instance)** — ironic but real: the monitoring system itself needs to be resilient, and this pattern applies recursively.
83. **On-call rotation reduction as an explicit engineering goal** — the project's core pitch to an eng org: fewer 2am pages for "just restart the instance" class incidents.
84. **Compliance-driven immutable infrastructure adoption** — replacing instances via SSM-bootstrapped Launch Templates (rather than patching in place) supports an org-wide push toward immutable infra.
85. **Cost optimization via right-sized min/max ASG bounds combined with self-healing** — avoids over-provisioning "just in case" since unhealthy capacity is replaced rather than needing standby buffers.
86. **Chaos-engineering validation target** — the fleet itself becomes the system under test in chaos experiments (e.g., randomly terminating instances to verify the self-healing loop actually works, à la Chaos Monkey).
87. **Blue/green or canary deployment safety net** — if a canary batch of instances fails health checks post-deploy, they're cycled automatically while the deploy pipeline gets a clear signal to halt.
88. **Internal ML feature-store instance degradation** — feature-serving nodes for ML pipelines benefit from the same recovery loop as customer-facing services.
89. **Legacy monolith lift-and-shift to EC2 with limited refactoring budget** — self-healing gives a legacy app HA characteristics without rewriting it for containers/serverless.
90. **Log-shipping agent failure silently causing observability gaps** — instance-level health check tied to agent liveness catches "app is fine but we're blind" scenarios.

## Cross-Cutting / Architectural Scenarios

91. **Instance-level security patch (CVE) rollout** — updating the Launch Template's AMI and letting natural instance cycling (or a forced refresh) roll the patch out fleet-wide gradually.
92. **Spot Instance interruption handling** — the same lifecycle-hook pattern (adapted for `EC2_SPOT_INSTANCE_TERMINATION`) can gracefully drain Spot capacity before AWS reclaims it, not just handle health-check failures.
93. **Cross-region disaster recovery drill** — demonstrating that a self-healing fleet in a secondary region can absorb failover traffic from a primary-region outage.
94. **Zero-downtime AMI rotation for base-image security hardening** — new hardened AMI rolled into the Launch Template; instances cycle onto it over time without a maintenance window.
95. **Capacity-aware self-healing during a dependency outage** (e.g., a downstream DB is slow) — distinguishing "my instance is broken" from "a dependency is broken" so the fleet doesn't churn-replace every instance chasing a problem replacement can't fix (an important design consideration, not just a use case).
96. **Multi-tenant SaaS "noisy neighbor" isolation at the infra layer** — reinforces #11 at an architectural level: unhealthy-node replacement as a blast-radius containment tool, not just an uptime tool.
97. **Interview/portfolio narrative** — concretely: "I designed and (partially) built a production-grade self-healing compute tier using ASG lifecycle hooks, EventBridge, and Lambda, targeting sub-3-minute RTO and 99.95% availability" is a strong, specific talking point backed by an actual architecture doc.
98. **Cost-of-downtime justification for stakeholders** — RTO/availability targets in this project's README give a concrete number ("99.95% = ~4.4 hrs/year downtime budget") to anchor a business case for investing in automation.
99. **Baseline for a service-mesh or Kubernetes migration comparison** — this EC2-native pattern is a useful "before" state to contrast against if the org later evaluates EKS/ECS with built-in self-healing, showing you understand the tradeoffs of each.
100. **Template for other stateless-tier self-healing projects** — the same lifecycle-hook + Lambda + SSM pattern generalizes to any stateless EC2 fleet (internal tools, batch workers, API tiers) beyond this specific capstone, making this a reusable reference architecture.

---

*Note: many of these (custom health checks on latency/logic/queue-depth rather than just TCP/HTTP reachability) require extending the health-check layer beyond the base ALB target-group check described in `ARCHITECTURE.md`. Worth flagging in `PLAN.md` if any of these get prioritized.*
