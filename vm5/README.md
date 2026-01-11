# 🚀 VM5 Enhanced - Production-Ready Virtual Machine with Terraform

[![Terraform](https://img.shields.io/badge/Terraform-%23623CE4.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://terraform.io)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Docker](https://img.shields.io/badge/Docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)

**VM5 Enhanced** — это идеально настроенный Terraform проект для развертывания виртуальных машин на Proxmox с полной параметризацией, встроенным мониторингом и лучшими DevOps практиками.

## 📚 Содержание

- [✨ Особенности](#-особенности)
- [⚠️ Безопасность](#-важно-безопасность)
- [📋 Требования](#-требования)
- [🚀 Быстрый старт](#-быстрый-старт)
- [📖 Детальная конфигурация](#-детальная-конфигурация)
- [📊 Мониторинг](#-мониторинг)
- [🛠️ Управление](#-управление)
- [📤 Outputs](#-outputs)
- [🔧 Customization](#-customization)
- [🚨 Troubleshooting](#-troubleshooting)
- [🔐 Безопасность](#-безопасность)
- [📁 Структура проекта](#-структура-проекта)

## ✨ Особенности

### 🎯 **Полностью Параметризован**
- ❌ **Нет хардкода** — все настройки через переменные
- 📝 **Валидация переменных** с проверкой корректности значений
- 🔧 **Легкая кастомизация** под любые требования

### 🔧 **Production-Ready**
- 🐳 **Docker & Docker Compose** из коробки
- 📊 **Мониторинг Stack** (Prometheus + Grafana + Node Exporter)
- 🔥 **UFW Firewall** с настроенными правилами
- 🔐 **SSH ключи + пароль** аутентификация
- 🤖 **QEMU Guest Agent** для лучшей интеграции

### 🏗️ **DevOps Best Practices**
- 📋 **Structured variables.tf** с documentation
- 📊 **Comprehensive outputs** с полной информацией
- ☁️ **Optimized cloud-init** без дублирований
- 🧪 **Automated testing** и валидация

---

## 📋 Требования

### 💻 **Software Dependencies:**
| Инструмент | Версия | Установка | Назначение |
|------------|--------|-----------|------------|
| **Terraform** | >= 1.5 | [terraform.io](https://terraform.io/downloads) | Infrastructure as Code |
| **Proxmox VE** | >= 7.4 | [Proxmox Downloads](https://proxmox.com/downloads) | Виртуализация |
| **just** | >= 1.0 | `brew install just` | Task runner (рекомендуемый) |
| **make** | >= 3.8 | Встроен в macOS/Linux | Task runner (fallback) |
| **jq** | >= 1.6 | `brew install jq` | JSON обработка |
| **SSH Client** | любая | Встроен | Подключение к VM |

### 🔧 **Optional Tools:**
| Инструмент | Назначение | Установка |
|------------|------------|-----------|
| **sshpass** | SSH с паролем | `brew install sshpass` |
| **nc (netcat)** | Проверка портов | Встроен |
| **curl** | HTTP запросы | Встроен |
| **ping** | Сетевые тесты | Встроен |

### 🌐 **Network Requirements:**
- Доступ к Proxmox API (обычно порт 8006)
- Свободный IP в локальной сети для VM
- Интернет для загрузки пакетов и образов

---

## ⚠️ ВАЖНО: Безопасность

> **🚨 КРИТИЧЕСКИ ВАЖНО:** Пароли `vm5secure2024` и `vm5admin123` предназначены **ТОЛЬКО для DEMO**!
> 
> В реальной среде **ОБЯЗАТЕЛЬНО**:
> - Задайте свои значения в `terraform.tfvars`
> - Смените пароль admin в Grafana при первом входе
> - Рассмотрите отключение `ssh_password_auth = false` для production

---

## 🚀 Быстрый старт

### 1. Клонирование и настройка
```bash
git clone <your-repo>
cd vm5

# Проверка зависимостей
terraform --version  # >= 1.5
jq --version         # >= 1.6

# Установка task runner (выберите один)
brew install just    # Рекомендуемый
# или используйте встроенный make
```

### 2. Настройка переменных
```bash
# Создайте конфигурационный файл из примера
cp terraform.tfvars.example terraform.tfvars

# Отредактируйте terraform.tfvars
vim terraform.tfvars  # или nano, code и т.д.
```

**Минимальная конфигурация:**

```hcl
# Основные параметры VM
vm_name = "my-server"
vm_ip   = "192.168.1.100"

# Ресурсы
vm_cores     = 4
vm_memory_mb = 8192

# Функциональность
monitoring_enabled = true
docker_enabled     = true
```

### 3. Развертывание

**С помощью just (рекомендуемый способ):**
```bash
# Полное развертывание с проверками
just deploy

# Или быстрое развертывание
just quick-deploy
```

**С помощью wrapper-скрипта:**
```bash
# Автоматически выберет just или make
./vm5 deploy
./vm5 quick-deploy
```

**С помощью make (fallback):**
```bash
make deploy-and-test
```

**Ручное развертывание Terraform:**
```bash
terraform init    # Инициализация
terraform plan     # Планирование  
terraform apply    # Развертывание
```

### 4. Подключение
```bash
# SSH подключение (правильный способ)
terraform output vm5_ssh_command  # покажет готовую команду
# или
VM_IP=$(terraform output -json vm5_info | jq -r '.ip_address')
ssh devops@"$VM_IP"

# Проверка мониторинга (динамически)
VM_IP=$(terraform output -json vm5_info | jq -r '.ip_address')
curl http://"$VM_IP":3000  # Grafana
curl http://"$VM_IP":9090  # Prometheus

# Или через готовые URLs из outputs
terraform output vm5_urls
```

---

## 📖 Детальная конфигурация

### 🔧 **Основные переменные**

| Переменная | Описание | По умолчанию |
|------------|----------|-------------|
| `vm_name` | Имя виртуальной машины | `"vm5-server"` |
| `vm_ip` | IP адрес | `"192.168.123.150"` |
| `vm_cores` | Количество CPU cores | `2` |
| `vm_memory_mb` | Память в MB | `4096` |
| `vm_disk_size_gb` | Размер диска в GB | `50` |

### 🔐 **Безопасность**

| Переменная | Описание | По умолчанию |
|------------|----------|-------------|
| `vm_username` | Основной пользователь | `"devops"` |
| `vm_user_password` | Пароль пользователя | `"vm5secure2024"` |
| `ssh_password_auth` | Разрешить SSH по паролю | `true` |
| `ssh_public_key` | SSH публичный ключ | **Required** |
| `setup_firewall` | Настроить UFW firewall | `true` |

### 🐳 **Функциональность**

| Переменная | Описание | По умолчанию |
|------------|----------|-------------|
| `docker_enabled` | Установить Docker | `true` |
| `monitoring_enabled` | Включить мониторинг | `true` |
| `qemu_agent_enabled` | Включить QEMU Agent | `true` |
| `vm_auto_start` | Автозапуск VM | `true` |

### 📦 **Дополнительные пакеты**

```hcl
install_packages = [
  "curl", "wget", "git", "vim", "htop", 
  "net-tools", "unzip", "tree", "nano",
  "jq", "ncdu", "tmux", "zsh"
]
```

---

## 📊 Мониторинг

### 📈 **Included Monitoring Stack:**

#### **Grafana** (Port 3000)
- **URL:** `$(terraform output -json vm5_urls | jq -r '.grafana')`
- **Login:** `admin`
- **Password:** `vm5admin123` ⚠️ **DEMO пароль - смените!**
- **Features:** Pre-configured dashboards, Prometheus datasource

#### **Prometheus** (Port 9090)
- **URL:** `$(terraform output -json vm5_urls | jq -r '.prometheus')`
- **Targets:** Node Exporter, Self-monitoring
- **Retention:** 15 days (configurable)

#### **Node Exporter** (Port 9100)
- **URL:** `$(terraform output -json vm5_urls | jq -r '.node_exporter')`
- **Metrics:** System metrics, hardware info

### 🔧 **Monitoring Configuration:**
```bash
# Все конфигурации создаются автоматически в:
/home/devops/monitoring/
├── docker-compose.yml
├── prometheus/prometheus.yml
└── grafana/provisioning/datasources/prometheus.yml
```

---

## 🛠️ Управление

### **Task Runners Comparison:**

| Команда | just | make | ./vm5 |
|---------|------|------|-------|
| **deploy** | `just deploy` | `make deploy-and-test` | `./vm5 deploy` |
| **quick-deploy** | `just quick-deploy` | `make quick-deploy` | `./vm5 quick-deploy` |
| **ssh** | `just ssh` | `make ssh` | `./vm5 ssh` |
| **monitor** | `just monitor-all` | `make monitor-all` | `./vm5 monitor-all` |
| **test** | `just test-full` | `make test-ssh` | `./vm5 test-ssh` |

### **Основные команды:**
```bash
# Развертывание
just deploy         # Полное развертывание с валидацией
just quick-deploy   # Быстрое развертывание (auto-approve)

# Мониторинг
just monitor-all    # Полный мониторинг + URLs
just health         # Проверка работоспособности
just test-full      # Комплексное тестирование

# Управление
just ssh            # SSH подключение к VM
just status         # Статус VM
just destroy        # Удаление VM
```

### **Manual Commands:**
```bash
# Terraform operations
terraform plan
terraform apply
terraform destroy

# SSH connection
ssh devops@$(terraform output -raw vm5_ssh_command | cut -d'@' -f2)

# Service checks
ssh devops@<vm_ip> 'docker ps'
ssh devops@<vm_ip> 'systemctl status docker'
```

### **Testing & Validation:**
```bash
# Network connectivity
ping <vm_ip>

# SSH test
ssh -o ConnectTimeout=5 devops@<vm_ip> 'echo VM5 ready'

# Docker test
ssh devops@<vm_ip> 'docker --version'

# Monitoring test
curl -s http://<vm_ip>:9090/api/v1/status/config
```

---

## 📤 Outputs

### **Доступные outputs:**

```bash
# Основная информация
terraform output vm5_info

# SSH команда
terraform output vm5_ssh_command

# URLs мониторинга
terraform output vm5_urls

# Полная сводка
terraform output vm5_summary
```

### **Пример output:**
```json
{
  \"🖥️ VM Info\": {
    \"name\": \"vm5-server\",
    \"ip\": \"192.168.123.150\",
    \"cores\": 2,
    \"memory\": \"4096MB\"
  },
  \"🔗 Connection\": {
    \"ssh\": \"ssh devops@192.168.123.150\"
  },
  \"📊 Monitoring\": {
    \"grafana\": \"http://192.168.123.150:3000 (admin/vm5admin123)\",
    \"prometheus\": \"http://192.168.123.150:9090\"
  }
}
```

---

## 🔧 Customization

### **Изменение IP адреса:**
```hcl
# В terraform.tfvars
vm_ip = "192.168.1.200"
vm_gateway = "192.168.1.1"
```

### **Увеличение ресурсов:**
```hcl
# В terraform.tfvars
vm_cores = 4
vm_memory_mb = 8192
vm_disk_size_gb = 100
```

### **Отключение мониторинга:**
```hcl
# В terraform.tfvars
monitoring_enabled = false
docker_enabled = false  # Если Docker не нужен
```

### **Дополнительные пакеты:**
```hcl
# В terraform.tfvars
install_packages = [
  "curl", "wget", "git", "vim", "htop",
  "nodejs", "npm", "python3-pip"  # Добавляем нужные пакеты
]
```

---

## 🚨 Troubleshooting

### **Проблемы с подключением:**
```bash
# Проверка сети
ping 192.168.123.150

# Проверка SSH порта
nmap -p 22 192.168.123.150

# SSH с отладкой
ssh -v devops@192.168.123.150
```

### **Проблемы с cloud-init:**
```bash
# Подключиться через Proxmox console и проверить
sudo tail -f /var/log/cloud-init-output.log
sudo cloud-init status --wait
```

### **Проблемы с мониторингом:**
```bash
# Проверка Docker контейнеров
ssh devops@192.168.123.150 'cd monitoring && docker-compose ps'

# Перезапуск мониторинга
ssh devops@192.168.123.150 'cd monitoring && docker-compose restart'
```

### **Проблемы с Terraform:**
```bash
# Очистка state (осторожно!)
terraform refresh

# Импорт существующих ресурсов
terraform import proxmox_virtual_environment_vm.vm5_server 750
```

---

## 🔐 Безопасность

### **Рекомендации:**

1. **Смените пароли по умолчанию:**
   ```bash
   # На VM
   sudo passwd devops
   
   # В Grafana
   # Зайдите в UI и смените пароль admin
   ```

2. **Отключите password authentication:**
   ```hcl
   # В terraform.tfvars
   ssh_password_auth = false
   ```

3. **Настройте более строгий firewall:**
   ```bash
   # На VM добавьте specific правила
   sudo ufw allow from 192.168.1.0/24 to any port 3000
   ```

4. **Регулярные обновления:**
   ```bash
   # На VM
   sudo apt update && sudo apt upgrade -y
   ```

---

## 📁 Структура проекта

```
vm5/
├── variables.tf      # 🔧 Все переменные с validation
├── main.tf          # 🏗️ Основная конфигурация Terraform
├── outputs.tf       # 📊 Outputs для информации о VM
├── cloud-init.tftpl # ☁️ Cloud-init template
├── terraform.tfvars # 🔐 Значения переменных
├── Makefile         # 🛠️ Automation команды
├── test-ssh.sh      # 🧪 SSH тестирование
└── README.md        # 📖 Документация
```

---

## 🤝 Контрибьюшены

Проект использует лучшие DevOps практики и открыт для улучшений:

1. **Fork** проект
2. Создайте **feature branch**
3. **Commit** изменения
4. **Push** в branch
5. Создайте **Pull Request**

---

## 📜 Лицензия

MIT License - смотрите [LICENSE](LICENSE) файл.

---

## 🔗 Полезные ссылки

- [Terraform Documentation](https://terraform.io/docs)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Cloud-init Documentation](https://cloud-init.readthedocs.io/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## ✅ Автор

**VM5 Enhanced Project**  
Создан как пример идеального DevOps проекта с Terraform

*Последнее обновление: Декабрь 2024*