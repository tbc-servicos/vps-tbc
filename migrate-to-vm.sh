#!/usr/bin/env bash
# Migração do Claude Code local (Mac) → vm-tbc1/dev1
# Uso: ./migrate-to-vm.sh [--dry-run]
# NÃO versionar com secrets resolvidos. Revisar cada bloco antes de rodar.
#
# Pré-requisitos:
#   - SSH config com `vm-tbc1` (ProxyJump) OU usar porta 2201
#   - Tudo que for via git clone deve estar pushed
#
# O que este script NÃO faz (manual pós-migração):
#   - claude login (conta compartilhada — autenticar 1x)
#   - tokens MCP (ATLASSIAN_API_TOKEN, N8N_API_KEY) — colocar à mão na VM
#   - KeePass master password — TROCAR antes de copiar .kdbx (atual é "master")

set -euo pipefail

DRY=""
[[ "${1:-}" == "--dry-run" ]] && DRY="echo [DRY] "

# Destino: usar ProxyJump (admin) para setup; dev1 é o home alvo
VM_SSH="ssh vm-tbc1"          # admin via ProxyJump — ajustar se necessário
DEV_HOME="/home/dev1"
RSYNC_SSH="-e 'ssh -J proxmox'"

# ─── cores ───────────────────────────────────────────────────────────────────
b() { echo -e "\033[1m$*\033[0m"; }

# ════════════════════════════════════════════════════════════════════════════
# 1. PROJETOS — clone fresh onde há remote, rsync onde não há
# ════════════════════════════════════════════════════════════════════════════
b "=== 1. Projetos ==="

# Projetos selecionados para migração: conciliador-v2, agente-erp

# agente-erp: clone fresh (main, tudo pushed)
# GitHub org tbc-servicos → acesso via token gh (HTTPS + credential helper), NÃO via SSH key
# (a chave rodrigopg-GitHub não está autorizada na org). Pré-req na VM: gh auth setup-git
b "  clone agente-erp (HTTPS + gh helper)"
${DRY}$VM_SSH "mkdir -p $DEV_HOME/git && cd $DEV_HOME/git && [ -d agente-erp ] || git clone https://github.com/tbc-servicos/agente-erp.git agente-erp"

# conciliador-v2: rsync working tree — branch local feature/006-reconciliation-config
# não está no remote (sem upstream). Preserva .git para não perder a branch.
b "  rsync conciliador-v2 (branch local sem push)"
# macOS usa openrsync — NÃO suporta --info=progress2 (usar -v se quiser verbose)
${DRY}rsync -az \
  --exclude=node_modules --exclude=.venv --exclude=__pycache__ \
  --exclude=dist --exclude=build --exclude=.next --exclude=vendor --exclude=target \
  -e "ssh -J proxmox" \
  ~/git/conciliador-v2/ dev1@10.0.0.3:$DEV_HOME/git/conciliador-v2/

# ════════════════════════════════════════════════════════════════════════════
# 2. SKILLS CUSTOM — via repo claude_skills (clone) + skills só-locais (rsync)
# ════════════════════════════════════════════════════════════════════════════
b "=== 2. Skills custom ==="

# repo claude_skills (Bitbucket) → contém: cassi, confluence, discli, fluig, jira,
# jira-api, keepass, mcp-proxy, memory, mit-docs, playwright, protheus, TAE, tempo
${DRY}$VM_SSH "cd $DEV_HOME/git && [ -d claude_skills ] || git clone git@bitbucket.org:fabricatbc/claude_skills.git claude_skills"
# Ativar as skills do repo conforme o setup-projeto.sh do claude_skills (ver README do repo).

# skills que SÓ existem em ~/.claude/skills (não no repo claude_skills):
# grafana, onfly, lancar-horas, sync-tempo, proxmox, prime-context, graphify,
# github-branch-protection, easypanel, sandeco-token-reduce
# (discli e keepass já vêm do repo — não duplicar)
b "  rsync skills só-locais → ~/.claude/skills"
${DRY}rsync -az --exclude=node_modules --exclude='*.log' -e "ssh -J proxmox" \
  ~/.claude/skills/{grafana,onfly,lancar-horas,sync-tempo,proxmox,prime-context,graphify,github-branch-protection,easypanel,sandeco-token-reduce} \
  dev1@10.0.0.3:$DEV_HOME/.claude/skills/

# ════════════════════════════════════════════════════════════════════════════
# 3. COMMANDS + HOOKS + RULES
# ════════════════════════════════════════════════════════════════════════════
b "=== 3. Commands, hooks, rules ==="
${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/commands/ dev1@10.0.0.3:$DEV_HOME/.claude/commands/
${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/hooks/    dev1@10.0.0.3:$DEV_HOME/.claude/hooks/
${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/rules/    dev1@10.0.0.3:$DEV_HOME/.claude/rules/

# ════════════════════════════════════════════════════════════════════════════
# 4. CLAUDE.md GLOBAL + MEMORY (só memory/, NÃO o projects/ inteiro de 553M)
# ════════════════════════════════════════════════════════════════════════════
b "=== 4. CLAUDE.md + memory ==="
${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/CLAUDE.md dev1@10.0.0.3:$DEV_HOME/.claude/CLAUDE.md
${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/memory/   dev1@10.0.0.3:$DEV_HOME/.claude/memory/
# memórias por-projeto: só os subdirs memory/ (não transcripts/history)
b "  memórias por-projeto"
${DRY}rsync -az --include='*/' --include='memory/***' --exclude='*' \
  -e "ssh -J proxmox" \
  ~/.claude/projects/ dev1@10.0.0.3:$DEV_HOME/.claude/projects/

# ════════════════════════════════════════════════════════════════════════════
# 5. KEEPASS (depois de TROCAR master password!)
# ════════════════════════════════════════════════════════════════════════════
b "=== 5. KeePass — SÓ APÓS TROCAR MASTER PASSWORD ==="
echo "  ⚠️ MANUAL: trocar master do Personal.kdbx (atual: master) ANTES."
echo "  ⚠️ .kdbx ficam no disco da VM. dev1 exclusivo seu, mas root (admin) lê."
# ${DRY}rsync -az -e "ssh -J proxmox" ~/.claude/keepass-config.json dev1@10.0.0.3:$DEV_HOME/.claude/keepass-config.json
# Copiar .kdbx + .keyx para paths que existam na VM e ajustar keepass-config.json
# (paths atuais apontam pro Google Drive do Mac — não existem na VM)

b "=== Concluído (passos automáticos). Ver runbook para passos manuais. ==="
