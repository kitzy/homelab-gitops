resource "proxmox_virtual_environment_vm" "k3s_control_1" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = []
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = []
  machine                              = null
  migrate                              = false
  name                                 = "k3s-control-1"
  network_device = [{
    bridge       = "vmbr1"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:83:8A:1E"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "pve1"
  on_boot             = false
  pool_id             = null
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 101

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 4
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "host"
    # units omitted: PVE stores 0 (unset) but the provider validator rejects 0
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "nvme-pool"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-101-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 499
    ssd               = false
  }

  initialization {
    datastore_id         = "nvme-pool"
    file_format          = null
    interface            = "ide2"
    meta_data_file_id    = null
    network_data_file_id = null
    type                 = null
    upgrade              = true
    user_data_file_id    = null
    vendor_data_file_id  = null
    dns {
      domain  = null
      servers = ["10.253.20.1"]
    }
    ip_config {
      ipv4 {
        address = "10.253.20.50/24"
        gateway = "10.253.20.1"
      }
    }
    user_account {
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIyjdeB89LoXWbhY+JS+eVwaoGoAfS684wVRsax7mZV kitzy@kitzy.com"]
      password = null
      username = "kitzy"
    }
  }

  memory {
    dedicated      = 8192
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  serial_device {
    device = "socket"
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_control_2" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = []
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = []
  machine                              = null
  migrate                              = false
  name                                 = "k3s-control-2"
  network_device = [{
    bridge       = "vmbr1"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:D2:43:18"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "pve1"
  on_boot             = false
  pool_id             = null
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 102

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 4
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "host"
    # units omitted: PVE stores 0 (unset) but the provider validator rejects 0
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "nvme-pool"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 499
    ssd               = false
  }

  initialization {
    datastore_id         = "nvme-pool"
    file_format          = null
    interface            = "ide2"
    meta_data_file_id    = null
    network_data_file_id = null
    type                 = null
    upgrade              = true
    user_data_file_id    = null
    vendor_data_file_id  = null
    dns {
      domain  = null
      servers = ["10.253.20.1"]
    }
    ip_config {
      ipv4 {
        address = "10.253.20.51/24"
        gateway = "10.253.20.1"
      }
    }
    user_account {
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIyjdeB89LoXWbhY+JS+eVwaoGoAfS684wVRsax7mZV kitzy@kitzy.com"]
      password = null
      username = "kitzy"
    }
  }

  memory {
    dedicated      = 8192
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  serial_device {
    device = "socket"
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_control_3" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = []
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = []
  machine                              = null
  migrate                              = false
  name                                 = "k3s-control-3"
  network_device = [{
    bridge       = "vmbr1"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:DB:3F:B4"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "pve2"
  on_boot             = false
  pool_id             = null
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 103

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 4
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "host"
    # units omitted: PVE stores 0 (unset) but the provider validator rejects 0
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "nvme-pool"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-103-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 499
    ssd               = false
  }

  initialization {
    datastore_id         = "nvme-pool"
    file_format          = null
    interface            = "ide2"
    meta_data_file_id    = null
    network_data_file_id = null
    type                 = null
    upgrade              = true
    user_data_file_id    = null
    vendor_data_file_id  = null
    dns {
      domain  = null
      servers = ["10.253.20.1"]
    }
    ip_config {
      ipv4 {
        address = "10.253.20.52/24"
        gateway = "10.253.20.1"
      }
    }
    user_account {
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIyjdeB89LoXWbhY+JS+eVwaoGoAfS684wVRsax7mZV kitzy@kitzy.com"]
      password = null
      username = "kitzy"
    }
  }

  memory {
    dedicated      = 8192
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  serial_device {
    device = "socket"
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_worker_1" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = []
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = []
  machine                              = null
  migrate                              = false
  name                                 = "k3s-worker-1"
  network_device = [{
    bridge       = "vmbr1"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:BC:62:DA"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "pve1"
  on_boot             = false
  pool_id             = null
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 111

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 8
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "host"
    # units omitted: PVE stores 0 (unset) but the provider validator rejects 0
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "nvme-pool"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-111-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 997
    ssd               = false
  }

  initialization {
    datastore_id         = "nvme-pool"
    file_format          = null
    interface            = "ide2"
    meta_data_file_id    = null
    network_data_file_id = null
    type                 = null
    upgrade              = true
    user_data_file_id    = null
    vendor_data_file_id  = null
    dns {
      domain  = null
      servers = ["10.253.20.1"]
    }
    ip_config {
      ipv4 {
        address = "10.253.20.60/24"
        gateway = "10.253.20.1"
      }
    }
    user_account {
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIyjdeB89LoXWbhY+JS+eVwaoGoAfS684wVRsax7mZV kitzy@kitzy.com"]
      password = null
      username = "kitzy"
    }
  }

  memory {
    dedicated      = 32768
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  serial_device {
    device = "socket"
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_worker_2" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = []
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = []
  machine                              = null
  migrate                              = false
  name                                 = "k3s-worker-2"
  network_device = [{
    bridge       = "vmbr1"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:23:62:B9"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "pve2"
  on_boot             = false
  pool_id             = null
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 112

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 8
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "host"
    # units omitted: PVE stores 0 (unset) but the provider validator rejects 0
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "nvme-pool"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-112-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 997
    ssd               = false
  }

  initialization {
    datastore_id         = "nvme-pool"
    file_format          = null
    interface            = "ide2"
    meta_data_file_id    = null
    network_data_file_id = null
    type                 = null
    upgrade              = true
    user_data_file_id    = null
    vendor_data_file_id  = null
    dns {
      domain  = null
      servers = ["10.253.20.1"]
    }
    ip_config {
      ipv4 {
        address = "10.253.20.61/24"
        gateway = "10.253.20.1"
      }
    }
    user_account {
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIyjdeB89LoXWbhY+JS+eVwaoGoAfS684wVRsax7mZV kitzy@kitzy.com"]
      password = null
      username = "kitzy"
    }
  }

  memory {
    dedicated      = 32768
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  serial_device {
    device = "socket"
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}
