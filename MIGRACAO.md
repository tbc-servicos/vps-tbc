# Migração Claude Code: Mac → vm-tbc1/dev1

Runbook da migração do ambiente local para `vm-tbc1` (10.0.0.3, porta 2201), usuário `dev1` (exclusivo do Rodrigo).

## Contexto e riscos

- **Conta Claude compartilhada** entre os 4 devs — `user.email` igual. Telemetria distingue por `enduser.id` (wrapper).
- **`OTEL_LOG_USER_PROMPTS=1`** no managed-settings — todo prompt vai pro otel-tbc, inclusive de projetos pessoais.
- **dev1 é exclusivo do Rodrigo** — outros devs não logam nele. Mas `root`/admin (inclui João Vitor) lê `/home/dev1`.
- **VM exposta na internet** (porta 2201). Não colocar secret de hypervisor (PVE) nem credencial de produção solta.

## O que NÃO migrar

- `~/.claude/projects/` inteiro (553M de transcripts) — só os subdirs `memory/`
- `~/.claude/settings.json` bruto — tem `statusLine`/`hooks` com paths locais que quebram; chaves `language`/`forceLoginMethod` já vêm do managed-settings. Portar só o que interessa à mão.
- `~/.claude/mcp.json` bruto — tem `ATLASSIAN_API_TOKEN`, `N8N_API_KEY` em claro. Reconfigurar na VM.
- history, file-history, sessions, security, cache, playwright-output — ruído local.

## Pré-requisitos de autenticação na VM (FEITO 2026-05-28)

Setup de credenciais git já aplicado em vm-tbc1/dev1:

1. **Chaves SSH copiadas** para `~/.ssh/` (dev1): `rodrigopg-GitHub`, `rodrigopgoncalves-Bitbucket` (priv 600, pub 644).
2. **`~/.ssh/config`** mapeia `github.com` → chave GitHub, `bitbucket.org` → chave Bitbucket (`IdentitiesOnly yes`).
3. **gh CLI 2.93** instalado via apt (root) + autenticado com token (`gh auth login --with-token`).
4. **gh credential helper** (`gh auth setup-git`) → git HTTPS usa o token gh.

> ⚠️ **Auth por destino:**
> - **GitHub org `tbc-servicos`** (agente-erp, conciliador-v2, vps-tbc): acesso via **token gh / HTTPS**, NÃO via SSH key. A chave `rodrigopg-GitHub` não está autorizada na org — clone SSH dá "Repository not found". Usar URL `https://github.com/...` (gh helper resolve).
> - **Bitbucket** (claude_skills): SSH key funciona — usar `git@bitbucket.org:...`.

## Passos automáticos

```bash
cd /Users/rodrigo/git/vps-tbc
./migrate-to-vm.sh --dry-run   # revisar
./migrate-to-vm.sh             # executar
```

Cobre: **agente-erp** (clone fresh) + **conciliador-v2** (rsync — branch local `feature/006-reconciliation-config` sem push), clone `claude_skills`, rsync 10 skills locais, commands/hooks/rules, CLAUDE.md global, memórias.

> Projetos escolhidos: apenas `conciliador-v2` e `agente-erp`. Para adicionar outros depois, editar o bloco de projetos em `migrate-to-vm.sh`.

## Passos manuais (pós-script)

### 1. Login Claude Code
```bash
ssh -p 2201 dev1@168.195.15.225
claude   # abre URL → autenticar com a conta TBC compartilhada
```

### 2. MCP servers (tokens à mão — nunca commitar)
Template pronto na VM: `~/mcp-template.json` (estrutura dos 3 servers com placeholders). Preencher os tokens e salvar como `~/.claude/mcp.json` ou no `.mcp.json` do projeto:
- `ATLASSIAN_API_TOKEN` (bitbucket) — KeePass `Tokens/BitBucket - API Token`
- `N8N_API_URL` / `N8N_API_KEY` — n8n só funciona se o endpoint for alcançável da VM
- `SUPABASE_ACCESS_TOKEN` — token Supabase

Validar conectividade de cada endpoint a partir da VM antes de confiar.

### 3. Plugins (reinstalar via marketplace — não copiar arquivos)
Script pronto na VM (`~/vm-post-migrate.sh`) — adiciona 9 marketplaces e instala 25 plugins:
```bash
ssh -p 2201 dev1@168.195.15.225
bash ~/vm-post-migrate.sh
claude plugin list   # verificar
```
Marketplaces: claude-plugins-official, mwguerra, superpowers, beads, automagik, claude-code-warp, caveman, dtsoden-easypanel, dataagile-agent-kit (tbc-servicos).

### 4. CLAUDE.md global — REVISAR antes de usar
O `~/.claude/CLAUDE.md` tem dados pessoais (KeePass accounts, assinatura, contexto TBC). Em dev1 exclusivo é aceitável, mas confirmar que não há secret embutido.

### 5. KeePass — só após TROCAR master password
1. No Mac, trocar master do `Personal.kdbx` (atual: `master` — fraco)
2. Copiar `.kdbx` + `.keyx` para um path na VM (ex: `/home/dev1/.keepass/`)
3. Ajustar `keepass-config.json` para os paths da VM (os atuais apontam pro Google Drive do Mac)
4. Adicionar as senhas master no secret store da VM (libsecret/secret-tool — não Keychain, é Linux)

> ⚠️ `.kdbx` com TODAS as senhas fica no disco da VM. root/admin lê. Avaliar se vale.

### 6. Hooks caveman — depende de Node
Os hooks em `~/.claude/hooks/*.js` precisam de Node (já tem v22 na VM). Validar que rodam:
```bash
node ~/.claude/hooks/caveman-activate.js --test 2>&1 || echo "ajustar"
```

## Verificação final

```bash
ssh -p 2201 dev1@168.195.15.225
claude --version                          # 2.1.x
ls ~/git/                                 # 10 projetos
ls ~/.claude/skills/                      # skills locais
claude -p "liste skills disponíveis"      # confirma skills + plugins carregados
```

## Limitações conhecidas

- Telemetria loga prompts (OTEL_LOG_USER_PROMPTS=1) — cuidado com projetos pessoais.
- MCP `jetbrains` inútil sem IDE na VM.
- Wrapper de telemetria é burlável via `/usr/bin/claude` direto.
