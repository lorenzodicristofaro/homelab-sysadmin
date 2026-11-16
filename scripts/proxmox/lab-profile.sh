#!/usr/bin/env bash
# lab-profile.sh - accende un profilo del lab Proxmox e spegne l'altro.
#
# Le VM vengono scelte in base ai tag Proxmox:
#   common     -> sempre accese con il profilo A e con il profilo B
#   profile-a  -> solo nel profilo A (es. elk01, nodi k3s)
#   profile-b  -> solo nel profilo B (es. crc01 OpenShift Local)
#
# Uso:  lab-profile.sh a | b | off | status
# Da eseguire come root sull'host Proxmox. Richiede jq (apt install jq).

set -euo pipefail

SHUTDOWN_TIMEOUT=180   # secondi concessi a ogni VM per spegnersi da sola
MIN_FREE_MB=2048       # RAM da lasciare libera all'host dopo l'avvio
LOG_TAG="lab-profile"

log() { echo "$(date '+%F %T') $*"; logger -t "$LOG_TAG" "$*"; }
die() { log "ERRORE: $*"; exit 1; }

usage() {
  echo "Uso: $0 a|b|off|status" >&2
  echo "  a       spegne profile-b, accende common + profile-a" >&2
  echo "  b       spegne profile-a, accende common + profile-b" >&2
  echo "  off     spegne profile-a, profile-b e common" >&2
  echo "  status  mostra VM, stato, RAM e tag" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
[[ $EUID -eq 0 ]] || die "eseguire come root"
command -v jq >/dev/null || die "jq non installato: apt install jq"

# Elenco JSON delle VM (template esclusi) del cluster/nodo
vm_json() {
  pvesh get /cluster/resources --type vm --output-format json |
    jq '[.[] | select(.type == "qemu" and (.template // 0) != 1)]'
}

# VMID che hanno il tag indicato (i tag Proxmox sono separati da ';')
vms_with_tag() {
  vm_json | jq -r --arg t "$1" \
    '.[] | select((.tags // "") | split(";") | index($t)) | .vmid' | sort -n
}

vm_status() { qm status "$1" | awk '{print $2}'; }

show_status() {
  vm_json | jq -r '.[] | [.vmid, .name, .status,
      ((.maxmem // 0) / 1048576 | floor), (.tags // "-")] | @tsv' |
    sort -n | column -t -s $'\t' -N VMID,NOME,STATO,RAM_MB,TAG
  free -m | awk '/^Mem:/ {printf "\nRAM host: usata %s MB, disponibile %s MB\n", $3, $7}'
}

# Spegne in parallelo le VM accese tra quelle passate
stop_vms() {
  local id pids=()
  for id in "$@"; do
    [[ $(vm_status "$id") == running ]] || continue
    log "Spengo VM $id"
    qm shutdown "$id" --timeout "$SHUTDOWN_TIMEOUT" --forceStop 1 &
    pids+=("$!")
  done
  local rc=0
  for pid in "${pids[@]}"; do wait "$pid" || rc=1; done
  (( rc == 0 )) || die "una o piu' VM non si sono spente"
}

# Controlla che ci sia RAM sufficiente per le VM da accendere
check_memory() {
  local id mem needed=0 avail
  for id in "$@"; do
    [[ $(vm_status "$id") == running ]] && continue
    mem=$(qm config "$id" | awk '/^memory:/ {print $2}')
    needed=$(( needed + ${mem:-0} ))
  done
  avail=$(free -m | awk '/^Mem:/ {print $7}')
  log "RAM richiesta ${needed} MB, disponibile ${avail} MB"
  (( needed + MIN_FREE_MB <= avail )) ||
    die "RAM insufficiente: servono ${needed} MB + ${MIN_FREE_MB} MB di margine"
}

start_vms() {
  local id
  for id in "$@"; do
    if [[ $(vm_status "$id") == running ]]; then
      log "VM $id gia' accesa"
      continue
    fi
    log "Avvio VM $id"
    qm start "$id"
    sleep 5   # evita picchi di I/O avviando tutto insieme
  done
}

mapfile -t COMMON < <(vms_with_tag common)
mapfile -t PROF_A < <(vms_with_tag profile-a)
mapfile -t PROF_B < <(vms_with_tag profile-b)

case "$1" in
  a)
    stop_vms "${PROF_B[@]}"
    check_memory "${COMMON[@]}" "${PROF_A[@]}"
    start_vms "${COMMON[@]}" "${PROF_A[@]}"
    ;;
  b)
    stop_vms "${PROF_A[@]}"
    check_memory "${COMMON[@]}" "${PROF_B[@]}"
    start_vms "${COMMON[@]}" "${PROF_B[@]}"
    ;;
  off)
    stop_vms "${PROF_A[@]}" "${PROF_B[@]}" "${COMMON[@]}"
    ;;
  status)
    show_status
    exit 0
    ;;
  *)
    usage
    ;;
esac

log "Profilo '$1' applicato"
show_status
