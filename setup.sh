#!/usr/bin/env bash
# Minecraft Bedrock MCP Server setup (Linux / WSL2)
#
# Linux port of setup.ps1. Clones the Mming-Lab MCP server into ./server,
# installs dependencies and builds it.
#
# Usage: ./setup.sh
#
# Note on WSL2: the MCP server runs here (Linux side) while Minecraft runs on
# the Windows side. They talk over the WebSocket port, which WSL2 forwards to
# the Windows localhost automatically. See README for details.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$ROOT/server"
REPO_URL="https://github.com/Mming-Lab/minecraft-bedrock-mcp-server.git"

info()  { printf '\033[36m%s\033[0m\n' "$*"; }
ok()    { printf '\033[32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die()   { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

assert_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"
}

info "=== Minecraft Bedrock MCP Server setup (Linux/WSL2) ==="

assert_command git  "Install it with your package manager, e.g. sudo apt install git"
assert_command node "Install Node.js 18 or newer, e.g. via nvm or your package manager"
assert_command npm  "Bundled with Node.js. Reinstall Node.js."

node_version="$(node --version)"
node_major="${node_version#v}"
node_major="${node_major%%.*}"
if [ "$node_major" -lt 18 ]; then
    warn "Node.js $node_version detected. 18 or higher recommended."
fi

if [ -d "$REPO_DIR" ]; then
    ok "[1/3] Updating existing repo..."
    git -C "$REPO_DIR" pull --ff-only
else
    ok "[1/3] Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
fi

ok "[2/4] Running npm install..."
npm --prefix "$REPO_DIR" install

# The upstream lockfile pins socket-be 2.3.1, whose World.getPlayerDetail() parses the
# "listd stats" response without checking that the command succeeded. On a multiplayer
# server the command fails, res.details is undefined, and .match() throws — killing the
# connection. Upstream disabled getPlayerDetail/Player.load outright in 2.6.0 for exactly
# this reason ("may crash Minecraft world in multiplayer"), so 2.6.0 is the floor here.
ok "[3/4] Pinning socket-be >= 2.6.0 and applying local patches..."
npm --prefix "$REPO_DIR" install "socket-be@^2.6.0"
node "$ROOT/scripts/patch-socket-be.js"

ok "[4/4] Running npm run build..."
npm --prefix "$REPO_DIR" run build

SERVER_JS="$REPO_DIR/dist/server.js"
[ -f "$SERVER_JS" ] || die "Build did not produce $SERVER_JS. Check the output above."

echo
info "=== Setup complete ==="
echo
echo "Next steps:"
echo "  1. Generate the Claude Code MCP config:"
echo "       ./apply-config.sh"
echo "  2. Start Claude Code from this directory:"
echo "       claude"
echo "  3. Launch Minecraft on the Windows side, enter a world with cheats ON"
echo "  4. In the Minecraft chat, run:"
echo "       /connect $(bash "$ROOT/scripts/wsl-ip.sh" 2>/dev/null || echo '<WSL2-IP>'):8001/ws"
echo
echo "Use the address above, not localhost: Minecraft is a UWP app on the Windows"
echo "side and does not reach a WSL2 listener through localhost. The address is a"
echo "WSL2 NAT address and changes when WSL restarts — re-read it with"
echo "./scripts/wsl-ip.sh"
echo
echo "Order matters: Claude Code must be running (so the MCP server is"
echo "listening) before you type /connect in Minecraft."
echo
printf '\033[33m%s\033[0m\n' "MCP server entry point:"
echo "  node \"$SERVER_JS\""
