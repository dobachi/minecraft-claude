#!/usr/bin/env bash
# Minecraft Bedrock MCP Server setup (Linux / WSL2)
#
# Linux port of setup.ps1. Checks out the MCP server submodule in ./server,
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

# server/ は git submodule（dobachi/minecraft-bedrock-education-mcp の
# legacy-chat-receive ブランチ）で、コミット単位で固定されている。
#
# 固定する理由: Mming-Lab の上流は 2026-08 に全面書き換えされ（アドオン経由の
# ブリッジ、ポート19131、ツール群も別物）、このプロジェクトが前提にしている
# ツール（build_cube / agent / world など）は残っていない。ブランチ先端を
# 追うと環境ごと壊れるため、submodule で SHA を固定する。
# 上流の新実装へ移行するかは別途判断する。
#
# 版を上げるときは server/ で目的のコミットに切り替え、
# 親リポジトリで `git add server` してコミットする。

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

ok "[1/4] Syncing the server submodule..."
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 ||
    die "$ROOT is not a git checkout. Clone this repository instead of downloading it, so the server submodule can be fetched."
git -C "$ROOT" submodule update --init server

ok "[2/4] Running npm install..."
npm --prefix "$REPO_DIR" install

# socket-be 2.3.1 の World.getPlayerDetail() は "listd stats" の応答を成功確認なしに
# 解析し、マルチプレイでは接続ごと落とす。下限 2.6.0 は submodule 側の package.json で
# 固定済みなので、ここでは残るクラッシュ（Network.onConnectionClose）にパッチを当てる。
ok "[3/4] Applying local patches..."
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
