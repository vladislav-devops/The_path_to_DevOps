#!/bin/bash
# 🧪 SSH тестирование для VM4

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Получаем информацию о VM из Terraform
log "Получение информации о VM4..."
VM_IP=$(terraform output -json vm4_info 2>/dev/null | jq -r '.ip_address' 2>/dev/null || echo "192.168.88.140")
SSH_COMMAND=$(terraform output -raw vm4_ssh_command 2>/dev/null || echo "ssh devops@192.168.88.140")

log "VM IP: $VM_IP"
log "SSH Command: $SSH_COMMAND"

# Тест 1: Проверка доступности по сети
log "Тест 1: Проверка доступности по ping..."
if ping -c 3 -W 3000 $VM_IP > /dev/null 2>&1; then
    success "VM доступна по сети"
else
    error "VM недоступна по ping"
    exit 1
fi

# Тест 2: Проверка SSH порта
log "Тест 2: Проверка SSH порта (22)..."
if nc -zv $VM_IP 22 >/dev/null 2>&1; then
    success "SSH порт открыт"
else
    error "SSH порт недоступен"
    exit 1
fi

# Тест 3: Проверка SSH соединения с ключами
log "Тест 3: Проверка SSH подключения с ключами..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes devops@$VM_IP "echo 'SSH connection successful'" 2>/dev/null; then
    success "SSH подключение с ключами работает"
else
    warning "SSH подключение с ключами не работает, проверяем альтернативные варианты..."
    
    # Попробуем с паролем
    log "Пробуем подключение с паролем..."
    if sshpass -p "vm4pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "echo 'SSH password login successful'" 2>/dev/null; then
        success "SSH подключение с паролем работает"
    else
        error "SSH подключение невозможно"
        
        # Диагностика
        log "Проведение диагностики..."
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -v devops@$VM_IP 2>&1 | head -20
        exit 1
    fi
fi

# Тест 4: Проверка базовых команд
log "Тест 4: Проверка базовых команд..."
SSH_KEY_TEST=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "whoami && hostname && uptime" 2>/dev/null || sshpass -p "vm4pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "whoami && hostname && uptime" 2>/dev/null)

if [ ! -z "$SSH_KEY_TEST" ]; then
    success "Базовые команды выполняются успешно:"
    echo "$SSH_KEY_TEST"
else
    error "Не удалось выполнить базовые команды"
    exit 1
fi

# Тест 5: Проверка cloud-init результатов
log "Тест 5: Проверка результатов cloud-init..."
CLOUD_INIT_RESULT=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "cat welcome.txt 2>/dev/null" 2>/dev/null || sshpass -p "vm4pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "cat welcome.txt 2>/dev/null" 2>/dev/null)

if [ ! -z "$CLOUD_INIT_RESULT" ]; then
    success "Cloud-init выполнен успешно: $CLOUD_INIT_RESULT"
else
    warning "Файл welcome.txt не найден (cloud-init возможно еще не завершен)"
fi

# Тест 6: Проверка установленных пакетов
log "Тест 6: Проверка установленных пакетов..."
PACKAGES_CHECK=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "which curl git vim htop" 2>/dev/null || sshpass -p "vm4pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no devops@$VM_IP "which curl git vim htop" 2>/dev/null)

if [ ! -z "$PACKAGES_CHECK" ]; then
    success "Основные пакеты установлены"
else
    warning "Некоторые пакеты могут быть не установлены"
fi

# Финальный отчет
echo ""
log "🎉 SSH тестирование завершено!"
success "VM4 готова к использованию"
log "Для подключения используйте: $SSH_COMMAND"
echo ""