# --- Ansible Integration ---

variable "ssh_private_key_file" {
  description = "Path to SSH private key for Ansible access"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ansible_run_playbook" {
  description = "Automatically run Ansible playbook after VM creation"
  type        = bool
  default     = false
}

# Generate Ansible inventory from Terraform outputs
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    vm_ips               = var.vm_ips
    vm_names             = [for i in range(var.vm_count) : "${var.vm_name_prefix}-${i + 1}"]
    vm_user              = var.vm_user
    ssh_private_key_file = var.ssh_private_key_file
  })

  filename        = "${path.module}/../ansible/inventory/hosts.terraform.ini"
  file_permission = "0644"

  depends_on = [vsphere_virtual_machine.k0s]
}

# Wait for SSH to become available on all VMs
resource "null_resource" "wait_for_ssh" {
  count = var.vm_count

  depends_on = [vsphere_virtual_machine.k0s]

  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      host        = var.vm_ips[count.index]
      user        = var.vm_user
      private_key = file(pathexpand(var.ssh_private_key_file))
      timeout     = "5m"
    }
  }
}

# Optionally run Ansible playbook after VM provisioning
resource "null_resource" "run_ansible" {
  count = var.ansible_run_playbook ? 1 : 0

  depends_on = [
    local_file.ansible_inventory,
    null_resource.wait_for_ssh,
  ]

  provisioner "local-exec" {
    command     = "ansible-playbook -i inventory/hosts.ini playbooks/site.yml"
    working_dir = "${path.module}/../ansible"
  }
}
