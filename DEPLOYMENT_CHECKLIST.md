# Чеклист готовности к развертыванию VM4 и VM5

## Дата проверки
Автоматически обновляется при запуске скриптов проверки

## Статус: ✅ ГОТОВО К РАЗВЕРТЫВАНИЮ

---

## 1. Proxmox Сервер

### Информация о сервере
- **URL**: https://192.168.123.41:8006
- **Версия**: Proxmox VE 8.4.11 (Release 8.4)
- **Нода**: pve01
- **Статус**: ✅ Онлайн
- **CPU загрузка**: ~2%
- **Память**: 13GB / 62GB (доступно: 49GB)

### Учетные данные
- **Логин**: root@pam
- **Пароль**: 1
- **Аутентификация**: ✅ Успешна

---

## 2. Сетевые Параметры

### Основные настройки
- **Подсеть**: 192.168.123.0/24
- **Gateway**: 192.168.123.1 (✅ доступен)
- **Bridge**: vmbr0

### IP адреса VM
| VM | IP адрес | Статус | Назначение |
|----|----------|--------|------------|
| VM4 | 192.168.123.140 | ✅ Свободен | Production server |
| VM5 | 192.168.123.150 | ✅ Свободен | Enhanced server с мониторингом |

### VM ID
| VM | VM ID | Статус |
|----|-------|--------|
| VM4 | 740 | ✅ Свободен |
| VM5 | 750 | ✅ Свободен |

---

## 3. Ресурсы для Развертывания

### Требования
```
VM4 (Production):
  - CPU: 2 cores
  - RAM: 4096 MB
  - Disk: 50 GB
  - OS: Ubuntu 22.04 LTS

VM5 (Enhanced):
  - CPU: 2 cores
  - RAM: 4096 MB
  - Disk: 50 GB
  - OS: Ubuntu 22.04 LTS
  - Дополнительно: Docker, Prometheus, Grafana

Общие требования:
  - CPU: 4 cores
  - RAM: 8 GB
  - Disk: ~105 GB (включая образы)
```

### Доступные ресурсы
- **CPU**: Достаточно (загрузка 2%)
- **RAM**: 49GB свободно (требуется 8GB) ✅
- **Disk**: Проверяется автоматически ✅

---

## 4. Зависимости и Инструменты

### Установленные инструменты
- ✅ Terraform v1.9.5
- ✅ curl
- ✅ jq
- ✅ SSH клиент
- ✅ ping

### Terraform Проекты
| Проект | main.tf | terraform.tfvars | .terraform | Статус |
|--------|---------|------------------|------------|--------|
| vm4 | ✅ | ✅ | ✅ | Готов |
| vm5 | ✅ | ✅ | ✅ | Готов |

---

## 5. Конфигурация Проектов

### VM4 (Упрощенная конфигурация)
```hcl
Proxmox:
  - Endpoint: https://192.168.123.41:8006
  - Username: root@pam
  - Password: 1
  - Node: pve01
  - Datastore: local

VM параметры:
  - Name: vm4-server
  - VM ID: 740
  - IP: 192.168.123.140/24
  - Gateway: 192.168.123.1
  - CPU: 2 cores
  - RAM: 4GB
  - Disk: 50GB

Пользователь:
  - Username: devops
  - SSH: ключ из terraform.tfvars
  - Password auth: включен
```

### VM5 (Расширенная конфигурация)
```hcl
Proxmox:
  - Endpoint: https://192.168.123.41:8006
  - Username: root@pam
  - Password: 1
  - Node: pve01
  - Datastore: local

VM параметры:
  - Name: vm5-server
  - VM ID: 750
  - IP: 192.168.123.150/24
  - Gateway: 192.168.123.1
  - CPU: 2 cores
  - RAM: 4GB
  - Disk: 50GB

Функциональность:
  - Docker: включен
  - Monitoring: включен (Grafana:3000, Prometheus:9090)
  - Firewall: включен (UFW)
  - QEMU Agent: включен

Пользователь:
  - Username: devops
  - SSH: ключ из terraform.tfvars
  - Password auth: включен
```

---

## 6. SSH Ключи

### Статус
- ⚠️ SSH ключ не найден в ~/.ssh/id_rsa.pub или ~/.ssh/id_ed25519.pub
- ✅ SSH ключ настроен в vm4/terraform.tfvars
- ✅ SSH ключ настроен в vm5/terraform.tfvars

### Рекомендация
Если вы хотите использовать SSH ключ с локальной машины:
```bash
# Создать новый ключ (если нет)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Скопировать публичный ключ
cat ~/.ssh/id_rsa.pub

# Обновить в terraform.tfvars обоих проектов
vim vm4/terraform.tfvars
vim vm5/terraform.tfvars
```

---

## 7. Интернет Подключение

### Статус
- ✅ Доступ к Ubuntu Cloud Images (https://cloud-images.ubuntu.com)
- ✅ Загрузка образов будет работать

---

## 8. Критические Изменения

### Обновленные параметры
Все конфигурации обновлены с новыми учетными данными:

#### Proxmox
- ❌ Старый endpoint: 192.168.88.76:8006
- ✅ Новый endpoint: 192.168.123.41:8006
- ❌ Старый пароль: proxmox123
- ✅ Новый пароль: 1
- ❌ Старая нода: pve1
- ✅ Новая нода: pve01

#### Сеть
- ❌ Старая подсеть: 192.168.88.0/24
- ✅ Новая подсеть: 192.168.123.0/24
- ❌ Старый gateway: 192.168.88.1
- ✅ Новый gateway: 192.168.123.1

#### IP адреса
- VM4: 192.168.88.140 → 192.168.123.140 ✅
- VM5: 192.168.88.150 → 192.168.123.150 ✅

### Обновленные файлы
```
vm4/
  ✅ main.tf (endpoint, node, IP адреса)
  ✅ terraform.tfvars (пароль)
  ✅ outputs.tf (IP адреса, SSH команды)
  ✅ README.md (документация)

vm5/
  ✅ variables.tf (endpoint, node, IP defaults)
  ✅ terraform.tfvars (пароль, IP адреса)
  ✅ README.md (документация)
```

---

## 9. Скрипты Проверки

### Доступные скрипты
```bash
# Быстрая проверка готовности
./check-readiness.sh

# Детальная проверка ресурсов Proxmox
./check-proxmox-resources.sh

# Проверка доступных нод
./check-nodes.sh

# Полная pre-flight проверка
./pre-flight-check.sh
```

---

## 10. Развертывание

### Пошаговая инструкция

#### Опция A: Развертывание VM4
```bash
# 1. Перейти в директорию проекта
cd vm4

# 2. Проверить конфигурацию
terraform validate

# 3. Посмотреть план развертывания
terraform plan

# 4. Применить конфигурацию
terraform apply

# 5. Подключиться по SSH (после развертывания)
ssh devops@192.168.123.140
```

#### Опция B: Развертывание VM5
```bash
# 1. Перейти в директорию проекта
cd vm5

# 2. Проверить конфигурацию
terraform validate

# 3. Посмотреть план развертывания
terraform plan

# 4. Применить конфигурацию
terraform apply

# 5. Подключиться по SSH (после развертывания)
ssh devops@192.168.123.150

# 6. Проверить мониторинг
# Grafana: http://192.168.123.150:3000 (admin/vm5admin123)
# Prometheus: http://192.168.123.150:9090
```

#### Опция C: Развертывание обеих VM
```bash
# Последовательное развертывание
cd vm4 && terraform apply && cd ../vm5 && terraform apply

# Или параллельно в разных терминалах
# Терминал 1:
cd vm4 && terraform apply

# Терминал 2:
cd vm5 && terraform apply
```

---

## 11. Возможные Проблемы и Решения

### Проблема: Ошибка аутентификации Proxmox
**Решение:**
```bash
# Проверить пароль в terraform.tfvars
grep proxmox_password vm4/terraform.tfvars

# Проверить подключение вручную
curl -k --data-urlencode "username=root@pam" \
     --data-urlencode "password=1" \
     https://192.168.123.41:8006/api2/json/access/ticket
```

### Проблема: IP адрес уже занят
**Решение:**
```bash
# Проверить, кто использует IP
ping 192.168.123.140
arp -a | grep 192.168.123.140

# Изменить IP в terraform.tfvars (для VM5)
# Для VM4 - изменить в main.tf
```

### Проблема: Нода не найдена
**Решение:**
```bash
# Проверить доступные ноды
./check-nodes.sh

# Обновить в конфигурации при необходимости
```

### Проблема: Недостаточно ресурсов
**Решение:**
```bash
# Проверить ресурсы
./check-proxmox-resources.sh

# Уменьшить требования в terraform.tfvars (для VM5):
vm_cores = 1
vm_memory_mb = 2048
vm_disk_size_gb = 30
```

---

## 12. После Развертывания

### Проверка VM4
```bash
# SSH подключение
ssh devops@192.168.123.140

# Проверка системы
uname -a
df -h
free -h
ip addr show
```

### Проверка VM5
```bash
# SSH подключение
ssh devops@192.168.123.150

# Проверка Docker
docker --version
docker ps

# Проверка мониторинга
cd ~/monitoring
docker-compose ps

# Веб-интерфейсы
# Grafana: http://192.168.123.150:3000
# Prometheus: http://192.168.123.150:9090
# Node Exporter: http://192.168.123.150:9100/metrics
```

---

## 13. Безопасность

### Рекомендации после развертывания

1. **Сменить пароли**
```bash
# На VM
ssh devops@192.168.123.XXX
sudo passwd devops

# В Grafana (VM5)
# Зайти в UI и сменить пароль admin
```

2. **Отключить password authentication SSH** (опционально)
```hcl
# В terraform.tfvars
ssh_password_auth = false
```

3. **Настроить firewall**
```bash
# На VM
sudo ufw status
sudo ufw allow from 192.168.123.0/24 to any port 3000  # Grafana только для локальной сети
```

4. **Обновить систему**
```bash
# На VM
sudo apt update && sudo apt upgrade -y
```

---

## 14. Мониторинг и Поддержка

### Команды мониторинга
```bash
# Статус VM в Proxmox (из хост-машины)
./check-proxmox-resources.sh

# Логи cloud-init (на VM после развертывания)
ssh devops@192.168.123.XXX
sudo tail -f /var/log/cloud-init-output.log

# Terraform outputs
cd vm4 && terraform output
cd vm5 && terraform output
```

---

## 15. Очистка

### Удаление VM
```bash
# Удалить VM4
cd vm4 && terraform destroy

# Удалить VM5
cd vm5 && terraform destroy

# Или обе
cd vm4 && terraform destroy && cd ../vm5 && terraform destroy
```

---

## Контрольный Список Перед Развертыванием

- [x] Proxmox доступен и аутентификация работает
- [x] Сетевые параметры корректны
- [x] IP адреса свободны
- [x] VM ID свободны
- [x] Достаточно CPU, RAM, Disk
- [x] Terraform установлен и инициализирован
- [x] Конфигурационные файлы обновлены
- [x] SSH ключи настроены
- [x] Интернет доступен для загрузки образов
- [ ] Пользователь ознакомлен с документацией
- [ ] Создана резервная копия (если есть существующие VM)

---

## Заключение

**Статус системы**: ✅ ГОТОВА К РАЗВЕРТЫВАНИЮ

Все необходимые параметры проверены и обновлены. Проекты VM4 и VM5 готовы к развертыванию.

Для начала развертывания выполните:
```bash
cd vm4 && terraform apply
# или
cd vm5 && terraform apply
```

---

**Дата создания чеклиста**: $(date)
**Последняя проверка**: Запустите ./check-readiness.sh для обновления
