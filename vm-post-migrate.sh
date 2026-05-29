#!/usr/bin/env bash
# Pós-migração: rodar DENTRO da vm-tbc1 (após `claude` logado).
# Reinstala marketplaces + plugins. Os plugins baixam via git dos marketplaces — não copiamos arquivos.
#
# Uso na VM:  bash ~/vm-post-migrate.sh
# Pré-req: claude já logado (claude → autenticar no browser uma vez).

set -uo pipefail
b() { echo -e "\033[1m$*\033[0m"; }

b "=== 1. Adicionar marketplaces ==="
MARKETPLACES=(
  "anthropics/claude-plugins-official"
  "mwguerra/claude-code-plugins"
  "obra/superpowers-marketplace"
  "steveyegge/beads"
  "automagik-dev/genie"
  "warpdotdev/claude-code-warp"
  "JuliusBrussee/caveman"
  "dtsoden/easypanel-claude-plugin"
  "https://github.com/tbc-servicos/dataagile-agent-kit.git"
)
for m in "${MARKETPLACES[@]}"; do
  b "  marketplace add $m"
  claude plugin marketplace add "$m" 2>&1 | tail -2 || echo "  (já existe ou erro — seguir)"
done

b "=== 2. Instalar plugins ==="
PLUGINS=(
  "docker-local@mwguerra-marketplace"
  "docker-specialist@mwguerra-marketplace"
  "filament-specialist@mwguerra-marketplace"
  "terminal-specialist@mwguerra-marketplace"
  "test-specialist@mwguerra-marketplace"
  "commit-commands@claude-plugins-official"
  "laravel-boost@claude-plugins-official"
  "php-lsp@claude-plugins-official"
  "claude-md-management@claude-plugins-official"
  "superpowers@claude-plugins-official"
  "beads@beads-marketplace"
  "playwright@claude-plugins-official"
  "pr-review-toolkit@claude-plugins-official"
  "code-review@claude-plugins-official"
  "code-simplifier@claude-plugins-official"
  "skill-creator@claude-plugins-official"
  "ralph-loop@claude-plugins-official"
  "security-guidance@claude-plugins-official"
  "claude-code-setup@claude-plugins-official"
  "telegram@claude-plugins-official"
  "genie@automagik"
  "warp@claude-code-warp"
  "atlassian@claude-plugins-official"
  "caveman@caveman"
  "easypanel@dtsoden-easypanel"
)
for p in "${PLUGINS[@]}"; do
  b "  install $p"
  claude plugin install "$p" 2>&1 | tail -2 || echo "  (erro — seguir)"
done

b "=== Concluído. Reiniciar claude para carregar plugins. ==="
b "Verificar: claude plugin list"
