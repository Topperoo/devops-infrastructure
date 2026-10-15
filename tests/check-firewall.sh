#!/usr/bin/env bash
set -euo pipefail
namespace=homework-denied
interface=ens-hwtest
cleanup() {
    ip link del "$interface" 2>/dev/null || true
    ip netns del "$namespace" 2>/dev/null || true
}
if ip netns list | grep -Eq "^${namespace}([[:space:]]|$)"; then
    echo 'Test namespace already exists' >&2
    exit 1
fi
if ip link show "$interface" >/dev/null 2>&1; then
    echo 'Test interface already exists' >&2
    exit 1
fi
ip netns add "$namespace"
trap cleanup EXIT
ip link add "$interface" type veth peer name hw-client
ip link set hw-client netns "$namespace"
ip addr add 172.29.88.1/30 dev "$interface"
ip link set "$interface" up
ip netns exec "$namespace" ip link set lo up
ip netns exec "$namespace" ip addr add 172.29.88.2/30 dev hw-client
ip netns exec "$namespace" ip link set hw-client up

echo 'Temporary external-interface test: source 172.29.88.2, target 172.29.88.1'
if ip netns exec "$namespace" nc -z -w 2 172.29.88.1 22; then
    echo 'FAIL: SSH accepted an unauthorized source'
    exit 1
fi
echo 'PASS: SSH blocked from unauthorized source'
set +e
ip netns exec "$namespace" curl --silent --show-error --noproxy '*' --connect-timeout 2 --max-time 3 http://172.29.88.1/
status=$?
set -e
if [[ $status -ne 28 ]]; then
    echo "FAIL: expected HTTP connection timeout, got $status"
    exit 1
fi
echo 'PASS: published Docker HTTP port blocked from unauthorized source'
ip netns exec "$namespace" ip neigh show 172.29.88.1 | grep lladdr
nft list table inet homework
