# --- vSphere Connection ---
variable "vsphere_user" {
  description = "vSphere User Name"
  type        = string
  default     = "administrator@vsphere.local"
}

variable "vsphere_password" {
  description = "vSphere Password"
  type        = string
  sensitive   = true
  default     = "VMware123!VMware123!"
}

variable "vsphere_server" {
  description = "vSphere Server"
  type        = string
  default     = "vc-mgmt.gooddi.lab"
}

# --- Infrastructure ---
variable "datacenter" {
  description = "vSphere Datacenter name"
  type        = string
  default     = "dtx-mgmt-dc01"
}

variable "datastore" {
  description = "vSphere Datastore name"
  type        = string
  default     = "dtx-mgmt-cl01-ds-nfs01"
}

variable "cluster" {
  description = "vSphere Compute Cluster name"
  type        = string
  default     = "dtx-mgmt-cl01"
}

variable "network" {
  description = "vSphere Network (port group) name"
  type        = string
  default     = "dtx-mgmt-cl01-vds01-pg-vm-mgmt"
}

# --- ESXi Host ---
variable "esxi_host" {
  description = "ESXi host name for OVA deployment (e.g. esxi01.gooddi.lab)"
  type        = string
  default     = "r760-1.gooddi.lab"
}

# --- OVA ---
variable "ova_path" {
  description = "Local path to the Ubuntu cloud image OVA file"
  type        = string
  default     = "/Users/git/Documents/GitHub/learn-terraform-docker-container/vsphere-terraform/noble-server-cloudimg-amd64.ova"
}

# --- VM Spec ---
variable "vm_name_prefix" {
  description = "Prefix for VM names (e.g. k0s-node)"
  type        = string
  default     = "ubuntu-24.04"
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "num_cpus" {
  description = "Number of vCPUs per VM"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB per VM"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Disk size in GB per VM"
  type        = number
  default     = 40
}

# --- User ---
variable "vm_user" {
  description = "Username to create on the VM via cloud-init"
  type        = string
  default     = "ujmoon"
}

variable "vm_password" {
  description = "Password for the VM user (hashed or plain — cloud-init will hash plain text)"
  type        = string
  sensitive   = true
  default     = "VMware1!"
}

variable "ssh_public_key" {
  description = "SSH public key to authorize for the VM user"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4QTb2MJ0dWeF5aZKbY//PTjNBMNHXw9vIGwotkKBqQAkyt9Eum/wOy4j0HZsOmsUvTxMS/A3qlrYbs+DA8sZEVJsi2wPjVE4u4k1QBnocjknr/PU7d8HLWKWDYU4ZbNdMZ0Q8WV+rz13Pyw97/4epWnYk2zaIVXPLn+zN31QqIUvtsjNrybOgsr/cUo8KZnT3D6+5LUwfOBfgHgcxNMAQBqKha1oo0dYa+UFnE0yrCIjljNuMQN0W0jQeFptAE2FhD9T7krbKNN82qc1kdCNfOfibpV1v/TX8vHrfp1jV4nmKbXFbudbd3TfrSBwGtLbuRyT8VNmba+zwy8Os0YdFUrEkM3GpRRJlBaZvPpRMNwa1t4F3TsXeoIKkJyoudp9I66VBn1oDI4cKDX5rT4/Q7hsdd7eNKDK+frEZyqelxmXbfIcN5X0hB2JK5IhrckgV3Wn9SRS7vGx8xtFm4N21W1MHhTpwrI2mcZatM1f05Hm5uFnJbV1tBgfHg1LihrWAXivqqovCFJ27Ukq85wmJLWRPaBemNv1e5/JzKkePs6KDd+BhKtaF/lpCDd6OCHgojBj8IGHrffTtt7MGeDRK/ReNECgBcaYBP4TruVJPIvfBm3OqzfjVvQkG7+522cx7XyLltF2gx9ba3Zke+jABAH2BypnE402lj4Mkpc8BOQ== git@mun-uijins-MacBook-Air.local"
}

# --- Network ---
variable "vm_ips" {
  description = "List of static IPs for each VM (must have vm_count entries)"
  type        = list(string)
  default     = ["10.100.64.171", "10.100.64.172", "10.100.64.173"]
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = "10.100.64.254"
}

variable "dns_servers" {
  description = "List of DNS server IPs"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "netmask" {
  description = "Subnet prefix length (e.g. 24)"
  type        = string
  default     = "24"
}

variable "vm_domain" {
  description = "Domain name for the VMs"
  type        = string
  default     = "gooddi.lab"
}
