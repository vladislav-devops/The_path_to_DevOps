# 📊 Outputs для VM4

output "vm4_info" {
  description = "Информация о VM4 сервере"
  value = {
    name        = proxmox_virtual_environment_vm.vm4_server.name
    ip_address  = "192.168.123.140"
    vm_id       = proxmox_virtual_environment_vm.vm4_server.vm_id
    ssh_command = "ssh devops@192.168.123.140"
    status      = "deployed"
    created_at  = timestamp()
  }
}

output "vm4_ssh_command" {
  description = "SSH команда для подключения к VM4"
  value       = "ssh devops@192.168.123.140"
}

output "vm4_config" {
  description = "Конфигурация VM4"
  value = {
    cores          = 2
    memory_mb      = 4096
    disk_size_gb   = 50
    network_bridge = "vmbr0"
    os_image       = "ubuntu-22.04-cloud-vm4.img"
    packages_count = 10
  }
}

output "vm4_testing" {
  description = "Информация о тестировании VM4"
  value = {
    ssh_test_enabled = true
    auto_validation  = true
    test_script      = "./test-ssh.sh"
    makefile_cmds    = ["make test-ssh", "make deploy-and-test"]
  }
}

output "vm4_commands" {
  description = "Полезные команды для работы с VM4"
  value = {
    connect_ssh      = "ssh devops@192.168.123.140"
    test_connection  = "./test-ssh.sh"
    deploy_and_test  = "make deploy-and-test"
    recreate_vm      = "make recreate"
    quick_deploy     = "make quick-deploy"
  }
}