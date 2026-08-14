#!/usr/bin/env bash
# Generate the Claude Code project-scope MCP config (.mcp.json) for this directory.
#
# Claude Code reads .mcp.json from the directory it is started in. This script
# writes one pointing at ./run-server.sh with an absolute path, so it works
# regardless of where you clone the repo.
#
# .mcp.json is gitignored (it contains a machine-specific absolute path), which
# is why it is generated rather than committed.
#
# Usage:
#   ./apply-config.sh              # port 8001 (default)
#   ./apply-config.sh --port 8002  # when 8001 is taken (e.g. Claude Desktop is running)
#
# Linux counterpart of apply-config.ps1. Note that it does NOT touch any Claude
# Desktop config: Claude Desktop is a Windows application and cannot spawn a
# process inside WSL2.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="$PROJECT_DIR/.mcp.json"
RUN_SERVER="$PROJECT_DIR/run-server.sh"
PORT=8001

info() { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --port=*) PORT="${1#*=}"; shift ;;
        -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

case "$PORT" in
    ''|*[!0-9]*) die "Port must be a number: $PORT" ;;
esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "Port out of range: $PORT"

[ -f "$RUN_SERVER" ] || die "$RUN_SERVER not found."
[ -x "$RUN_SERVER" ] || warn "$RUN_SERVER is not executable. Run: chmod +x run-server.sh"

if [ ! -f "$PROJECT_DIR/server/dist/server.js" ]; then
    warn "server/dist/server.js not found — run ./setup.sh before starting Claude Code."
fi

if [ -f "$OUT_FILE" ]; then
    cp -f "$OUT_FILE" "$OUT_FILE.bak"
    warn "Backed up existing config: $OUT_FILE.bak"
fi

# Build the JSON with node so the absolute path is escaped correctly.
node -e '
const fs = require("fs");
const [out, cmd, port] = process.argv.slice(1);
const config = {
  mcpServers: {
    "minecraft-bedrock": { command: cmd, args: ["--port=" + port] }
  }
};
fs.writeFileSync(out, JSON.stringify(config, null, 2) + "\n");
' "$OUT_FILE" "$RUN_SERVER" "$PORT"

ok "Wrote: $OUT_FILE"
echo
cat "$OUT_FILE"
echo
info "Next:"
echo "  1. Start Claude Code from this directory:  cd \"$PROJECT_DIR\" && claude"
echo "  2. Approve the 'minecraft-bedrock' MCP server prompt (Yes / Always)"
echo "  3. In Minecraft (Windows side), enter a world with cheats ON and run:"
echo "       /connect $(bash "$PROJECT_DIR/scripts/wsl-ip.sh" 2>/dev/null || echo '<WSL2-IP>'):$PORT/ws"
echo
echo "Not localhost — Minecraft is a UWP app on the Windows side and does not reach"
echo "a WSL2 listener that way. Re-read the address with ./scripts/wsl-ip.sh after a"
echo "WSL restart, since it is a NAT address that changes."
echo
echo "Claude Code must be running before you type /connect — it is what starts"
echo "the MCP server that listens on port $PORT."
