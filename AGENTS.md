# vps-tbc

Infraestrutura Proxmox VE 9.1 com VMs Ubuntu 26.04 para desenvolvimento com Claude Code + Docker. 4 VMs ativas, acesso externo via port forwarding (portas 2201-2204).

## Carregar contexto antes de trabalhar

| Área | Arquivo |
|------|---------|
| Proxmox, rede, port forwarding, CLI pve | `.claude/context/infra.md` |
| VMs, usuários, stack, fix de clone, tmux | `.claude/context/vms.md` |
| Migração ambiente local → VM | `MIGRACAO.md` |
| Playwright na VM com browser no Mac | `PLAYWRIGHT-VM.md` |
| Dotfiles aplicados ao template | `dotfiles/` |

## Regras inegociáveis

- Template VMID 100: nunca iniciar — apenas clonar. Para editar: `qm set 100 --template 0` → start → fix → shutdown → `--template 1`
- Pós-clone: fix de MAC + gateway obrigatório antes de tentar SSH
- Gateway no netplan sempre `10.0.0.1` — clone herda IP errado no `via:`
- Devs sem sudo/root — só Docker. Acesso root só via admin (ProxyJump)
- `stop`/`rollback`: confirmar com usuário antes — destrutivo
- Full clone demora ~10min — não interromper
- VM exposta na internet (porta 220N) — não pôr secret de hypervisor/produção solto

## Comandos essenciais

```bash
# Proxmox CLI
pve nodes && pve vms && pve stats

# SSH admin (ProxyJump)
ssh proxmox            # host Proxmox
ssh vm-tbc1            # VM 1 via ProxyJump

# SSH dev (port forwarding)
ssh -p 2201 dev1@168.195.15.225   # vm-tbc1
ssh -p 2202 dev1@168.195.15.225   # vm-tbc2
ssh -p 2203 dev1@168.195.15.225   # vm-tbc3
ssh -p 2204 dev1@168.195.15.225   # vm-tbc4

# Executar como root numa VM
ssh proxmox 'qm guest exec <vmid> --pass-stdin=0 -- bash -c "<cmd>"'
```
