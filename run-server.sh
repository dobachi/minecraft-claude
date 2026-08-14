#!/usr/bin/env bash
# Wrapper that launches the Mming-Lab MCP server with stderr captured to logs/server.log.
#
# stdout is left connected to the parent process (Claude Code / Claude Desktop) because
# the MCP protocol uses stdin/stdout for JSON-RPC framing — redirecting stdout would
# break the integration. Only stderr is diverted to the log file.
#
# Linux port of run-server.cmd.
#
# Usage: ./run-server.sh [--port=8001] [--lang=ja]
#   Any arguments are passed straight through to the MCP server.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/server.log"
SERVER_JS="$PROJECT_DIR/server/dist/server.js"

mkdir -p "$LOG_DIR"

if [ ! -f "$SERVER_JS" ]; then
    # Report on stderr AND to the log — stdout belongs to the MCP transport.
    msg="run-server.sh: $SERVER_JS not found. Run ./setup.sh first."
    echo "$msg" >&2
    echo "$msg" >>"$LOG_FILE"
    exit 1
fi

{
    echo
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') server start (pid=$$) ==="
} >>"$LOG_FILE"

# exec so the node process inherits this PID (the one just logged above) and
# receives signals from the parent directly.
exec node "$SERVER_JS" "$@" 2>>"$LOG_FILE"
