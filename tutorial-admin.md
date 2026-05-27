# Guia do Administrador — Ambientes de Desenvolvimento

## Infraestrutura

- **Proxmox:** `168.195.15.225` (acesso root via SSH)
- **Rede interna:** `10.0.0.0/24` (NAT, sem rota direta da internet)
- **VMs:** acessíveis apenas via jump host (proxmox)

## VMs disponíveis

| VM | VMID | IP |
|----|------|----|
| vm-tbc1 | 101 | 10.0.0.3 |
| vm-tbc2 | 102 | 10.0.0.4 |
| vm-tbc3 | 103 | 10.0.0.5 |
| vm-tbc4 | 104 | 10.0.0.6 |

## Configurar ~/.ssh/config

```
Host proxmox
    HostName 168.195.15.225
    User root
    ForwardAgent yes

Host vm-tbc1
    HostName 10.0.0.3
    User root
    ProxyJump proxmox

Host vm-tbc2
    HostName 10.0.0.4
    User root
    ProxyJump proxmox

Host vm-tbc3
    HostName 10.0.0.5
    User root
    ProxyJump proxmox

Host vm-tbc4
    HostName 10.0.0.6
    User root
    ProxyJump proxmox
```

## Acesso direto

```bash
# Proxmox
ssh proxmox

# VM específica
ssh vm-tbc1

# Sem ~/.ssh/config configurado
ssh -J root@168.195.15.225 root@10.0.0.3
```

## Gerenciar VMs (no Proxmox)

```bash
# Listar VMs
ssh proxmox 'qm list'

# Iniciar / parar
ssh proxmox 'qm start 101'
ssh proxmox 'qm stop 101'

# Executar comando numa VM sem SSH
ssh proxmox 'qm guest exec 101 --pass-stdin=0 -- bash -c "comando"'

# Clonar template para nova VM
ssh proxmox 'qm clone 100 <novo_vmid> --name <nome> --full 1'
```

## Gerenciar usuários nas VMs

```bash
# Criar usuário
ssh vm-tbc1 'useradd -m -s /bin/bash -G docker <usuario>'
echo '<usuario>:<senha>' | ssh vm-tbc1 'chpasswd'

# Forçar troca de senha no primeiro login
ssh vm-tbc1 'chage -d 0 <usuario>'

# Listar usuários
ssh vm-tbc1 'getent passwd | grep -v nologin | grep -v false'
```

## Acessar interface web do Proxmox

URL: `https://168.195.15.225:8006`
- Realm: **Linux PAM** (não "Proxmox VE authentication server")
