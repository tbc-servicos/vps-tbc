# Contexto: Infraestrutura Proxmox

## Servidor

| Item | Valor |
|------|-------|
| Host | 168.195.15.225 |
| Acesso web | https://168.195.15.225:8006 (realm: Linux PAM) |
| Node | sp1-sd-tdcdistro-1 |
| vCPUs | 96 x Xeon Platinum 8160 |
| RAM | 125 GB |
| Disco | 1.8 TB ZFS (local-zfs) |
| Proxmox VE | 9.1.1 |

## Rede

| Item | Valor |
|------|-------|
| Bridge externa | vmbr0 — 168.195.15.225/31, gateway 168.195.15.224 |
| Bridge interna | vmbr1 — 10.0.0.1/24, NAT via iptables |
| DNS primário | 187.108.193.3 |
| DNS secundário | 8.8.8.8 |

**Bloco /31 = sem IPs livres para VMs com IP público.** VMs usam NAT interno com port forwarding.

## VMs

| VMID | Nome | IP interno | Porta SSH externa | Status |
|------|------|------------|-------------------|--------|
| 100 | vm-template | — | — | Template — nunca iniciar, só clonar |
| 101 | vm-tbc1 | 10.0.0.3 | 2201 | running |
| 102 | vm-tbc2 | 10.0.0.4 | 2202 | running |
| 103 | vm-tbc3 | 10.0.0.5 | 2203 | running |
| 104 | vm-tbc4 | 10.0.0.6 | 2204 | running |

## Acesso SSH

**Admin (ProxyJump — acesso root):**
```
Host proxmox     → root@168.195.15.225
Host vm-tbc1     → root@10.0.0.3  (ProxyJump proxmox)
Host vm-tbc2     → root@10.0.0.4  (ProxyJump proxmox)
Host vm-tbc3     → root@10.0.0.5  (ProxyJump proxmox)
Host vm-tbc4     → root@10.0.0.6  (ProxyJump proxmox)
```

**Dev (port forwarding direto):**
```bash
ssh -p 2201 dev1@168.195.15.225   # vm-tbc1
ssh -p 2202 dev1@168.195.15.225   # vm-tbc2
ssh -p 2203 dev1@168.195.15.225   # vm-tbc3
ssh -p 2204 dev1@168.195.15.225   # vm-tbc4
```

## Port forwarding (iptables)

Regras persistidas em `/etc/iptables/rules.v4` via `iptables-persistent`.

```bash
# Ver regras ativas
ssh proxmox 'iptables -t nat -L PREROUTING -n --line-numbers'

# Adicionar nova VM
ssh proxmox 'iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport <PORTA> -j DNAT --to-destination <IP>:22'
ssh proxmox 'iptables -A FORWARD -p tcp -d <IP> --dport 22 -j ACCEPT'
ssh proxmox 'iptables-save > /etc/iptables/rules.v4'
```

## CLI pve

Binário: `~/.local/bin/pve` (Python + proxmoxer)
Env vars em `~/.claude/settings.json` → `PVE_HOST`, `PVE_USER`, `PVE_PASS`

```bash
pve nodes                    # listar nodes
pve vms                      # listar VMs
pve stats                    # CPU/RAM/disco
pve status <vmid>            # status VM
pve start <vmid>             # iniciar
pve shutdown <vmid>          # desligar (graceful)
pve stop <vmid>              # parar (force) — confirmar antes
pve snapshot <vmid> <nome>   # snapshot
pve clone <vmid> <newid>     # clonar (full)
pve tasks                    # tarefas recentes
```

## Armadilhas conhecidas

- Login web: realm deve ser **Linux PAM** (não "Proxmox VE authentication server")
- Clones herdam MAC da template → interface sem IP. Fix obrigatório via `qm guest exec`
- Gateway pós-clone: `via:` no netplan fica apontando para o próprio IP da VM — corrigir para `10.0.0.1`
- Bloco /31: sem IP público para VMs — usar NAT vmbr1
- `pve` CLI não carrega env vars em subshell da sessão atual — nova sessão resolve
- Full clone de 100GB demora ~10min — esperar antes de iniciar próximo

## Comandos úteis no host Proxmox

```bash
# Executar comando dentro de VM sem SSH (via guest agent)
ssh proxmox 'qm guest exec <vmid> --pass-stdin=0 -- bash -c "<cmd>"'

# Clonar template
ssh proxmox 'qm clone 100 <id> --name <nome> --full 1'

# Converter VM em template
ssh proxmox 'pvesh create /nodes/sp1-sd-tdcdistro-1/qemu/<vmid>/template'
```
