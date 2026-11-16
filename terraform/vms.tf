locals {
  vms = {
    rhel-mgmt01 = { id = 200, ip = "192.168.1.200", tpl = 9001, cores = 2, mem = 2048, disk = 20, tags = ["common", "lab", "rhel9"] }
    rhel-web01  = { id = 201, ip = "192.168.1.201", tpl = 9001, cores = 2, mem = 2048, disk = 20, tags = ["common", "lab", "rhel9"] }
    rhel-db01   = { id = 202, ip = "192.168.1.202", tpl = 9001, cores = 2, mem = 2048, disk = 20, tags = ["common", "lab", "rhel9"] }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = local.vms
  name      = each.key
  vm_id     = each.value.id
  node_name = "pve"
  tags      = each.value.tags
  on_boot   = false

  clone {
    vm_id = each.value.tpl
  }
  agent {
    enabled = false
  }
  cpu {
    cores = each.value.cores
    type  = "host"
  }
  memory {
    dedicated = each.value.mem
  }
  disk {
    datastore_id = "nvme"
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
    ssd          = true
  }
  initialization {
    datastore_id = "nvme"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.1.1"
      }
    }
    dns {
      servers = ["1.1.1.1", "9.9.9.9"]
    }
    user_account {
      username = "admin"
      keys     = [trimspace(file(pathexpand(var.ssh_pubkey_path)))]
    }
  }
  lifecycle {
    ignore_changes = [started, disk]
  }
}
