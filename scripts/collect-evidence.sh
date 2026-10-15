#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
mkdir -p evidence
nginx_url=$(terraform -chdir=terraform output -raw nginx_url)
vm_ip=$(python3 - "$nginx_url" <<'PY'
import sys
from urllib.parse import urlparse
print(urlparse(sys.argv[1]).hostname)
PY
)
terraform -chdir=terraform state list | tee evidence/terraform-state.txt
ssh -i .local/id_ed25519 -o StrictHostKeyChecking=yes "deployer@$vm_ip" \
    'sudo /usr/local/bin/monitor.sh docker' | tee evidence/monitor-vm.txt
ssh -i .local/id_ed25519 "deployer@$vm_ip" \
    'docker compose -f /opt/app/docker-compose.yml ps' | tee evidence/compose-vm.txt
curl --noproxy '*' --fail --max-time 15 "http://$vm_ip/" | tee evidence/curl-vm.txt
curl --noproxy '*' --include --fail --max-time 15 "$nginx_url" | tee evidence/terraform-curl.txt
ssh -i .local/id_ed25519 "deployer@$vm_ip" \
    'docker inspect terraform-nginx app-app-1 app-nginx-1' | python3 -c '
import json
import sys
result = []
for item in json.load(sys.stdin):
    result.append({
        "name": item["Name"].lstrip("/"),
        "networks": sorted(item["NetworkSettings"]["Networks"]),
        "mounts": item["Mounts"],
        "ports": item["NetworkSettings"]["Ports"],
        "health": item["State"]["Health"]["Status"],
    })
print(json.dumps(result, indent=4))
' | tee evidence/docker-isolation.json
