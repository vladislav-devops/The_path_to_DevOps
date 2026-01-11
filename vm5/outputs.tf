# 📊 VM5 Outputs - Идеальные outputs с переменными

# ==================
# ОСНОВНАЯ ИНФОРМАЦИЯ
# ==================

output "vm5_info" {
  description = "Основная информация о VM5 сервере"
  value = {
    name        = proxmox_virtual_environment_vm.vm5_server.name
    hostname    = var.vm_name  
    ip_address  = var.vm_ip
    vm_id       = var.vm_id
    username    = var.vm_username
    ssh_command = "ssh ${var.vm_username}@${var.vm_ip}"
    status      = "deployed"
    created_at  = timestamp()
  }
}

# ==================
# БЕЗОПАСНОСТЬ И НАСТРОЙКИ
# ==================

output "vm5_security" {
  description = "Настройки безопасности для автоматизации тестов"
  value = {
    ssh_password_auth = var.ssh_password_auth
    firewall_enabled  = var.setup_firewall
    username         = var.vm_username
    monitoring_ports = var.monitoring_enabled ? ["3000", "9090", "9100"] : []
  }
}

# ==================
# ПОДКЛЮЧЕНИЕ
# ==================

output "vm5_ssh_command" {
  description = "SSH команда для подключения к VM5"
  value       = "ssh ${var.vm_username}@${var.vm_ip}"
}

output "vm5_connection" {
  description = "Полная информация о подключении"
  value = {
    ssh_command    = "ssh ${var.vm_username}@${var.vm_ip}"
    ip_address     = var.vm_ip
    username       = var.vm_username
    port          = 22
    key_auth      = "ssh-key"
    password_auth = var.ssh_password_auth ? "enabled" : "disabled"
  }
}

# ==================
# КОНФИГУРАЦИЯ
# ==================

output "vm5_config" {
  description = "Полная конфигурация VM5"
  value = {
    # Ресурсы
    cores          = var.vm_cores
    memory_mb      = var.vm_memory_mb
    disk_size_gb   = var.vm_disk_size_gb
    
    # Сеть
    network_bridge = var.vm_network_bridge
    ip_address     = var.vm_ip
    gateway        = var.vm_gateway
    netmask        = var.vm_netmask
    dns_servers    = var.vm_dns_servers
    
    # Система
    os_image       = var.ubuntu_cloud_image_name
    hostname       = var.vm_name
    auto_start     = var.vm_auto_start
    
    # Функции
    docker_enabled     = var.docker_enabled
    monitoring_enabled = var.monitoring_enabled
    qemu_agent        = var.qemu_agent_enabled
    firewall_enabled  = var.setup_firewall
  }
}

# ==================
# URLS И СЕРВИСЫ
# ==================

output "vm5_urls" {
  description = "URL-адреса сервисов VM5"
  value = var.monitoring_enabled ? {
    grafana    = "http://${var.vm_ip}:3000"
    prometheus = "http://${var.vm_ip}:9090"
    node_exporter = "http://${var.vm_ip}:9100/metrics"
  } : {}
}

output "vm5_monitoring" {
  description = "Информация о мониторинге"
  value = var.monitoring_enabled ? {
    enabled        = true
    grafana_url    = "http://${var.vm_ip}:3000"
    grafana_admin  = "admin"
    grafana_pass   = "vm5admin123"
    prometheus_url = "http://${var.vm_ip}:9090"
    node_exporter  = "http://${var.vm_ip}:9100"
  } : {
    enabled = false
    message = "Monitoring disabled in variables"
  }
}

# ==================
# КОМАНДЫ УПРАВЛЕНИЯ
# ==================

output "vm5_commands" {
  description = "Полезные команды для работы с VM5"
  value = {
    # Подключение
    connect_ssh      = "ssh ${var.vm_username}@${var.vm_ip}"
    
    # Terraform управление
    deploy_vm        = "terraform apply"
    destroy_vm       = "terraform destroy"
    plan_changes     = "terraform plan"
    
    # Тестирование
    test_connection  = "./test-ssh.sh"
    
    # Makefile команды
    quick_deploy     = "make quick-deploy"
    full_deploy      = "make deploy"
    test_ssh         = "make test-ssh"
    recreate_vm      = "make recreate"
    
    # Проверка статуса
    check_services   = "ssh ${var.vm_username}@${var.vm_ip} 'systemctl status docker qemu-guest-agent'"
  }
}

# ==================
# ТЕСТИРОВАНИЕ
# ==================

output "vm5_testing" {
  description = "Информация о тестировании VM5"
  value = {
    ssh_test_enabled = true
    auto_validation  = true
    connection_test  = "ping -c 3 ${var.vm_ip}"
    ssh_test        = "ssh -o ConnectTimeout=5 ${var.vm_username}@${var.vm_ip} 'echo VM5 ready'"
    docker_test     = var.docker_enabled ? "ssh ${var.vm_username}@${var.vm_ip} 'docker --version'" : "disabled"
    monitoring_test = var.monitoring_enabled ? "curl -s http://${var.vm_ip}:9090/api/v1/status/config" : "disabled"
  }
}


# ==================
# ПОЛНАЯ СВОДКА
# ==================

output "vm5_summary" {
  description = "Полная сводка VM5 развертывания"
  value = {
    "🖥️  VM Info" = {
      name     = var.vm_name
      id       = var.vm_id
      ip       = var.vm_ip
      cores    = var.vm_cores
      memory   = "${var.vm_memory_mb}MB"
      disk     = "${var.vm_disk_size_gb}GB"
    }
    
    "🔗 Connection" = {
      ssh = "ssh ${var.vm_username}@${var.vm_ip}"
    }
    
    "📊 Monitoring" = var.monitoring_enabled ? {
      grafana    = "http://${var.vm_ip}:3000 (admin/vm5admin123)"
      prometheus = "http://${var.vm_ip}:9090"
    } : {
      status = "disabled"
    }
    
    "🐳 Docker" = var.docker_enabled ? "enabled" : "disabled"
    
    "🔥 Firewall" = var.setup_firewall ? "enabled (UFW)" : "disabled"
    
    "⚡ Status" = "ready for use"
  }
}