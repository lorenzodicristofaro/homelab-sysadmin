# Rete del laboratorio

Tutte le VM del lab stanno sulla LAN di casa 192.168.1.0/24, collegate al bridge
`vmbr0` dell'host Proxmox, con indirizzi statici assegnati da cloud-init tramite
Terraform.

## Parametri generali

| Parametro            | Valore                                   |
| -------------------- | ---------------------------------------- |
| Rete                 | 192.168.1.0/24                           |
| Gateway              | 192.168.1.1 (router di casa)             |
| DNS                  | 1.1.1.1, 9.9.9.9                         |
| Bridge Proxmox       | `vmbr0` su `nic0`, senza VLAN            |
| Host Proxmox         | `pve` - 192.168.1.10 (interfaccia web :8006) |
| DHCP del router      | 192.168.1.20 - 192.168.1.199             |
| IP statici del lab   | 192.168.1.200 - 192.168.1.249            |
| IP per test usa e getta | 192.168.1.249 (VMID 999)              |

## Piano di indirizzamento

| VM          | VMID | IP            | Template   | RAM   | Profilo   | Ruolo                              |
| ----------- | ---- | ------------- | ---------- | ----- | --------- | ---------------------------------- |
| rhel-mgmt01 | 200  | 192.168.1.200 | 9001 RHEL  | 2 GB  | common    | Jump host, Ansible, script, kubectl|
| rhel-web01  | 201  | 192.168.1.201 | 9001 RHEL  | 2 GB  | common    | Apache                             |
| rhel-db01   | 202  | 192.168.1.202 | 9001 RHEL  | 2 GB  | common    | PostgreSQL                         |
| mon01       | 205  | 192.168.1.205 | 9000 Rocky | 2 GB  | common    | Prometheus, Grafana                |
| elk01       | 206  | 192.168.1.206 | 9000 Rocky | 4 GB  | profile-a | Elasticsearch, Kibana              |
| k3s-cp01    | 210  | 192.168.1.210 | 9000 Rocky | 2 GB  | profile-a | k3s control plane                  |
| k3s-w01     | 211  | 192.168.1.211 | 9000 Rocky | 2 GB  | profile-a | k3s worker                         |
| k3s-w02     | 212  | 192.168.1.212 | 9000 Rocky | 2 GB  | profile-a | k3s worker                         |
| crc01       | 220  | 192.168.1.220 | 9001 RHEL  | 16 GB | profile-b | OpenShift Local                    |

### Convenzioni

- **VMID = ultimo ottetto dell'IP**: dal numero della VM si ricava l'indirizzo e viceversa.
- **Blocchi per funzione**: 200-204 server RHEL, 205-209 monitoraggio e log,
  210-219 Kubernetes, 220-229 OpenShift. Una VM nuova prende il primo numero libero
  del suo blocco.
- **Template**: 9000 Rocky 9, 9001 RHEL 9.
- **Nomi**: `<ruolo><numero a due cifre>`, con prefisso `rhel-` per le VM RHEL.

## Porte e flussi consentiti

| Servizio                 | Porta     | Su                 | Consentito da          |
| ------------------------ | --------- | ------------------ | ---------------------- |
| SSH                      | 22/tcp    | tutte le VM        | PC, rhel-mgmt01        |
| HTTP                     | 80/tcp    | rhel-web01         | LAN                    |
| PostgreSQL               | 5432/tcp  | rhel-db01          | solo rhel-web01        |
| node_exporter            | 9100/tcp  | tutte le VM        | solo mon01             |
| Prometheus               | 9090/tcp  | mon01              | LAN                    |
| Grafana                  | 3000/tcp  | mon01              | LAN                    |
| Elasticsearch            | 9200/tcp  | elk01              | VM del lab (Filebeat)  |
| Kibana                   | 5601/tcp  | elk01              | LAN                    |
| API Kubernetes           | 6443/tcp  | k3s-cp01           | nodi k3s, rhel-mgmt01  |
| Interfaccia Proxmox      | 8006/tcp  | pve                | PC                     |

Le regole sono applicate con firewalld su ogni VM tramite Ansible. Eccezione: sui
nodi k3s firewalld e' disattivato, come indicato dalla documentazione k3s per le
distribuzioni della famiglia RHEL.

## Scelte e limiti

- **Nessuna VLAN**: il router di casa non gestisce 802.1Q. Una rete separata
  richiederebbe un router virtuale o l'SDN di Proxmox, senza benefici per gli
  obiettivi del progetto.
- **IP statici fuori dal DHCP**: inventario Ansible, target di Prometheus e CMDB
  dipendono da indirizzi che non devono cambiare.
- **Nessun servizio esposto su Internet**: nessun port forwarding sul router.

## Storico

| Data       | Modifica                                                              |
| ---------- | --------------------------------------------------------------------- |
| 2026-11-16 | Dismesse le VM 100-106 del progetto precedente (IP .50-.56 liberati). Definito il piano attuale. |
