#!/usr/bin/env bash
set -euo pipefail
IMG=$(ls /var/lib/vz/template/rhel-9.*-kvm.qcow2)
qm create 9001 --name rhel9-template --memory 2048 --cores 2 --cpu host \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26
qm importdisk 9001 "$IMG" nvme
qm set 9001 --scsi0 nvme:vm-9001-disk-0,discard=on,ssd=1 \
  --ide2 nvme:cloudinit --boot order=scsi0 \
  --serial0 socket --vga serial0 --tags "template;rhel9"
qm template 9001
