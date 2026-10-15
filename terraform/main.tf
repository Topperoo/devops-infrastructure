locals {
  controller_ip = cidrhost(var.network_cidr, 1)
  vm_ip         = cidrhost(var.network_cidr, 10)
}

resource "libvirt_network" "lab" {
  name      = var.name
  mode      = "nat"
  addresses = [var.network_cidr]
  autostart = true
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_pool" "lab" {
  name = var.name
  type = "dir"
  path = "/var/lib/libvirt/images/${var.name}"
}

resource "libvirt_volume" "ubuntu" {
  name   = "ubuntu-22.04-base.qcow2"
  pool   = libvirt_pool.lab.name
  source = var.image_path
  format = "qcow2"
}

resource "libvirt_volume" "root" {
  name           = "root.qcow2"
  pool           = libvirt_pool.lab.name
  base_volume_id = libvirt_volume.ubuntu.id
  size           = 12 * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "bootstrap" {
  name = "cloud-init.iso"
  pool = libvirt_pool.lab.name
  user_data = templatefile("${path.module}/cloud-init.yml.tftpl", {
    hostname       = var.name
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    controller_ip  = local.controller_ip
  })
  network_config = yamlencode({
    version = 2
    ethernets = {
      primary = {
        match = { macaddress = "52:54:00:77:00:10" }
        dhcp4 = true
      }
    }
  })
}

resource "libvirt_domain" "host" {
  name      = var.name
  memory    = var.memory_mib
  vcpu      = var.vcpu
  cloudinit = libvirt_cloudinit_disk.bootstrap.id
  autostart = false
  disk {
    volume_id = libvirt_volume.root.id
  }
  network_interface {
    network_id     = libvirt_network.lab.id
    mac            = "52:54:00:77:00:10"
    addresses      = [local.vm_ip]
    wait_for_lease = true
  }
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}
