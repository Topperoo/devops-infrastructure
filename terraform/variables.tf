variable "docker_host" {
  type    = string
  default = "unix:///var/run/docker.sock"
}

variable "ssh_private_key_path" {
  type    = string
  default = "../.local/id_ed25519"
}

variable "bind_address" {
  type    = string
  default = "127.0.0.1"
}

variable "http_port" {
  type    = number
  default = 8080
  validation {
    condition     = var.http_port >= 1024 && var.http_port <= 65535 && floor(var.http_port) == var.http_port
    error_message = "Use an integer port between 1024 and 65535."
  }
}
