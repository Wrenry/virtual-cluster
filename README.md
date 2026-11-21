# virtual-cluster

An elastic, virtual HPC cluster built with OpenTofu, Ansible and Slurm. Worker VMs are cloned on request, join Slurm on their own, run a job, and are torn down when the administrator is done with them.

This repository is the **lab build**: a single HP Z620 running Proxmox VE stands in for the production design (Cisco C240 M4, ESXi, RHEL 9). The lab runs AlmaLinux 9 and is built to behave like an **air-gapped site**, so every package comes from an offline repo carried in on a virtual CD.

## How it fits together

| Machine | Role | Networks |
| --- | --- | --- |
| Control VM | Runs OpenTofu and builds the config kit and offline repo. The only machine with internet. | Management (VLAN 202) |
| Head node | slurmctld, slurmdbd, MariaDB, munge, DHCP/DNS (dnsmasq), NTP (chrony), NFS | Management (VLAN 202) and cluster (VLAN 50) |
| Workers | Linked clones running slurmd as dynamic nodes, one partition per size class | Cluster (VLAN 50) only, no gateway |

The control VM **never connects to the head node**. Configuration and packages reach it on an ISO that is attached to its CD drive through the Proxmox API (the "config kit").

## Repository layout

```
classes.yml        # single source of truth: pool caps, network, worker size classes
tofu/base/         # Proxmox provider and the head node VM
tofu/worker/       # linked-clone worker module (in progress)
ansible/           # site.yml and roles: storage, repo, base, dnsmasq, nfs, slurm
repo/packages.txt  # offline repo manifest
image/             # golden worker image (in progress)
workloads/         # workload profiles (in progress)
bin/control/       # push-kit, build-repo
bin/head/          # pull-kit
jobs/              # benchmark sbatch files (in progress)
```

## Worker classes

Defined in `classes.yml`. Each class is a Slurm partition, and workers join it as dynamic nodes with the class name as a feature.

| Class | vCPU | Memory | Max nodes |
| --- | --- | --- | --- |
| xs | 2 | 4 GB | 16 |
| s | 4 | 8 GB | 8 |
| m | 8 | 16 GB | 4 |
| l | 16 | 32 GB | 2 |

## Usage

### 1. Build the offline repo (control VM)

Slurm is built from source RPMs with PMIx support (the EPEL package is outdated):

```bash
rpmbuild -ta slurm-<version>.tar.bz2 --with pmix
```

Then stage everything in `repo/packages.txt`, with all dependencies, plus the Slurm RPMs:

```bash
bin/control/build-repo
```

### 2. Send the config kit (control VM)

```bash
bin/control/push-kit          # config only
bin/control/push-kit --repo   # config plus the offline repo
```

### 3. Apply it (head node)

```bash
~/virtual-cluster/bin/head/pull-kit
ansible-playbook -c local -i localhost, ~/virtual-cluster/ansible/site.yml --ask-become-pass
```

`pull-kit` syncs the config into `~/virtual-cluster` and, when the disc carries one, copies the offline repo to `/srv/nfs/apps/repo`. A second playbook run should report `changed=0`.

## Ansible roles

| Role | What it sets up |
| --- | --- |
| `storage` | Data disk on `/srv/nfs` with `home`, `apps` and `scratch` |
| `repo` | `hpc-local` dnf repo; with `hpc_offline_only: true` (default) the online repos are turned off |
| `base` | chrony for the cluster VLAN, firewalld zones, `ip_forward=0` |
| `dnsmasq` | Static-lease DHCP and DNS on the cluster VLAN |
| `nfs` | Exports `home`, `apps` and `scratch` to the cluster VLAN |
| `slurm` | Fixed IDs for munge and slurm, munge, MariaDB, slurmdbd, slurmctld (configless) |

## Secrets

Nothing secret is stored in this repository.

- The Proxmox API token lives in `~/.tofu-env` on the control VM.
- The munge key and the accounting database password are generated on the head node and never leave it.
- OpenTofu state (`*.tfstate`) is git-ignored. Back it up separately.

## Status

Working: head node, offline repo, Slurm controller and accounting, air-gap test passed.

Next: golden worker image, `tofu/worker` module, deploy and teardown scripts, MPI benchmarks, monitoring.
