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
4. Configurar port forwarding no iptables
5. Testar `ssh -p <porta> dev1@168.195.15.225 'hostname'`
6. Persistir: `ssh proxmox 'iptables-save > /etc/iptables/rules.v4'`

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
