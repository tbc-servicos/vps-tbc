#!/usr/bin/env bash
set -euo pipefail

# ─── cores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*"; exit 1; }

echo
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     Configuração do Ambiente Dev     ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo

# ─── verificar SSH ────────────────────────────────────────────────────────────
if ! command -v ssh &>/dev/null; then
    error "SSH não encontrado. Instale o OpenSSH e tente novamente."
fi

# ─── coletar dados ───────────────────────────────────────────────────────────
echo -e "${BOLD}Informe os dados recebidos do administrador:${RESET}"
echo

read -rp "  Host da VM (ex: 10.0.0.3 ou vm.exemplo.com): " VM_HOST
read -rp "  Jump host (deixe em branco se conexão direta): " JUMP_HOST
read -rp "  Usuário: " VM_USER
read -rsp "  Senha: " VM_PASS
echo
read -rp "  Alias para o ambiente (ex: meu-ambiente): " VM_ALIAS

echo

# ─── validações básicas ───────────────────────────────────────────────────────
[[ -z "$VM_HOST" ]]  && error "Host não pode ser vazio."
[[ -z "$VM_USER" ]]  && error "Usuário não pode ser vazio."
[[ -z "$VM_PASS" ]]  && error "Senha não pode ser vazia."
[[ -z "$VM_ALIAS" ]] && VM_ALIAS="meu-ambiente"

# ─── ~/.ssh/config ────────────────────────────────────────────────────────────
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

info "Configurando ~/.ssh/config..."

# remover entrada anterior com mesmo alias
if grep -q "^Host ${VM_ALIAS}$" "$SSH_CONFIG" 2>/dev/null; then
    warn "Entrada '${VM_ALIAS}' já existe — sobrescrevendo."
    # remover bloco existente
    perl -i -0pe "s/\nHost ${VM_ALIAS}\n(    .*\n)*//g" "$SSH_CONFIG" 2>/dev/null || true
fi

{
    echo ""
    echo "Host ${VM_ALIAS}"
    echo "    HostName ${VM_HOST}"
    echo "    User ${VM_USER}"
    if [[ -n "$JUMP_HOST" ]]; then
        echo "    ProxyJump ${JUMP_HOST}"
    fi
} >> "$SSH_CONFIG"

chmod 600 "$SSH_CONFIG"
success "~/.ssh/config atualizado (alias: ${VM_ALIAS})"

# ─── testar conexão ───────────────────────────────────────────────────────────
info "Testando conexão com ${VM_HOST}..."

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=no)
if [[ -n "$JUMP_HOST" ]]; then
    SSH_OPTS+=(-J "$JUMP_HOST")
fi

if command -v sshpass &>/dev/null; then
    CONN_TEST=$(sshpass -p "$VM_PASS" ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_HOST}" "echo ok" 2>&1) || true
else
    warn "sshpass não instalado — testando sem senha (pode pedir senha manualmente)."
    CONN_TEST=$(ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_HOST}" "echo ok" 2>&1) || true
fi

if [[ "$CONN_TEST" != *"ok"* ]]; then
    warn "Não foi possível verificar a conexão automaticamente."
    warn "Teste manualmente com: ssh ${VM_ALIAS}"
else
    success "Conexão estabelecida com sucesso."
fi

# ─── instrução de troca de senha ─────────────────────────────────────────────
echo
echo -e "${YELLOW}${BOLD}Próximo passo obrigatório:${RESET}"
echo -e "  Conecte na VM e troque sua senha:"
echo
echo -e "  ${BOLD}ssh ${VM_ALIAS}${RESET}"
echo -e "  ${BOLD}passwd${RESET}"
echo

# ─── instrução Claude Code ────────────────────────────────────────────────────
echo -e "${YELLOW}${BOLD}Para ativar o Claude Code na VM:${RESET}"
echo -e "  Após conectar, execute: ${BOLD}claude${RESET}"
echo -e "  Siga a URL exibida para autenticar com sua conta Anthropic."
echo

success "Configuração concluída! Acesse com: ${BOLD}ssh ${VM_ALIAS}${RESET}"
echo
