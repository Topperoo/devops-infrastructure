#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
mkdir -p evidence
vm_ip=$(terraform -chdir=terraform output -raw vm_ip)
terraform -chdir=terraform state list | tee evidence/terraform-state.txt
ssh -i .local/id_ed25519 -o StrictHostKeyChecking=accept-new "deployer@$vm_ip" \
    'sudo /usr/local/bin/monitor.sh docker' | tee evidence/monitor-vm.txt
ssh -i .local/id_ed25519 "deployer@$vm_ip" \
    'sudo docker compose -f /opt/app/docker-compose.yml ps' | tee evidence/compose-vm.txt
curl --noproxy '*' --fail --max-time 15 "http://$vm_ip/" | tee evidence/curl-vm.txt
