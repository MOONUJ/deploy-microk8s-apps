# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform project that provisions a virtual machine on VMware vSphere. It is a subdirectory of a larger `learn-terraform-docker-container` repo (the parent directory manages Docker containers via Terraform).

## Key Commands

```bash
terraform init        # Initialize providers (hashicorp/vsphere v2.12.0)
terraform plan        # Preview infrastructure changes
terraform apply       # Apply changes (creates/modifies VM resources)
terraform destroy     # Tear down all managed resources
terraform fmt         # Format .tf files
terraform validate    # Validate configuration syntax
```

## Architecture

Single-configuration Terraform project (no modules) with two files:

- **main.tf** — Defines the vSphere provider and a single VM resource (`vsphere_virtual_machine.vm`) along with data sources for datacenter, datastore, compute cluster, and network.
- **variables.tf** — Connection credentials (`vsphere_user`, `vsphere_password`, `vsphere_server`) with defaults pointing to a lab environment (`vc-mgmt.gooddi.lab`).

The vSphere provider is configured with `allow_unverified_ssl = true` and a 10-second API timeout.

## Infrastructure Targets

- **Datacenter:** `dtx-mgmt-dc01`
- **Cluster:** `dtx-mgmt-cl01`
- **Datastore:** `dtx-mgmt-cl01-ds-nfs01`
- **Network:** `dtx-mgmt-cl01-vds01-pg-vm-mgmt`
- **VM:** `foo` — 1 vCPU, 1 GB RAM, 20 GB disk, `otherLinux64Guest`

## Notes

- Credentials have defaults in `variables.tf`. Override via `terraform.tfvars`, environment variables (`TF_VAR_vsphere_*`), or `-var` flags.
- `terraform.tfstate` and `.terraform/` are present locally — do not commit state files to version control.
