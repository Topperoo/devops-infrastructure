#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
vm_ip=$(terraform -chdir=vm output -raw vm_ip)
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

python3 - "$vm_ip" <<'PYTHON'
import json
import sys
from pathlib import Path

variables = Path('terraform/terraform.tfvars.json')
if not variables.exists():
    vm_ip = sys.argv[1]
    variables.write_text(json.dumps({
        'docker_host': f'ssh://deployer@{vm_ip}:22',
        'bind_address': vm_ip,
        'http_port': 8080,
    }, indent=4) + '\n')
PYTHON
