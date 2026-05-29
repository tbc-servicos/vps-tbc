#!/usr/bin/env bash
# Ponte Playwright: MCP server headed no Mac (browser visível) + reverse tunnel para vm-tbc1.
# A VM (Claude Code) conecta no MCP via http://localhost:8931/mcp através do tunnel.
#
# Uso:
#   ./playwright-vm-bridge.sh start   # sobe MCP server + tunnel
#   ./playwright-vm-bridge.sh stop    # derruba ambos
#   ./playwright-vm-bridge.sh status

set -uo pipefail

PORT=8931
VM_HOST="vm-tbc1"                 # ~/.ssh/config (ProxyJump proxmox)
PROFILE_DIR="$HOME/.playwright-vm-profile"
MCP_PIDFILE="/tmp/pw-vm-mcp.pid"
TUN_PIDFILE="/tmp/pw-vm-tunnel.pid"
LOG="/tmp/pw-vm-bridge.log"

start() {
  # 1. MCP server headed (browser aparece no Mac), perfil dedicado persistente
  if [ -f "$MCP_PIDFILE" ] && kill -0 "$(cat "$MCP_PIDFILE")" 2>/dev/null; then
    echo "MCP server já rodando (pid $(cat "$MCP_PIDFILE"))"
  else
    mkdir -p "$PROFILE_DIR"
    npx @playwright/mcp@0.0.70 \
      --port "$PORT" \
      --browser chromium \
      --user-data-dir "$PROFILE_DIR" \
      --output-dir "$HOME/.playwright-vm-profile/output" \
      > "$LOG" 2>&1 &
    echo $! > "$MCP_PIDFILE"
    sleep 4
    echo "MCP server iniciado (pid $(cat "$MCP_PIDFILE")) em http://localhost:$PORT/mcp"
  fi

  # 2. Reverse tunnel: VM:localhost:PORT → Mac:localhost:PORT
  #    Mantém Host=localhost na VM (Chrome/DNS-rebind safe) e o MCP é alcançável de lá.
  if [ -f "$TUN_PIDFILE" ] && kill -0 "$(cat "$TUN_PIDFILE")" 2>/dev/null; then
    echo "Tunnel já ativo (pid $(cat "$TUN_PIDFILE"))"
  else
    ssh -N -R "$PORT:localhost:$PORT" \
      -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
      "$VM_HOST" &
    echo $! > "$TUN_PIDFILE"
    sleep 2
    echo "Tunnel ativo (pid $(cat "$TUN_PIDFILE")): VM localhost:$PORT → Mac"
  fi

  echo ""
  echo "Na VM, o MCP playwright deve apontar para: http://localhost:$PORT/mcp"
  echo "Teste da VM:  curl -s -o /dev/null -w '%{http_code}\\n' http://localhost:$PORT/sse"
}

stop() {
  for pf in "$TUN_PIDFILE" "$MCP_PIDFILE"; do
    if [ -f "$pf" ]; then
      pid=$(cat "$pf")
      kill "$pid" 2>/dev/null && echo "morto pid $pid"
      rm -f "$pf"
    fi
  done
}

status() {
  for pf in "$MCP_PIDFILE" "$TUN_PIDFILE"; do
    if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then
      echo "$(basename "$pf"): ativo (pid $(cat "$pf"))"
    else
      echo "$(basename "$pf"): parado"
    fi
  done
}

case "${1:-}" in
  start)  start ;;
  stop)   stop ;;
  status) status ;;
  *) echo "uso: $0 {start|stop|status}"; exit 1 ;;
esac
