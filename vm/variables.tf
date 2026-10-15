variable "libvirt_uri" {
  type    = string
  default = "qemu:///system"
}

variable "name" {
  type    = string
  default = "devops-homework"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.name))
    error_message = "Use a lowercase resource name, up to 31 characters."
  }
}

variable "network_cidr" {
  type    = string
  default = "172.28.77.0/24"
  validation {
    condition     = can(cidrhost(var.network_cidr, 10))
    error_message = "Provide an IPv4 subnet containing at least 16 addresses."
  }
}

variable "ssh_public_key_path" {
  type    = string
  default = "../.local/id_ed25519.pub"
}

variable "memory_mib" {
  type    = number
  default = 1536
}

variable "vcpu" {
  type    = number
  default = 1
}

variable "image_path" {
  type        = string
  description = "Absolute path to the verified Ubuntu 22.04 cloud image."
}
