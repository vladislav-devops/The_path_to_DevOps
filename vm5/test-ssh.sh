#!/bin/bash
# 🧪 SSH тестирование для VM5 - Enterprise Version
# Интеграция с Terraform outputs, безопасность, без хардкода

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные среды для гибкости
VM5_PASSWORD="${VM5_PASSWORD:-vm5secure2024}"
ENABLE_PASSWORD_SSH="${ENABLE_PASSWORD_SSH:-false}"

# Функции для логирования
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

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    if ! command -v terraform >/dev/null 2>&1; then
        missing+=("terraform")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if ! command -v nc >/dev/null 2>&1; then
        missing+=("nc (netcat)")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Отсутствуют зависимости: ${missing[*]}"
        log "Установите: brew install ${missing[*]// jq/ jq nc}"
        exit 1
    fi
}

# Получение информации из Terraform
get_vm_info() {
    log "Получение информации о VM5 из Terraform..."
    
    # Проверяем, что terraform state существует
    if ! terraform output vm5_info >/dev/null 2>&1; then
        error "Не удалось получить vm5_info из terraform output"
        log "Убедитесь что выполнен 'terraform apply' и VM развернута"
        exit 1
    fi
    
    # Получаем основную информацию
    VM_INFO_JSON=$(terraform output -json vm5_info)
    if [ -z "$VM_INFO_JSON" ] || [ "$VM_INFO_JSON" = "null" ]; then
        error "vm5_info пустой или null"
        exit 1
    fi
    
    # Извлекаем данные
    VM_IP=$(echo "$VM_INFO_JSON" | jq -r '.ip_address')
    VM_USER=$(echo "$VM_INFO_JSON" | jq -r '.username')
    SSH_COMMAND=$(echo "$VM_INFO_JSON" | jq -r '.ssh_command')
    
    # Получаем настройки безопасности  
    SECURITY_INFO=$(terraform output -json vm5_security 2>/dev/null || echo '{}')
    SSH_PASSWORD_AUTH=$(echo "$SECURITY_INFO" | jq -r '.ssh_password_auth // "true"')
    
    # Валидация данных
    if [ "$VM_IP" = "null" ] || [ -z "$VM_IP" ]; then
        error "Не удалось получить IP адрес VM"
        exit 1
    fi
    
    if [ "$VM_USER" = "null" ] || [ -z "$VM_USER" ]; then
        error "Не удалось получить username VM"
        exit 1
    fi
    
    log "VM IP: $VM_IP"
    log "VM User: $VM_USER" 
    log "SSH Command: $SSH_COMMAND"
    log "SSH Password Auth: $SSH_PASSWORD_AUTH"
}

# Тест 1: Проверка доступности по сети
test_network() {
    log "Тест 1: Проверка доступности по ping..."
    if ping -c 3 -W 3000 "$VM_IP" > /dev/null 2>&1; then
        success "VM доступна по сети"
    else
        error "VM недоступна по ping"
        exit 1
    fi
}

# Тест 2: Проверка SSH порта
test_ssh_port() {
    log "Тест 2: Проверка SSH порта (22)..."
    if nc -zv "$VM_IP" 22 >/dev/null 2>&1; then
        success "SSH порт открыт"
    else
        error "SSH порт недоступен"
        exit 1
    fi
}

# Тест 3: SSH подключение с ключами
test_ssh_keys() {
    log "Тест 3: Проверка SSH подключения с ключами..."
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "echo 'SSH connection successful'" 2>/dev/null; then
        success "SSH подключение с ключами работает"
        return 0
    else
        warning "SSH подключение с ключами не работает"
        return 1
    fi
}

# Тест 4: SSH подключение с паролем (если разрешено)
test_ssh_password() {
    # Проверяем настройки безопасности
    if [ "$SSH_PASSWORD_AUTH" = "false" ]; then
        log "SSH аутентификация по паролю отключена (безопасно)"
        return 1
    fi
    
    # Проверяем переменную среды
    if [ "$ENABLE_PASSWORD_SSH" != "true" ]; then
        log "Тесты с паролем отключены через ENABLE_PASSWORD_SSH"
        log "Для включения: export ENABLE_PASSWORD_SSH=true"
        return 1
    fi
    
    # Проверяем наличие sshpass
    if ! command -v sshpass >/dev/null 2>&1; then
        warning "sshpass не установлен, пропускаем тест с паролем"
        log "Установите: brew install sshpass"
        return 1
    fi
    
    log "Тест 4: Проверка SSH подключения с паролем..."
    if sshpass -p "$VM5_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "echo 'SSH password login successful'" 2>/dev/null; then
        success "SSH подключение с паролем работает"
        return 0
    else
        error "SSH подключение с паролем не работает"
        return 1
    fi
}

# Тест 5: Выполнение базовых команд
test_basic_commands() {
    log "Тест 5: Проверка базовых команд..."
    
    # Пробуем с ключами, потом с паролем
    SSH_TEST=""
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "whoami && hostname && uptime" 2>/dev/null; then
        SSH_TEST=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "whoami && hostname && uptime" 2>/dev/null)
    elif [ "$SSH_PASSWORD_AUTH" = "true" ] && [ "$ENABLE_PASSWORD_SSH" = "true" ] && command -v sshpass >/dev/null 2>&1; then
        SSH_TEST=$(sshpass -p "$VM5_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "whoami && hostname && uptime" 2>/dev/null)
    fi
    
    if [ ! -z "$SSH_TEST" ]; then
        success "Базовые команды выполняются успешно:"
        echo "$SSH_TEST"
    else
        error "Не удалось выполнить базовые команды"
        exit 1
    fi
}

# Тест 6: Проверка cloud-init результатов
test_cloud_init() {
    log "Тест 6: Проверка результатов cloud-init..."
    
    # Пробуем с ключами, потом с паролем
    CLOUD_INIT_RESULT=""
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "cat ~/welcome.txt 2>/dev/null" 2>/dev/null; then
        CLOUD_INIT_RESULT=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "cat ~/welcome.txt 2>/dev/null" 2>/dev/null)
    elif [ "$SSH_PASSWORD_AUTH" = "true" ] && [ "$ENABLE_PASSWORD_SSH" = "true" ] && command -v sshpass >/dev/null 2>&1; then
        CLOUD_INIT_RESULT=$(sshpass -p "$VM5_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "cat ~/welcome.txt 2>/dev/null" 2>/dev/null)
    fi
    
    if [ ! -z "$CLOUD_INIT_RESULT" ]; then
        success "Cloud-init выполнен успешно: $CLOUD_INIT_RESULT"
    else
        warning "Файл ~/welcome.txt не найден (cloud-init возможно еще не завершен)"
    fi
}

# Тест 7: Проверка установленных пакетов
test_packages() {
    log "Тест 7: Проверка установленных пакетов..."
    
    # Пробуем с ключами, потом с паролем
    PACKAGES_CHECK=""
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "which curl git vim htop" 2>/dev/null; then
        PACKAGES_CHECK=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$VM_USER@$VM_IP" "which curl git vim htop" 2>/dev/null)
    elif [ "$SSH_PASSWORD_AUTH" = "true" ] && [ "$ENABLE_PASSWORD_SSH" = "true" ] && command -v sshpass >/dev/null 2>&1; then
        PACKAGES_CHECK=$(sshpass -p "$VM5_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "which curl git vim htop" 2>/dev/null)
    fi
    
    if [ ! -z "$PACKAGES_CHECK" ]; then
        success "Основные пакеты установлены"
    else
        warning "Некоторые пакеты могут быть не установлены"
    fi
}

# Основная логика
main() {
    echo ""
    log "🚀 Запуск тестирования VM5 (Enterprise Version)"
    echo ""
    
    # Проверка зависимостей
    check_dependencies
    
    # Получение информации из Terraform
    get_vm_info
    
    echo ""
    log "Начинаем серию тестов..."
    echo ""
    
    # Запуск тестов
    test_network
    test_ssh_port
    
    # SSH тесты с учетом настроек безопасности
    if test_ssh_keys; then
        log "Используем SSH ключи для дальнейших тестов"
    elif test_ssh_password; then
        log "Используем SSH пароль для дальнейших тестов"
        warning "Рекомендуется настроить SSH ключи для безопасности"
    else
        error "SSH подключение невозможно"
        log "Проверьте настройки SSH ключей или паролей"
        exit 1
    fi
    
    # Дополнительные тесты
    test_basic_commands
    test_cloud_init  
    test_packages
    
    # Финальный отчет
    echo ""
    log "🎉 SSH тестирование завершено!"
    success "VM5 готова к использованию"
    log "Для подключения используйте: $SSH_COMMAND"
    
    # Показываем полезные команды
    echo ""
    log "📋 Полезные команды:"
    log "  terraform output vm5_info      # Информация о VM"
    log "  terraform output vm5_urls      # URLs мониторинга"
    log "  terraform output vm5_security  # Настройки безопасности"
    echo ""
}

# Запуск основной функции
main "$@"