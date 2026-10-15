#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
vm_ip=$(terraform -chdir=terraform output -raw vm_ip)
key_path="$project_dir/.local/id_ed25519"

cat > ansible/inventory.ini <<INVENTORY
[app_hosts]
devops-host ansible_host=$vm_ip ansible_user=ubuntu ansible_ssh_private_key_file='$key_path'

[app_hosts:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
INVENTORY
chmod 600 ansible/inventory.ini
ssh -i "$key_path" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    "ubuntu@$vm_ip" 'sudo cloud-init status --wait'
