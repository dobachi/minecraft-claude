#!/usr/bin/env bash
# Print the WSL2 IPv4 address that Minecraft on the Windows side should connect to.
#
# Why this exists:
#   Minecraft for Windows is a UWP app. Even with a loopback exemption in place,
#   connecting to `localhost` does not reach a server listening inside WSL2 —
#   measured on Windows 11 26200 / WSL 2.4.13, where `/connect localhost:8001/ws`
#   failed while `/connect <this address>:8001/ws` succeeded.
#
#   WSL2's NAT address changes every time WSL restarts, so it has to be looked up
#   rather than written down.
#
# Usage:
#   ./scripts/wsl-ip.sh            # prints e.g. 172.29.198.82
#   echo "/connect $(./scripts/wsl-ip.sh):8001/ws"

set -euo pipefail

addr="$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)"

if [ -z "$addr" ]; then
    echo "wsl-ip.sh: could not determine the eth0 IPv4 address." >&2
    echo "Run 'ip -4 addr' and use the address of the interface facing Windows." >&2
    exit 1
fi

echo "$addr"
