# Runbook: HTTP 403 o servizio bloccato da SELinux

| Voce | Valore |
| --- | --- |
| Sistemi | VM RHEL 9 con SELinux in Enforcing |
| Quando usarlo | Un servizio riceve "Permission denied" su file o porte, ma i permessi classici sono corretti |
| Impatto | Nessun fermo per la correzione; il servizio e' gia' degradato |
| Durata | 10-20 minuti |
| Riferimenti | INC00100xx (403 su /srv/www), PRB00400xx |

Regola: **SELinux resta in Enforcing**. `setenforce 0` si usa solo per un istante,
per confermare la diagnosi, e si ripristina subito con `setenforce 1`.

## 1. Conferma che il problema e' di SELinux

Controlla i tre livelli in ordine: servizio, SELinux, firewall.

```bash
sudo tail -n 20 /var/log/httpd/error_log        # oppure: journalctl -u <servizio> -n 20
ls -l <percorso>                                  # permessi classici
getenforce                                        # Enforcing
sudo ausearch -m avc -ts recent                   # blocchi SELinux recenti
```

Una riga `avc: denied` che cita il processo del servizio conferma la causa.

## 2. Leggi il blocco

```
avc: denied { getattr } for comm="httpd" path="/srv/www/index.html"
     scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:var_t:s0
```

| Campo | Significato |
| --- | --- |
| `{ getattr }`, `{ read }`, `{ name_bind }` | Operazione negata (`name_bind` = mettersi in ascolto su una porta) |
| `comm` | Programma bloccato |
| `scontext` | Etichetta del processo (soggetto) |
| `tcontext` | Etichetta del file o della porta (oggetto) |

Per una spiegazione e una soluzione suggerita:

```bash
sudo sealert -a /var/log/audit/audit.log | head -n 40   # pacchetto setroubleshoot-server
```

## 3a. Caso file: contesto errato su un percorso

```bash
ls -ldZ /var/www/html <percorso>                  # confronta le etichette
sudo semanage fcontext -a -t httpd_sys_content_t "<percorso>(/.*)?"
sudo restorecon -Rv <percorso>
```

Tipi piu' comuni:

| Contenuto | Tipo |
| --- | --- |
| Pagine web in sola lettura | `httpd_sys_content_t` |
| Dati di PostgreSQL | `postgresql_db_t` |
| Cartella `.ssh` degli utenti | `ssh_home_t` |

Non usare `chcon`: la modifica si perde al primo relabel del filesystem.

## 3b. Caso porta: servizio su una porta non standard

```bash
sudo semanage port -l | grep -w <porta>           # nessun output = porta senza etichetta
sudo semanage port -a -t http_port_t -p tcp <porta>
# se risponde "already defined": usa -m al posto di -a
```

## 4. Verifica

```bash
sudo systemctl restart <servizio>                 # solo nel caso porta
curl -I http://localhost[:porta]                  # 200 OK
sudo ausearch -m avc -ts recent                   # nessun nuovo blocco
sudo semanage fcontext -l -C                      # regole locali registrate
sudo semanage port -l -C
```

## 5. Rollback

```bash
sudo semanage fcontext -d "<percorso>(/.*)?" && sudo restorecon -Rv <percorso>
sudo semanage port -d -t http_port_t -p tcp <porta>
```

## Errori comuni

| Sintomo | Causa | Soluzione |
| --- | --- | --- |
| `semanage: command not found` | Pacchetto assente | `sudo dnf -y install policycoreutils-python-utils` |
| `sealert: command not found` | Pacchetto assente | `sudo dnf -y install setroubleshoot-server` |
| 403 senza righe `avc` | Causa nella configurazione di Apache | Controlla il blocco `<Directory>` con `Require all granted` |
| Funziona con `setenforce 0` ma `restorecon` non cambia nulla | Regola `fcontext` mancante o con percorso errato | `semanage fcontext -l -C`, correggi l'espressione |
