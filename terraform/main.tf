terraform {
  required_version = ">= 1.13, < 2.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
  ssh_opts = [
    "-i", pathexpand(var.ssh_private_key_path),
    "-o", "StrictHostKeyChecking=yes",
    "-o", "BatchMode=yes"
  ]
}

resource "docker_network" "nginx" {
  name = "terraform-nginx-net"
}

resource "docker_volume" "nginx" {
  name = "terraform-nginx-html"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.28.0-alpine"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name         = "terraform-nginx"
  image        = docker_image.nginx.image_id
  restart      = "unless-stopped"
  network_mode = docker_network.nginx.name
  wait         = true
  wait_timeout = 60

  ports {
    internal = 80
    external = var.http_port
    ip       = var.bind_address
  }

  mounts {
    type      = "volume"
    source    = docker_volume.nginx.name
    target    = "/usr/share/nginx/html"
    read_only = true
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1/"]
    interval = "5s"
    timeout  = "3s"
    retries  = 12
  }
}
