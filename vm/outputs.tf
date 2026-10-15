output "vm_ip" {
  value = local.vm_ip
}

output "controller_ip" {
  value = local.controller_ip
}

output "vm_name" {
  value = libvirt_domain.host.name
}
