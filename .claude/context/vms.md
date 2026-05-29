# Contexto: VMs — Configuração e Manutenção

## Stack instalado (todas as VMs)

| Software | Versão | Notas |
|----------|--------|-------|
| Ubuntu | 26.04 LTS | Server (sem GUI) |
| Node.js | v22.22.2 | via nodesource |
| Claude Code | 2.1.150 | global (`/usr/local/bin/claude`) |
| Docker | 29.5.2 CE | via get.docker.com |
| Docker Compose | v5.1.4 | plugin (`docker compose`) |
| qemu-guest-agent | instalado | necessário para `qm guest exec` |
| tmux | 3.6 | sessão persistente — `.tmux.conf` + auto-attach no template |

## Persistência de sessão (tmux)

Template já vem com tmux + auto-attach. Cada SSH interativo cai na sessão `main` (persiste no servidor → trocar de device continua de onde parou). Dotfiles de referência em `dotfiles/` (repo).

- `~/.tmux.conf`: mouse, scrollback 50k, truecolor, escape-time baixo, status bar
- `~/.bashrc`: snippet `tmux auto-attach (vps-tbc)` — guard para SSH interativo fora de tmux

Mosh não usado: resolve conexão (roaming/sleep), não persistência de sessão entre devices; exigiria UDP forward (acesso é TCP 2201).

## Usuários

| Usuário | Senha inicial | Grupos | Acesso root |
|---------|--------------|--------|-------------|
| dev1 | dev1 | docker | NÃO — sem sudo |
| dev2 | dev2 | docker | NÃO — sem sudo |
| dev3 | dev3 | docker | NÃO — sem sudo |
| dev4 | dev4 | docker | NÃO — sem sudo |

Senha inicial fraca por design — devs obrigados a trocar no primeiro login (`chage -d 0`).
Root SSH desabilitado (`PermitRootLogin no`).
Devs **não** têm sudo/root — só Docker. Acesso root só via admin (ProxyJump).

> ⚠️ Template original tinha `dev1` no grupo `sudo` — corrigido em 2026-05-28. Clones antigos podem ter herdado. Verificar pós-clone: `getent group sudo` deve estar vazio. Se não: `deluser dev1 sudo`.

## Autenticação Claude Code

Sem API key — login por conta Claude individual.

Cada usuário roda uma vez:
```bash
claude   # gera URL → abrir no browser → sessão salva em ~/.claude/
```

Sessões isoladas por usuário (`~/.claude/` separado por home).

## Rede interna das VMs

```
vm-tbc1: 10.0.0.3/24  gateway 10.0.0.1
vm-tbc2: 10.0.0.4/24  gateway 10.0.0.1
vm-tbc3: 10.0.0.5/24  gateway 10.0.0.1
vm-tbc4: 10.0.0.6/24  gateway 10.0.0.1
DNS: 187.108.193.3
```

Netplan em `/etc/netplan/*.yaml` — após editar: `sudo netplan apply`

## Adicionar nova VM (fluxo completo)

Ver guia detalhado no Confluence: https://fabricadesoftwaretbc.atlassian.net/wiki/spaces/FSW/pages/233897985

Resumo:
1. `ssh proxmox 'qm clone 100 <newid> --name <nome> --full 1'` — aguardar ~10min
2. `ssh proxmox 'qm start <newid>'`
3. Fix MAC + IP + gateway via `qm guest exec` (ver abaixo)
4. Aplicar managed-settings + wrapper de telemetria do Claude Code (ver abaixo)
5. Configurar port forwarding no iptables
6. Testar `ssh -p <porta> dev1@168.195.15.225 'hostname'`
7. Persistir: `ssh proxmox 'iptables-save > /etc/iptables/rules.v4'`

> tmux + auto-attach já vêm do template (aplicado 2026-05-29). Se clonar de template antigo, aplicar os dotfiles de `dotfiles/` manualmente.

## Fix de clone obrigatório pós-clone

```bash
ssh proxmox 'qm guest exec <vmid> --pass-stdin=0 -- bash -c "
NEW_MAC=\$(cat /sys/class/net/ens18/address)
NETPLAN=\$(ls /etc/netplan/*.yaml | head -1)
sed -i \"s/macaddress: .*/macaddress: \$NEW_MAC/\" \$NETPLAN
sed -i \"s/10\\.0\\.0\\.[0-9]*/<IP_NOVO>/g\" \$NETPLAN
sed -i \"s/via: .*/via: 10.0.0.1/\" \$NETPLAN
hostnamectl set-hostname <nome>
deluser dev1 sudo 2>/dev/null
netplan apply
echo done
"'
```

> ⚠️ O `via:` no netplan herda o IP antigo (aponta para si mesmo) — o `sed` do gateway é obrigatório.
> ⚠️ `deluser dev1 sudo` é defensivo — devs não podem ter root. Template já corrigido, mas garante em clones de templates antigos.

## Managed settings do Claude Code (obrigatório pós-clone)

Policy de sistema com precedência máxima — sobrescreve qualquer `~/.claude/settings.json` do dev e é imutável para usuários sem sudo.

Path: `/etc/claude-code/managed-settings.json` (owner `root:root`, modo `644`).

Hierarquia de precedência (maior → menor):
1. `/etc/claude-code/managed-settings.json` ← enterprise policy
2. flags CLI
3. `.claude/settings.local.json` (projeto)
4. `.claude/settings.json` (projeto)
5. `~/.claude/settings.json` (user)

Aplicar via base64 (arquivo de referência local: `managed-settings.json` na raiz do repo — **gitignored, contém token OTEL Bearer**):

```bash
# do Mac, com o repo em /Users/rodrigo/git/vps-tbc
B64=$(base64 < /Users/rodrigo/git/vps-tbc/managed-settings.json | tr -d '\n')
ssh proxmox "qm guest exec <vmid> --pass-stdin=0 -- bash -c '
  mkdir -p /etc/claude-code
  echo \"$B64\" | base64 -d > /etc/claude-code/managed-settings.json
  chown root:root /etc/claude-code/managed-settings.json
  chmod 644 /etc/claude-code/managed-settings.json
'"
```

> ⚠️ O JSON contém o token OTEL (`OTEL_EXPORTER_OTLP_HEADERS`) — nunca commitar. Está no `.gitignore`.
> Conteúdo: telemetria OTEL, `forceLoginMethod: claudeai`, `language: portuguese`, plugins MCP, announcements TBC.
> ⚠️ `OTEL_RESOURCE_ATTRIBUTES` **não** fica no managed-settings — é definido pelo wrapper (fonte única, evita conflito de precedência).

## Launch wrapper de telemetria (identifica dev por usuário Linux)

Devs compartilham a mesma conta Claude → `user.email`/`account_uuid` são idênticos e não distinguem quem é quem na telemetria. O wrapper injeta `enduser.id=<user Linux>` e `host.name=<VM>` no `OTEL_RESOURCE_ATTRIBUTES`.

Path: `/usr/local/bin/claude` (root:root **755**). `/usr/local/bin` precede `/usr/bin` no PATH → wrapper resolve antes do binário real (`/usr/bin/claude`).

Arquivo de referência: `claude-wrapper.sh` na raiz do repo (versionado — sem secret).

```bash
B64_WRAP=$(base64 < /Users/rodrigo/git/vps-tbc/claude-wrapper.sh | tr -d '\n')
ssh proxmox "qm guest exec <vmid> --pass-stdin=0 -- bash -c '
  echo \"$B64_WRAP\" | base64 -d > /usr/local/bin/claude
  chown root:root /usr/local/bin/claude
  chmod 755 /usr/local/bin/claude
'"
```

Conteúdo do wrapper:
```bash
export OTEL_RESOURCE_ATTRIBUTES="org=TBC,team.id=dev,plan=teams,enduser.id=$(id -un),host.name=$(hostname)"
exec /usr/bin/claude "$@"
```

> Usa `id -un` (não `$USER` — vazio em shell não-login). `exec` preserva sinais/exit code. Path absoluto evita recursão.
> ⚠️ **Burlável**: dev que roda `/usr/bin/claude` direto pula o wrapper e não emite `enduser.id`. Para identidade não-burlável, única forma é 1 conta Claude por dev (aí `user.email` resolve sozinho).

Telemetria segmentável por: `user.email`/`account_uuid` (conta), `enduser.id` (user Linux), `host.name` (VM).

## Gerar mensagem de boas-vindas para dev

```bash
cd /Users/rodrigo/git/vps-tbc
./gerar-mensagem-dev.sh
```

Script local (não versionado). Seleciona VM e usuário por menu, gera mensagem com host, porta, usuário e senha.

## Documentação Confluence (restrita)

| Página | URL |
|--------|-----|
| Guia do Administrador | https://fabricadesoftwaretbc.atlassian.net/wiki/spaces/FSW/pages/233832449 |
| Como criar nova VM | https://fabricadesoftwaretbc.atlassian.net/wiki/spaces/FSW/pages/233897985 |
| Guia do Dev (pública) | https://fabricadesoftwaretbc.atlassian.net/wiki/spaces/FSW/pages/233570305 |
