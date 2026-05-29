# Playwright na VM com browser no Mac

A VM (vm-tbc1) não tem display. Para rodar Playwright via MCP **com o browser visível no Mac**, o MCP server roda no Mac (browser local) e a VM conecta no MCP através de um reverse SSH tunnel.

```
┌─ Mac ──────────────────────────┐         ┌─ vm-tbc1 ────────────┐
│ @playwright/mcp --port 8931     │◀───────│ Claude Code           │
│  └─ Chromium (visível)          │  tunnel │  mcp: playwright-mac  │
│ ssh -R 8931:localhost:8931 ─────┼─────────▶ localhost:8931/mcp   │
└─────────────────────────────────┘         └──────────────────────┘
```

Por que MCP no Mac (não CDP split): menos partes móveis, sem gotchas de Host-header do CDP. Só o protocolo MCP cruza o tunnel.

## Uso

**No Mac**, antes de usar Playwright na VM:
```bash
cd /Users/rodrigo/git/vps-tbc
./playwright-vm-bridge.sh start   # sobe MCP server (browser headed) + tunnel
# ... trabalhar na VM ...
./playwright-vm-bridge.sh stop    # derruba ao terminar
./playwright-vm-bridge.sh status
```

**Na VM**, o `~/.claude/mcp.json` já aponta para o tunnel:
```json
{ "mcpServers": { "playwright-mac": { "url": "http://localhost:8931/mcp" } } }
```

Reiniciar o `claude` na VM após subir a ponte para o MCP conectar.

## Detalhes

- **Perfil**: dedicado limpo em `~/.playwright-vm-profile` no Mac (sem cookies/logins pessoais). Para usar logins, ajustar `--user-data-dir` no script.
- **Tunnel `-R 8931:localhost:8931`**: bind no loopback da VM → Host header fica `localhost` → sem problema de DNS-rebind.
- **Endpoint**: `/mcp` (HTTP streamable). `/sse` é legacy.
- Browser **sempre abre no Mac** — a VM só dirige.

## Verificação

```bash
# da VM, com a ponte ativa:
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8931/sse   # 200 = OK
```

## Limitações

- Ponte precisa estar ativa no Mac enquanto a VM usa Playwright. Fecha = para.
- Plugin `playwright@claude-plugins-official` na VM traz um MCP com paths Mac — não usar esse; usar o `playwright-mac` (remoto) do mcp.json.
