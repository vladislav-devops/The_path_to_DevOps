# 🚀 VM5 - Идеальная Terraform конфигурация с переменными
# Полностью параметризованное решение без хардкода

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ====================
# PROVIDER НАСТРОЙКА
# ====================

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}

# ====================
# UBUNTU CLOUD IMAGE
# ====================

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type        = "iso"
  datastore_id        = var.proxmox_datastore
  node_name           = var.proxmox_node
  url                 = var.ubuntu_cloud_image_url
  file_name           = var.ubuntu_cloud_image_name
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 300
  verify              = true
}

# ====================
# CLOUD-INIT КОНФИГУРАЦИЯ
# ====================

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore
  node_name    = var.proxmox_node
  overwrite    = true

  source_raw {
    data = templatefile("${path.root}/cloud-init.tftpl", {
      # VM параметры
      hostname          = var.vm_name
      username          = var.vm_username
      password          = var.vm_user_password
      ssh_public_key    = var.ssh_public_key
      ssh_password_auth = var.ssh_password_auth
      
      # Сетевые параметры
      vm_ip_address     = var.vm_ip
      vm_gateway        = var.vm_gateway
      vm_netmask        = var.vm_netmask
      vm_dns_servers    = var.vm_dns_servers
      
      # Функциональность
      monitoring_enabled = var.monitoring_enabled
      docker_enabled     = var.docker_enabled
      setup_firewall     = var.setup_firewall
      qemu_agent_enabled = var.qemu_agent_enabled
      install_packages   = var.install_packages
    })
    file_name = var.cloud_init_file_name
  }
}

# ====================
# ВИРТУАЛЬНАЯ МАШИНА
# ====================

resource "proxmox_virtual_environment_vm" "vm5_server" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  # Автозапуск
  on_boot = var.vm_auto_start
  started = true

  # Операционная система
  operating_system {
    type = "l26"
  }

  # CPU конфигурация
  cpu {
    cores = var.vm_cores
    type  = "qemu64"
  }

  # Память
  memory {
    dedicated = var.vm_memory_mb
  }

  # BIOS и прочие настройки
  bios            = "seabios"
  scsi_hardware   = "virtio-scsi-pci"
  keyboard_layout = "en-us"

  # QEMU Agent
  agent {
    enabled = var.qemu_agent_enabled
    timeout = "5m"
  }

  # Сетевой интерфейс
  network_device {
    bridge  = var.vm_network_bridge
    model   = "virtio"
    enabled = true
  }

  # Диск
  disk {
    datastore_id = var.proxmox_datastore
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.vm_disk_size_gb
    file_format  = "qcow2"
  }

  # Cloud-init инициализация
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    datastore_id      = var.proxmox_datastore

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_netmask}"
        gateway = var.vm_gateway
      }
    }
  }

  # Таймауты
  timeout_create      = 600
  timeout_start_vm    = 600
  timeout_shutdown_vm = 300
  timeout_reboot      = 300

  depends_on = [
    proxmox_virtual_environment_download_file.ubuntu_cloud_image,
    proxmox_virtual_environment_file.cloud_config
  ]
}

# ====================
# SSH ТЕСТИРОВАНИЕ
# ====================

resource "null_resource" "ssh_test" {
  depends_on = [proxmox_virtual_environment_vm.vm5_server]

  # Триггеры для пересоздания тестов
  triggers = {
    vm_id      = proxmox_virtual_environment_vm.vm5_server.id
    ip_address = var.vm_ip
    vm_name    = var.vm_name
  }

  # Ожидание доступности VM
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔄 Ожидание готовности ${var.vm_name}..."
      sleep 30
      
      echo "🏓 Проверка доступности ${var.vm_ip} по сети..."
      timeout 60 bash -c 'until ping -c1 ${var.vm_ip} &>/dev/null; do sleep 2; done'
      
      echo "🔐 Проверка SSH порта ${var.vm_ip}:22..."
      timeout 60 bash -c 'until timeout 1 bash -c "echo >/dev/tcp/${var.vm_ip}/22"; do sleep 5; done' 2>/dev/null
      
      echo "✅ ${var.vm_name} готова к использованию!"
      echo "🔗 SSH: ssh ${var.vm_username}@${var.vm_ip}"
    EOT
  }
}

# ====================
# ЛОКАЛЬНЫЕ ЗНАЧЕНИЯ
# ====================

locals {
  vm_info = {
    name        = var.vm_name
    ip_address  = var.vm_ip
    username    = var.vm_username
    ssh_command = "ssh ${var.vm_username}@${var.vm_ip}"
    vm_id       = var.vm_id
  }
  
  monitoring_urls = var.monitoring_enabled ? {
    grafana    = "http://${var.vm_ip}:3000"
    prometheus = "http://${var.vm_ip}:9090"
  } : {}
}