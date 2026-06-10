# Git Workflow — multi-cloud-voip-lab

## Overview

The **Azure bastion** (`azureuser@4.235.114.198`) is the single source of truth for this repo. All git operations — commit, push, pull — happen from Azure. No cloud VM has a git clone of this repo.

Configs flow in two directions depending on the cloud:

| Cloud | Direction | Mechanism |
|---|---|---|
| Oracle | VM → Azure | `rsync` pull — configs edited live on VM, synced back to Azure |
| GCP | VM → Azure | `rsync` pull — configs edited live on instance |
| AWS | Azure → VM | Ansible push — repo is source of truth, VMs are never edited directly |
| Azure | Local only | direct `git add` — Azure is the repo, no sync needed |

---

## Directory Structure

```
~/multi-cloud-voip-lab/          ← repo root on Azure
├── oracle/
│   ├── vm1-signaling/           ← rsynced from opc@144.24.1.61
│   └── vm2-media/               ← rsynced from opc@141.148.155.33
├── gcp/
│   └── configs/                 ← rsynced from GCP instance
├── aws/
│   ├── terraform/               ← source of truth, pushed via Terraform
│   ├── ansible/                 ← source of truth, pushed via Ansible
│   └── configs/                 ← source of truth, pushed via Ansible
├── azure/
│   └── sipp-test-framework/     ← lives on Azure, no sync needed
├── monitoring/
│   └── exporters/               ← Python exporters, source of truth here
└── docs/
```

---

## Daily Workflow — Oracle & GCP (rsync pull)

These clouds have configs edited directly on the VM. You rsync them back to Azure, then commit from Azure.

### Step 1 — SSH to the VM and make your change

```bash
# Oracle VM1 (OpenSIPS)
ssh -i ~/.ssh/oracle_key opc@144.24.1.61
vim ~/opensips/opensips.cfg
# test your change, restart container
docker restart opensips

# Oracle VM2 (FreeSWITCH / RTPEngine)
ssh -i ~/.ssh/oracle_key opc@141.148.155.33
```

```bash
# GCP (through Azure ProxyJump)
ssh -J azureuser@4.235.114.198 -i ~/.ssh/google_compute_engine \
    user@GCP_INTERNAL_IP
vim ~/voiplab/opensips/opensips.cfg
```

### Step 2 — Rsync configs back to Azure

Run these from Azure, not from the VM:

```bash
# Oracle VM1 → Azure
rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    opc@144.24.1.61:~/opensips/ \
    ~/multi-cloud-voip-lab/oracle/vm1-signaling/opensips/

rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    opc@144.24.1.61:~/redis/ \
    ~/multi-cloud-voip-lab/oracle/vm1-signaling/redis/

# Oracle VM2 → Azure
rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    opc@141.148.155.33:~/freeswitch-config/ \
    ~/multi-cloud-voip-lab/oracle/vm2-media/freeswitch-config/

rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    opc@141.148.155.33:~/rtpengine-config/ \
    ~/multi-cloud-voip-lab/oracle/vm2-media/rtpengine-config/

# GCP → Azure (ProxyJump not needed for rsync — use direct path)
rsync -avz -e "ssh -i ~/.ssh/google_compute_engine" \
    user@GCP_PUBLIC_IP:~/voiplab/opensips/ \
    ~/multi-cloud-voip-lab/gcp/configs/opensips/

rsync -avz -e "ssh -i ~/.ssh/google_compute_engine" \
    user@GCP_PUBLIC_IP:~/voiplab/docker-compose.yml \
    ~/multi-cloud-voip-lab/gcp/docker-compose.yml
```

Or use the Justfile shorthand (Oracle only):

```bash
just sync        # rsync from Oracle VM1 + VM2
just sync-vm1    # Oracle VM1 only
just sync-vm2    # Oracle VM2 only
```

### Step 3 — Commit and push from Azure

```bash
cd ~/multi-cloud-voip-lab

# Always check what changed before staging
git diff
git status

# Stage only the cloud you changed — never git add . across all clouds
git add oracle/vm1-signaling/opensips/opensips.cfg
git commit -m "fix(oracle/opensips): describe what you changed and why"
git push

# Or use Justfile one-liner for Oracle:
just save "fix: opensips PUBLISH loop — add method guard"
```

---

## Daily Workflow — AWS (Ansible push)

AWS is the opposite. The repo is the source of truth. You never edit configs directly on AWS VMs.

### Step 1 — Edit configs on Azure

```bash
cd ~/multi-cloud-voip-lab

# Edit the config in the repo
vim aws/configs/opensips/opensips.cfg
# or
vim aws/ansible/playbooks/deploy.yml
```

### Step 2 — Commit first, then deploy

```bash
git add aws/
git commit -m "fix(aws/opensips): describe your change"
git push

# Then deploy to AWS VMs via Ansible
cd aws/ansible
ansible-playbook -i inventory/hosts.yml playbooks/aws-voip.yml

# Or via Justfile if wired up
just deploy-aws
```

### Step 3 — Verify on the VM

```bash
# SSH to AWS signaling node via Azure ProxyJump
ssh -J azureuser@4.235.114.198 ubuntu@AWS_SIGNALING_IP

docker ps
docker logs opensips --tail 20
```

---

## Deploying a Config Change Back to Oracle/GCP

If you edit a config in the repo (from GitHub or locally on Azure) and need to push it back to a VM:

```bash
# Push to Oracle VM1
rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    ~/multi-cloud-voip-lab/oracle/vm1-signaling/opensips/ \
    opc@144.24.1.61:~/opensips/

# Then restart the container on the VM
ssh -i ~/.ssh/oracle_key opc@144.24.1.61 "docker restart opensips"

# Or use Justfile
just deploy-vm1
just restart opensips vm1
```

---

## Commit Message Convention

Always prefix with the cloud and service:

```
fix(gcp/opensips): PUBLISH loop — add PUBLISH|SUBSCRIBE guard before has_totag
fix(oracle/vm1): update opensips socket advertise address
feat(aws/ansible): add rollback playbook
feat(monitoring): add rtpengine-exporter memory metric
docs: update git workflow with AWS rsync pattern
```

---

## What Is and Isn't Tracked in Git

**Tracked:**
- All `*.cfg`, `*.yml`, `*.conf`, `*.json` config files
- Terraform `.tf` files
- Ansible playbooks and inventory
- Python exporters
- Docker Compose files
- Scripts and Justfiles
- Documentation

**Never tracked (see `.gitignore`):**
- `*.tfstate`, `*.tfstate.backup`, `.terraform/`
- `.env`, `secrets/`, `*.pem`, `*.key`
- `terraform.tfvars` (contains real IPs and credentials)
- Container logs, recordings, storage

---

## Recover a Config From Git History

If you broke something and need to restore a previous version:

```bash
# See the history for a specific file
git log --oneline oracle/vm1-signaling/opensips/opensips.cfg

# View a specific version
git show COMMIT_HASH:oracle/vm1-signaling/opensips/opensips.cfg

# Restore it
git checkout COMMIT_HASH -- oracle/vm1-signaling/opensips/opensips.cfg

# Then redeploy to VM
rsync -avz -e "ssh -i ~/.ssh/oracle_key" \
    ~/multi-cloud-voip-lab/oracle/vm1-signaling/opensips/ \
    opc@144.24.1.61:~/opensips/
ssh -i ~/.ssh/oracle_key opc@144.24.1.61 "docker restart opensips"
```

---

## SSH Key Reference

| Cloud | User | Key |
|---|---|---|
| Oracle VM1 | `opc` | `~/.ssh/oracle_key` |
| Oracle VM2 | `opc` | `~/.ssh/oracle_key` |
| GCP | `user` | `~/.ssh/google_compute_engine` |
| AWS Signaling | `ubuntu` | `~/.ssh/aws_voip_key` |
| AWS Media | `ubuntu` | `~/.ssh/aws_voip_key` |
| Azure (bastion) | `azureuser` | `4.235.114.198` |

All non-Azure SSH goes through Azure ProxyJump:
```bash
ssh -J azureuser@4.235.114.198 opc@ORACLE_IP
ssh -J azureuser@4.235.114.198 ubuntu@AWS_IP
```
