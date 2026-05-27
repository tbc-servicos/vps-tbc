# Guia do Desenvolvedor — Acesso ao Ambiente

Você receberá três informações do administrador:
- **Host** — endereço da sua VM
- **Usuário** — seu login
- **Senha** — trocar no primeiro acesso

---

## Opção A — Configuração automática (recomendado)

Execute o comando abaixo no seu terminal e siga as instruções:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rodrigopg/vps-tbc/main/setup-env.sh)
```

O script configura tudo automaticamente: SSH, troca de senha e teste de conexão.

---

## Opção B — Configuração manual

### 1. Verificar SSH

```bash
ssh -V
```

Se não tiver instalado:
- **Windows:** ative o OpenSSH em *Configurações → Aplicativos → Recursos opcionais*, ou instale o [Git for Windows](https://git-scm.com/download/win)
- **Mac/Linux:** já vem instalado

### 2. Configurar ~/.ssh/config

**Mac/Linux:**
```bash
nano ~/.ssh/config
```

**Windows** — abra com Notepad ou VS Code:
```
C:\Users\<seu-usuario>\.ssh\config
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
