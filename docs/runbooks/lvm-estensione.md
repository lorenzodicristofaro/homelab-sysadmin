# Runbook: estendere un volume LVM a caldo

| Voce | Valore |
| --- | --- |
| Sistemi | VM RHEL 9 con dati su LVM (es. rhel-db01, /pgdata) |
| Quando usarlo | Filesystem quasi pieno (alert disco > 85%) su un volume LVM |
| Impatto | Nessun fermo: XFS si estende con il filesystem montato |
| Durata | 10-15 minuti |
| Riferimenti | CHG00300xx (creazione del volume) |

## 1. Verifica la situazione

```bash
df -h /pgdata                 # uso del filesystem
sudo lvs                      # volumi logici e dimensioni
sudo vgs                      # spazio libero nel volume group (colonna VFree)
lsblk                         # dischi e partizioni
```

- Se `VFree` del volume group e' sufficiente: vai al punto 3.
- Se `VFree` e' zero o insufficiente: serve un nuovo disco, punto 2.

## 2. Aggiungi un disco al volume group (solo se serve)

```bash
# [PVE] aggiunge un disco da 10 GB alla VM 202
qm set 202 --scsi2 nvme:10,discard=on,ssd=1

# [VM]
lsblk                         # il nuovo disco, ad esempio sdc, senza partizioni
sudo pvcreate /dev/sdc        # ATTENZIONE: verifica il nome, cancella il contenuto
sudo vgextend vg_data /dev/sdc
sudo vgs                      # VFree aumentato
```

Dopo aver aggiunto un disco a mano, Terraform deve ignorare i dischi della VM
(`ignore_changes = [started, disk]` in `terraform/vms.tf`).

## 3. Estendi volume e filesystem

```bash
sudo lvextend -r -L +3G /dev/vg_data/lv_pgdata
```

| Opzione | Significato |
| --- | --- |
| `-L +3G` | aggiunge 3 GB (in alternativa `-l +100%FREE` usa tutto lo spazio libero) |
| `-r` | ridimensiona anche il filesystem; senza, il volume cresce ma `df` non cambia |

## 4. Verifica

```bash
df -h /pgdata                 # dimensione aumentata
sudo lvs
sudo systemctl status postgresql --no-pager   # il servizio non si e' mai fermato
```

## 5. Rollback

XFS **non si puo' ridurre**. Non esiste un rollback dell'estensione: se lo spazio
non serve piu' resta allocato. Per questo si estende a piccoli passi e solo quando
necessario.

## Errori comuni

| Sintomo | Causa | Soluzione |
| --- | --- | --- |
| `pvcreate: command not found` | Pacchetto lvm2 assente (Guest Image minima) | `sudo dnf -y install lvm2` |
| `Insufficient free space` | VFree insufficiente | Punto 2, poi ripeti il punto 3 |
| `df` mostra la vecchia dimensione | Dimenticato `-r` | `sudo xfs_growfs /pgdata` |
| Al riavvio `/pgdata` non e' montato | Riga errata in `/etc/fstab` | Console Proxmox, correggi la riga, `sudo mount -a` |
