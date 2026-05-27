# Guia do Desenvolvedor — Acesso ao Ambiente

Você receberá três informações do administrador:
- **Host** — endereço da sua VM
- **Usuário** — seu login
- **Senha** — trocar no primeiro acesso

---

## Pré-requisito: terminal com Bash

- **Mac/Linux:** use o terminal nativo
- **Windows:** instale o **WSL 2** antes de continuar

  ```powershell
  # Execute no PowerShell como Administrador
  wsl --install
  ```

  Reinicie o computador quando solicitado. Após reiniciar, abra o **Ubuntu** pelo menu Iniciar e conclua a configuração inicial. Use sempre o terminal do WSL daqui em diante.

---

## Opção A — Configuração automática (recomendado)

Execute no terminal e siga as instruções:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbc-servicos/vps-tbc/main/setup-env.sh)
```

O script configura tudo automaticamente: SSH, troca de senha e teste de conexão.

---

## Opção B — Configuração manual

### 1. Configurar ~/.ssh/config

```bash
nano ~/.ssh/config
```

Adicione (substituindo os valores pelos que o admin enviou):

```
Host meu-ambiente
    HostName <HOST>
    User <USUARIO>
    ProxyJump <JUMP_HOST>
```

### 3. Conectar

```bash
ssh meu-ambiente
```

Na primeira vez confirme com `yes` quando perguntado sobre o fingerprint.

### 4. Trocar a senha (obrigatório)

```bash
passwd
```

Informe a senha atual, depois a nova duas vezes.

---

## Ferramentas disponíveis

| Ferramenta | Verificar |
|------------|-----------|
| Claude Code | `claude --version` |
| Docker | `docker run hello-world` |
| Node.js | `node --version` |

### Ativar o Claude Code

Na primeira vez:

```bash
claude
```

Uma URL será exibida no terminal. Abra no navegador, faça login com sua conta Anthropic e autorize.

---

## VS Code com Remote SSH (recomendado)

1. Instale a extensão **Remote - SSH** (Microsoft)
2. `F1` → `Remote-SSH: Connect to Host`
3. Selecione `meu-ambiente`

VS Code completo rodando diretamente na sua VM.

---

## Referência rápida

| Ação | Comando |
|------|---------|
| Conectar | `ssh meu-ambiente` |
| Abrir Claude Code | `claude` |
| Verificar Docker | `docker ps` |
| Sair | `exit` |
