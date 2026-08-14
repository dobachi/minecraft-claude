#!/usr/bin/env bash
# Generate the Claude Code project-scope MCP config (.mcp.json).
#
# Claude Code reads .mcp.json from the directory it is started in, so this file
# belongs wherever you intend to run `claude` — which is not necessarily this
# repository. The MCP server is referenced by absolute path, so the config works
# from any directory.
#
# Usage:
#   ./apply-config.sh                          # write .mcp.json here
#   ./apply-config.sh --output-dir ~/work      # write it where you start claude
#   ./apply-config.sh --port 8002              # when 8001 is taken
#
# Writing it somewhere else is the norm when this repo lives inside a larger
# workspace: putting .mcp.json at the workspace root lets one Claude Code session
# reach both the Minecraft tools and every sibling project, instead of confining
# the session to this one directory.
#
# .mcp.json is gitignored here because it contains a machine-specific absolute
# path. If you point --output-dir at another repository, make sure that repo
# ignores .mcp.json too — this script warns when it does not.
#
# Linux counterpart of apply-config.ps1. It does NOT touch any Claude Desktop
# config: Claude Desktop is a Windows application and cannot spawn a process
# inside WSL2.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SERVER="$PROJECT_DIR/run-server.sh"
OUT_DIR="$PROJECT_DIR"
PORT=8001

info() { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --port) PORT="${2:-}"; shift 2 ;;
        --port=*) PORT="${1#*=}"; shift ;;
        --output-dir) OUT_DIR="${2:-}"; shift 2 ;;
        --output-dir=*) OUT_DIR="${1#*=}"; shift ;;
        -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

case "$PORT" in
    ''|*[!0-9]*) die "Port must be a number: $PORT" ;;
esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "Port out of range: $PORT"

[ -d "$OUT_DIR" ] || die "Output directory does not exist: $OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
OUT_FILE="$OUT_DIR/.mcp.json"

[ -f "$RUN_SERVER" ] || die "$RUN_SERVER not found."
[ -x "$RUN_SERVER" ] || warn "$RUN_SERVER is not executable. Run: chmod +x run-server.sh"

if [ ! -f "$PROJECT_DIR/server/dist/server.js" ]; then
    warn "server/dist/server.js not found — run ./setup.sh before starting Claude Code."
fi

# A .mcp.json holds an absolute path from this machine, so it should not be committed.
if [ "$OUT_DIR" != "$PROJECT_DIR" ] && git -C "$OUT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    if ! git -C "$OUT_DIR" check-ignore -q .mcp.json 2>/dev/null; then
        warn "$OUT_DIR is a git repository that does not ignore .mcp.json."
        warn "Add '.mcp.json' to its .gitignore to keep this machine's paths out of version control."
    fi
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
echo "  1. Start Claude Code from the directory holding that file:"
echo "       cd \"$OUT_DIR\" && claude"
echo "  2. Approve the 'minecraft-bedrock' MCP server prompt (Yes / Always)"
echo "  3. In Minecraft (Windows side), enter a world with cheats ON and run:"
echo "       /connect $(bash "$PROJECT_DIR/scripts/wsl-ip.sh" 2>/dev/null || echo '<WSL2-IP>'):$PORT/ws"
echo
echo "Not localhost — Minecraft is a UWP app on the Windows side and does not reach"
echo "a WSL2 listener that way. Re-read the address with ./scripts/wsl-ip.sh after a"
echo "WSL restart, since it is a NAT address that changes."
echo
echo "Claude Code must be running before you type /connect — it is what starts"
echo "the MCP server that listens on port $PORT. Only one process can hold the"
echo "port, so do not leave a second Claude Code session or a manual run-server.sh"
echo "running elsewhere."
