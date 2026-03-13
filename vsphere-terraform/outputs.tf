output "vm_names" {
  description = "Names of the deployed VMs"
  value       = vsphere_virtual_machine.k0s[*].name
}

output "vm_ips" {
  description = "Static IPs assigned to the VMs"
  value       = var.vm_ips
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file (Terraform-managed VMs)"
  value       = local_file.ansible_inventory.filename
}
