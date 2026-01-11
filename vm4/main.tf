# 🚀 VM4 - Упрощенная конфигурация для одной VM
# Берем лучшие практики из vm3 но делаем простую монолитную конфигурацию

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.123.41:8006/"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}

# Variables
variable "proxmox_password" {
  description = "Пароль Proxmox"
  type        = string
  sensitive   = true
}

variable "vm_user_password" {
  description = "Пароль пользователя VM"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH публичный ключ"
  type        = string
}

# Ubuntu Cloud Image - с уникальным именем для vm4
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = "pve01"
  url                 = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name           = "ubuntu-22.04-cloud-vm4.img"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 300
  verify              = true
}

# Cloud-init конфигурация
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve01"
  overwrite    = true

  source_raw {
    data = templatefile("${path.root}/cloud-init.tftpl", {
      hostname          = "vm4-server"
      username          = "devops"
      password          = var.vm_user_password
      ssh_public_key    = var.ssh_public_key
      ssh_password_auth = true
      vm_ip_address     = "192.168.123.140"
      vm_gateway        = "192.168.123.1"
    })
    file_name = "vm4-server-cloud-init.yaml"
  }
}

# Виртуальная машина
resource "proxmox_virtual_environment_vm" "vm4_server" {
  name        = "vm4-server"
  description = "🚀 VM4 Production Server"
  tags        = ["terraform", "vm4", "production"]
  node_name   = "pve01"
  vm_id       = 740

  # Автозапуск
  on_boot = true
  started = true

  # Операционная система
  operating_system {
    type = "l26"
  }

  # CPU
  cpu {
    cores = 2
    type  = "qemu64"
  }

  # Память
  memory {
    dedicated = 4096
  }

  # BIOS и прочие настройки
  bios            = "seabios"
  scsi_hardware   = "virtio-scsi-pci"
  keyboard_layout = "en-us"

  # QEMU Agent
  agent {
    enabled = true
    timeout = "5m"
  }

  # Сетевой интерфейс
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    enabled = true
  }

  # Диск
  disk {
    datastore_id = "local"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 50
    file_format  = "qcow2"
  }

  # Cloud-init
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    datastore_id      = "local"

    ip_config {
      ipv4 {
        address = "192.168.123.140/24"
        gateway = "192.168.123.1"
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

# SSH тестирование после развертывания
resource "null_resource" "ssh_test" {
  depends_on = [proxmox_virtual_environment_vm.vm4_server]

  # Триггеры для пересоздания тестов
  triggers = {
    vm_id = proxmox_virtual_environment_vm.vm4_server.id
    ip_address = "192.168.123.140"
  }

  # Ожидание доступности VM
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔄 Ожидание готовности VM..."
      sleep 30

      echo "🏓 Проверка доступности по сети..."
      timeout 60 bash -c 'until ping -c1 192.168.123.140 &>/dev/null; do sleep 2; done'

      echo "🔐 Проверка SSH порта..."
      timeout 60 bash -c 'until timeout 1 bash -c "echo >/dev/tcp/192.168.123.140/22"; do sleep 5; done' 2>/dev/null

      echo "✅ VM4 готова к использованию!"
    EOT
  }
}