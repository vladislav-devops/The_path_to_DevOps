# 🔧 VM5 - Переменные для идеального Terraform проекта
# Все параметры виртуальной машины настраиваются через переменные

# ====================
# PROXMOX ПАРАМЕТРЫ  
# ====================

variable "proxmox_endpoint" {
  description = "URL Proxmox API endpoint"
  type        = string
  default     = "https://192.168.123.41:8006/"
}

variable "proxmox_username" {
  description = "Proxmox пользователь"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Пароль Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Имя Proxmox узла"
  type        = string
  default     = "pve01"
}

variable "proxmox_datastore" {
  description = "Proxmox datastore для хранения"
  type        = string
  default     = "local"
}

# ====================
# VM ОСНОВНЫЕ ПАРАМЕТРЫ
# ====================

variable "vm_name" {
  description = "Имя виртуальной машины"
  type        = string
  default     = "vm5-server"
}

variable "vm_id" {
  description = "ID виртуальной машины"
  type        = number
  default     = 750
}

variable "vm_description" {
  description = "Описание виртуальной машины"
  type        = string
  default     = "🚀 VM5 Enhanced Server - Production Ready"
}

variable "vm_tags" {
  description = "Теги для виртуальной машины"
  type        = list(string)
  default     = ["terraform", "vm5", "production", "enhanced"]
}

# ====================
# VM РЕСУРСЫ
# ====================

variable "vm_cores" {
  description = "Количество CPU cores"
  type        = number
  default     = 2
  
  validation {
    condition     = var.vm_cores >= 1 && var.vm_cores <= 8
    error_message = "VM cores должны быть от 1 до 8."
  }
}

variable "vm_memory_mb" {
  description = "Объем памяти в MB"
  type        = number
  default     = 4096
  
  validation {
    condition     = var.vm_memory_mb >= 1024 && var.vm_memory_mb <= 16384
    error_message = "Память должна быть от 1024 до 16384 MB."
  }
}

variable "vm_disk_size_gb" {
  description = "Размер диска в GB"
  type        = number
  default     = 50
  
  validation {
    condition     = var.vm_disk_size_gb >= 10 && var.vm_disk_size_gb <= 500
    error_message = "Размер диска должен быть от 10 до 500 GB."
  }
}

# ====================
# СЕТЕВЫЕ НАСТРОЙКИ
# ====================

variable "vm_ip" {
  description = "IP адрес виртуальной машины"
  type        = string
  default     = "192.168.123.150"
  
  validation {
    condition     = can(cidrhost("${var.vm_ip}/24", 0))
    error_message = "VM IP должен быть валидным IPv4 адресом."
  }
}

variable "vm_gateway" {
  description = "Gateway для виртуальной машины"
  type        = string
  default     = "192.168.123.1"
}

variable "vm_netmask" {
  description = "Сетевая маска"
  type        = string
  default     = "24"
}

variable "vm_dns_servers" {
  description = "DNS серверы"
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

variable "vm_network_bridge" {
  description = "Network bridge для VM"
  type        = string
  default     = "vmbr0"
}

# ====================
# ПОЛЬЗОВАТЕЛЬ VM
# ====================

variable "vm_username" {
  description = "Основной пользователь VM"
  type        = string
  default     = "devops"
  
  validation {
    condition     = length(var.vm_username) >= 3
    error_message = "Имя пользователя должно быть минимум 3 символа."
  }
}

variable "vm_user_password" {
  description = "Пароль пользователя VM"
  type        = string
  sensitive   = true
  default     = "vm5secure2024"
}

variable "ssh_public_key" {
  description = "SSH публичный ключ для авторизации"
  type        = string
}

variable "ssh_password_auth" {
  description = "Разрешить SSH аутентификацию по паролю"
  type        = bool
  default     = true
}

# ====================
# CLOUD IMAGE
# ====================

variable "ubuntu_cloud_image_url" {
  description = "URL Ubuntu cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "ubuntu_cloud_image_name" {
  description = "Имя файла Ubuntu cloud image"
  type        = string
  default     = "ubuntu-22.04-cloud-vm5.img"
}

# ====================
# ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
# ====================

variable "vm_auto_start" {
  description = "Автозапуск VM при старте Proxmox"
  type        = bool
  default     = true
}

variable "qemu_agent_enabled" {
  description = "Включить QEMU guest agent"
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "Включить установку monitoring stack"
  type        = bool
  default     = true
}

variable "docker_enabled" {
  description = "Включить установку Docker"
  type        = bool
  default     = true
}

# ====================
# CLOUD-INIT НАСТРОЙКИ
# ====================

variable "cloud_init_file_name" {
  description = "Имя cloud-init конфигурационного файла"
  type        = string
  default     = "vm5-server-cloud-init.yaml"
}

variable "setup_firewall" {
  description = "Настроить firewall (UFW)"
  type        = bool
  default     = true
}

variable "install_packages" {
  description = "Дополнительные пакеты для установки"
  type        = list(string)
  default     = [
    "curl", "wget", "git", "vim", "htop", 
    "net-tools", "unzip", "tree", "nano"
  ]
}