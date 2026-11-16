# Convenzioni ServiceNow del laboratorio

Istanza: Personal Developer Instance (URL nel file locale servicenow.env,
non nel repository). Va in ibernazione dopo alcune ore di inattivita'.

## Utenti e gruppi

| Utente / gruppo | Ruoli | Uso |
| --- | --- | --- |
| admin | admin | Configurazione dell'istanza, approvazioni |
| svc_homelab | itil | Solo API: script e alert aprono e aggiornano incident |
| Homelab Ops | itil | Assignment group di tutti i ticket |

## Priorita' degli incident (impatto x urgenza)

|              | Urgenza 1 - Alta | Urgenza 2 - Media | Urgenza 3 - Bassa |
| ------------ | ---------------- | ----------------- | ----------------- |
| Impatto 1    | P1 Critical      | P2 High           | P3 Moderate       |
| Impatto 2    | P2 High          | P3 Moderate       | P4 Low            |
| Impatto 3    | P3 Moderate      | P4 Low            | P5 Planning       |

Impatto nel lab:
- 1 = piu' servizi fermi (host Proxmox, rete, cluster intero)
- 2 = un servizio fermo (rhel-web01 non risponde, Grafana giu')
- 3 = componente ridondato o non critico (un worker k3s, un exporter)

Urgenza:
- 1 = peggiora da solo o blocca il lavoro adesso (disco al 95% e in crescita)
- 2 = degradato ma stabile
- 3 = puo' aspettare la prossima finestra di manutenzione

## Ciclo di vita dell'incident

New -> In Progress -> (On Hold) -> Resolved -> Closed

- Presa in carico: stato In Progress, Assigned to compilato.
- Work notes: ogni comando di diagnosi rilevante e il suo esito (note interne).
- Additional comments: solo comunicazioni per chi ha aperto il ticket.
- Resolved: Resolution code e Resolution notes obbligatori (causa + azione).
- Ogni incident P1/P2 o ripetuto due volte genera un Problem e un post-mortem
  in docs/postmortem/.

## Categorie

| Category | Esempi nel lab |
| --- | --- |
| Hardware | Host Proxmox, dischi, RAM |
| Software | Servizi systemd, pod, Elasticsearch |
| Network | firewalld, DNS, raggiungibilita' |
| Database | PostgreSQL su rhel-db01 |

## Tipi di Change

| Tipo | Quando | Esempi |
| --- | --- | --- |
| Standard | Attivita' ripetitiva, rischio basso, pre-approvata | Patching mensile, riavvio di una VM, cambio profilo |
| Normal | Modifica nuova o con rischio | Nuova VM, nuovo servizio, modifiche a rete o storage |
| Emergency | Ripristino urgente di un servizio | Rollback dopo un aggiornamento fallito |

## Formato dei ticket

- Short description: `[homelab] <host o componente>: <sintomo>`
  es. `[homelab] rhel-web01: HTTP 403 sulla DocumentRoot`
- Ticket aperti dagli script: stesso formato, categoria Software, gruppo Homelab Ops.

## Collegamento con Git

I commit che risolvono un ticket ne citano il numero:
`fix(rhel): contesto SELinux per /srv/www (INC0010004)`

## Registro

| Data | Ticket | Descrizione |
| --- | --- | --- |
| 2026-11-16 | CHG00300i01 | Pulizia host Proxmox e infrastruttura base |
