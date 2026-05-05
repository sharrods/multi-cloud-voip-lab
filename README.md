# Multi-Cloud VoIP Lab

Production-grade carrier VoIP infrastructure deployed across **AWS, GCP, Oracle Cloud, and Azure** — fully automated with Terraform, Ansible, Docker, and a custom observability stack.

Built to apply enterprise voice engineering to modern DevOps infrastructure — real deployments, real incidents, real fixes.

**[Live Architecture Diagram](https://sharrods.github.io/multi-cloud-voip-lab/architecture.html)** · **[Portfolio](https://sharrods.github.io)**

---

## Architecture

| Cloud | Role | Deployment Method |
|-------|------|-------------------|
| **Oracle Cloud** | Primary entry point · Load balancer · Emergency fallback | Docker (manual) |
| **GCP** | VoIP stack + central monitoring hub · 50% traffic | Docker Compose |
| **AWS** | VoIP cluster · 50% traffic · K8s migration candidate | Terraform + Ansible + Docker |
| **Azure** | Control plane · Bastion host · Operations hub | Hardened bastion |

---

## Call Distribution & Failover

Under normal operation calls enter via Oracle and are split 50/50 between GCP and AWS. SRV records at the carrier level enable automatic failover if Oracle goes down.

```
Normal:
  Twilio/Carriers → Oracle OpenSIPS (load balancer)
                  → GCP OpenSIPS (50%) → GCP FreeSWITCH
                  → AWS OpenSIPS (50%) → AWS FreeSWITCH

Oracle down:
  Twilio/Carriers → SRV failover → GCP or AWS OpenSIPS directly

AWS down:
  Oracle → GCP OpenSIPS (100%) → GCP FreeSWITCH

GCP down:
  Oracle → AWS OpenSIPS (100%) → AWS FreeSWITCH

Both AWS + GCP down:
  Oracle OpenSIPS → plays emergency announcement
```

---

## Stack

**VoIP / Media**
- [OpenSIPS](https://opensips.org/) — SIP proxy and session border controller
- [FreeSWITCH](https://freeswitch.org/) — Media server
- [RTPEngine](https://github.com/sipwise/rtpengine) — RTP proxy and NAT traversal
- [Redis](https://redis.io/) — Registration backend and shared state (all clouds)

**Infrastructure / Automation**
- [Terraform](https://www.terraform.io/) — AWS infrastructure provisioning (VPC, EC2, security groups, EIPs)
- [Ansible](https://www.ansible.com/) — AWS configuration management and container deployment
- [Docker Compose](https://docs.docker.com/compose/) — GCP service orchestration (13 services)
- [Docker](https://www.docker.com/) — Oracle service deployment (manual, no Compose)
- [Justfile](https://just.systems/) — Task automation and workflow orchestration

**Observability**
- [Prometheus](https://prometheus.io/) — Centralized metrics collection on GCP (17 targets)
- [Grafana](https://grafana.com/) — Dashboards for OpenSIPS, FreeSWITCH, RTPEngine, system
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) — Alert routing to Slack, Gmail, and ntfy
- Custom Python exporters — opensips-exporter (:9153), freeswitch-exporter (:9282), rtpengine-exporter (:9092)

**Testing / Debugging**
- [SIPp](https://sipp.sourceforge.net/) — SIP load testing and regression testing
- [sngrep](https://github.com/irontec/sngrep) — SIP ladder analysis and debugging
- Custom SIPP scenario framework with Justfile orchestration

---

## Service Map

| Cloud | VM | Services |
|-------|----|----------|
| Oracle | oracle-vm1 (Signaling) | OpenSIPS · Redis |
| Oracle | oracle-vm2 (Media) | FreeSWITCH · RTPEngine · Redis |
| GCP | gcp-voip (All-in-One) | OpenSIPS · FreeSWITCH · RTPEngine · Redis · Prometheus · Grafana · Alertmanager · SBC Dashboard |
| AWS | aws-signaling | OpenSIPS · Redis |
| AWS | aws-media | FreeSWITCH · RTPEngine · Redis |
| Azure | bastion | sngrep · SIPp · Ansible · Terraform · Justfile |

---

## Repository Structure

```
multi-cloud-voip-lab/
├── aws/
│   ├── terraform/          # VPC, EC2, security groups, EIPs
│   └── ansible/            # Roles: OpenSIPS, FreeSWITCH, RTPEngine, Redis, Docker, monitoring
├── gcp/
│   ├── opensips/           # OpenSIPS SIP proxy config
│   ├── prometheus/         # Prometheus config, alert rules
│   └── grafana/            # Dashboards and datasources
├── oracle/
│   ├── vm1-signaling/      # OpenSIPS config
│   └── vm2-media/          # FreeSWITCH, RTPEngine configs
├── azure/
│   ├── sipp-test-framework/  # SIPP testing framework with Justfile
│   ├── sipp-scenarios/       # UAC scenarios (basic, redirect, media, load)
│   └── scripts/              # Exporter deployment and automation scripts
├── monitoring/
│   ├── opensips-exporter/    # Custom Python Prometheus exporter
│   ├── freeswitch-exporter/  # Custom Python Prometheus exporter
│   └── rtpengine-exporter/   # Custom Python Prometheus exporter
└── docs/
    ├── index.html            # Live architecture diagram
    └── architecture.html     # Live architecture diagram
```

---

## Monitoring Architecture

```
All Clouds (exporters) → GCP Prometheus :9090 → Grafana :3000
                                    ↓
                         Alertmanager → Slack · Gmail · ntfy
```

**17 scrape targets across all clouds:**

| Exporter | Port | Clouds |
|----------|------|--------|
| opensips-exporter | 9153 | GCP · AWS · Oracle |
| freeswitch-exporter | 9282 | GCP · AWS · Oracle |
| rtpengine-exporter | 9092 | GCP · AWS · Oracle |
| redis-exporter | 9121 | GCP · AWS · Oracle |
| node-exporter | 9100 | All clouds |

---

## Custom Prometheus Exporters

Three Python exporters written from scratch to expose VoIP-specific metrics not available in standard exporters:

- **opensips-exporter** — SIP dialog counts, transaction rates, memory usage via MI FIFO interface
- **freeswitch-exporter** — Active channels, call duration, codec stats via ESL
- **rtpengine-exporter** — Active sessions, packet loss, jitter via control socket

All exporters run as Docker containers with explicit port mapping and `--restart unless-stopped`.

---

## Infrastructure Details

### Oracle Cloud (Docker — Manual)
- 2x AMD E2.1.Micro (us-ashburn) — free tier
- VM1: OpenSIPS + Redis (signaling) · VM2: FreeSWITCH + RTPEngine + Redis (media)
- Primary call entry point — load balances 50/50 between GCP and AWS
- Hardest deployment in the lab — 1GB RAM VMs, no Docker Compose, each container managed individually
- Real-world challenge: VMs crash under load, require rebuild

### GCP (Docker Compose)
- e2-medium (us-central1-c)
- 13 services on a single VM — full VoIP stack + complete monitoring hub
- Central Prometheus scrapes all 17 targets across all clouds
- Real-world challenge: Free tier killed the server mid-deployment — IP changed, broke all scrapers across every cloud, had to re-add ACL rules in Azure and security groups in AWS

### AWS (Terraform + Ansible — Cleanest Build)
- 2x EC2 (us-east-1) — aws-signaling + aws-media
- Infrastructure via Terraform, configuration via Ansible
- Most reproducible and stable deployment
- Kubernetes migration planned

### Azure (Control Plane — Zero Call Traffic)
- Standard_B2ats_v2 ARM64 (Norway East)
- Hardened bastion — SSH key auth only, ProxyJump to all cloud VMs
- Full SIP debug toolkit: sngrep, SIPp, ngrep, custom scripts
- Justfile automation for all repeatable operations

---

## Security Architecture

- **Bastion host pattern** — all infrastructure access routes through Azure
- **SSH ProxyJump** — no direct public SSH to VoIP nodes
- **Key-based auth only** — no password authentication anywhere
- **Least-privilege security groups** — per-service port restrictions
- **Secrets management** — no credentials in version control

---

## Key Technical Challenges Solved

- Fixed OpenSIPS `onreply_route`/`failure_route` syntax requiring explicit block names (`[DEFAULT]`)
- Resolved Docker exporter bridge networking — must use explicit port mapping, not `--network host`, on AWS
- Debugged SIP ACK routing failures and SIPp blank Request-URI scenarios
- Fixed OpenSIPS container healthcheck case mismatch (`Up Time` vs `Up time`)
- Pinned Terraform AMI to prevent EC2 instance replacement on `terraform apply`
- Recovered from GCP free tier shutdown — rebuilt visibility across all clouds after IP change
- Built Justfile-based workflow for exporter deployment, rsync, and lab automation

---

## About

Built by a Senior Voice Infrastructure Engineer with 10+ years of enterprise VoIP experience (Ribbon SBC, Metaswitch Perimeta, OpenSIPS, FreeSWITCH). This lab applies carrier-grade voice engineering to modern DevOps infrastructure — automated, observable, and deployable across any cloud.

**[View Portfolio](https://sharrods.github.io)** · **[Live Architecture](https://sharrods.github.io/multi-cloud-voip-lab/architecture.html)**

**Technologies:** OpenSIPS · FreeSWITCH · RTPEngine · Redis · Terraform · Ansible · Docker · Docker Compose · Prometheus · Grafana · Alertmanager · Python · Justfile · SIPp · sngrep · AWS · GCP · Azure · Oracle Cloud
