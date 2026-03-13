provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
  api_timeout          = 10
}

# --- Data Sources ---

data "vsphere_datacenter" "datacenter" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_host" "host" {
  name          = var.esxi_host
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_ovf_vm_template" "ovf" {
  name             = "noble-server-cloudimg-amd64.ova"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  host_system_id   = data.vsphere_host.host.id
  local_ovf_path   = var.ova_path
  ovf_network_map = {
    "VM Network" = data.vsphere_network.network.id
  }
}

# --- Cloud-init templates ---

locals {
  userdata = [for i in range(var.vm_count) : base64encode(<<-CLOUDINIT
#cloud-config
hostname: ${var.vm_name_prefix}-${i + 1}
users:
  - name: ${var.vm_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    plain_text_passwd: ${var.vm_password}
    lock_passwd: false
    groups: [adm, sudo, wheel, users]
    ssh_authorized_keys:
      - ${var.ssh_public_key}
ssh_pwauth: true
write_files:
  - path: /etc/modprobe.d/blacklist-floppy.conf
    content: |
      blacklist floppy
  - path: /etc/netplan/01-custom.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          ens192:
            dhcp4: false
            addresses:
              - ${var.vm_ips[i]}/${var.netmask}
            routes:
              - to: default
                via: ${var.gateway}
            nameservers:
              addresses: [${join(", ", var.dns_servers)}]
runcmd:
  - rm -f /etc/netplan/50-cloud-init.yaml
  - netplan apply
  - update-initramfs -u
CLOUDINIT
  )]
}

# --- Virtual Machines ---

resource "vsphere_virtual_machine" "k0s" {
  count = var.vm_count

  name             = "${var.vm_name_prefix}-${count.index + 1}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  datacenter_id    = data.vsphere_datacenter.datacenter.id
  host_system_id   = data.vsphere_host.host.id

  num_cpus = var.num_cpus
  memory   = var.memory
  guest_id = data.vsphere_ovf_vm_template.ovf.guest_id

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout  = 0

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  ovf_deploy {
    local_ovf_path    = var.ova_path
    disk_provisioning = "thin"
    ovf_network_map = {
      "VM Network" = data.vsphere_network.network.id
    }
  }

  cdrom {
    client_device = true
  }

  vapp {
    properties = {
      "user-data"   = local.userdata[count.index]
      "password"    = var.vm_password
      "public-keys" = var.ssh_public_key
    }
  }

  lifecycle {
    ignore_changes = [
      vapp,
    ]
  }
}
