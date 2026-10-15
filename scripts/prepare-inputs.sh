#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
mkdir -p .local
chmod 700 .local

if [[ ! -f .local/id_ed25519 ]]; then
    ssh-keygen -q -t ed25519 -N '' -C devops-homework -f .local/id_ed25519
fi

image=ubuntu-22.04-server-cloudimg-amd64.img
base_url=https://cloud-images.ubuntu.com/releases/22.04/release
curl -fsSL --connect-timeout 15 "$base_url/SHA256SUMS" -o .local/SHA256SUMS
if [[ ! -f .local/$image ]]; then
    curl -fL --retry 3 --connect-timeout 15 "$base_url/$image" -o ".local/$image.part"
    mv ".local/$image.part" ".local/$image"
fi

python3 - "$project_dir" "$image" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

project = Path(sys.argv[1])
name = sys.argv[2]
image = project / '.local' / name
checksums = (project / '.local/SHA256SUMS').read_text().splitlines()
expected = next(line.split()[0] for line in checksums if line.split()[-1].lstrip('*') == name)
with image.open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != expected:
    raise SystemExit('Ubuntu image checksum mismatch; remove the image and retry.')
variables = project / 'vm/terraform.tfvars.json'
if not variables.exists():
    variables.write_text(json.dumps({'image_path': str(image)}, indent=4) + '\n')
print(f'Image verified: {actual}')
print('Terraform inputs and SSH key are ready.')
PY
