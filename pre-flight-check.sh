#!/bin/bash
# Pre-flight Check Script для VM4 и VM5
# Проверяет все необходимые параметры перед развертыванием

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Символы
CHECK="✅"
CROSS="❌"
INFO="ℹ️"
WARN="⚠️"

# Счетчики
PASSED=0
FAILED=0
WARNINGS=0

# Функции для вывода
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}${WARN} $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

# Загрузка переменных из terraform.tfvars
load_vars() {
    local project=$1
    if [[ -f "$project/terraform.tfvars" ]]; then
        # Извлекаем значения переменных
        VM_IP=$(grep "^vm_ip" "$project/terraform.tfvars" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "")
        PROXMOX_PASSWORD=$(grep "^proxmox_password" "$project/terraform.tfvars" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "")
    fi
}

# ==========================================
# 1. ПРОВЕРКА ОСНОВНЫХ ЗАВИСИМОСТЕЙ
# ==========================================
check_dependencies() {
    print_header "1. Проверка зависимостей"

    # Terraform
    if command -v terraform &> /dev/null; then
        TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4 || terraform version | head -1 | cut -d'v' -f2)
        print_success "Terraform установлен (версия: $TF_VERSION)"
    else
        print_error "Terraform не установлен"
    fi

    # curl
    if command -v curl &> /dev/null; then
        print_success "curl установлен"
    else
        print_error "curl не установлен (требуется для API запросов)"
    fi

    # jq (опционально, но полезно)
    if command -v jq &> /dev/null; then
        print_success "jq установлен"
    else
        print_warning "jq не установлен (рекомендуется для обработки JSON)"
    fi

    # ssh
    if command -v ssh &> /dev/null; then
        print_success "SSH клиент установлен"
    else
        print_error "SSH клиент не установлен"
    fi

    # ping
    if command -v ping &> /dev/null; then
        print_success "ping доступен"
    else
        print_warning "ping недоступен (сетевая диагностика ограничена)"
    fi
}

# ==========================================
# 2. ПРОВЕРКА PROXMOX ПОДКЛЮЧЕНИЯ
# ==========================================
check_proxmox_connection() {
    print_header "2. Проверка Proxmox подключения"

    PROXMOX_HOST="192.168.123.41"
    PROXMOX_PORT="8006"
    PROXMOX_URL="https://${PROXMOX_HOST}:${PROXMOX_PORT}"

    # Проверка доступности хоста
    print_info "Проверка доступности ${PROXMOX_HOST}..."
    if ping -c 1 -W 2 "$PROXMOX_HOST" &> /dev/null; then
        print_success "Proxmox хост ${PROXMOX_HOST} доступен по сети"
    else
        print_error "Proxmox хост ${PROXMOX_HOST} недоступен по сети"
        return 1
    fi

    # Проверка порта API
    print_info "Проверка порта ${PROXMOX_PORT}..."
    if timeout 3 bash -c "echo >/dev/tcp/${PROXMOX_HOST}/${PROXMOX_PORT}" 2>/dev/null; then
        print_success "Proxmox API порт ${PROXMOX_PORT} открыт"
    else
        print_error "Proxmox API порт ${PROXMOX_PORT} недоступен"
        return 1
    fi

    # Проверка SSL сертификата (с игнорированием самоподписанного)
    print_info "Проверка HTTPS доступа..."
    if curl -k -s --connect-timeout 5 "${PROXMOX_URL}/api2/json/version" > /dev/null; then
        print_success "Proxmox API HTTPS доступен"
    else
        print_error "Proxmox API HTTPS недоступен"
        return 1
    fi
}

# ==========================================
# 3. ПРОВЕРКА АУТЕНТИФИКАЦИИ PROXMOX
# ==========================================
check_proxmox_auth() {
    print_header "3. Проверка аутентификации Proxmox"

    PROXMOX_HOST="192.168.123.41"
    PROXMOX_URL="https://${PROXMOX_HOST}:8006"

    # Читаем пароль из vm4
    load_vars "vm4"

    if [[ -z "$PROXMOX_PASSWORD" ]]; then
        print_warning "Не удалось прочитать пароль из terraform.tfvars"
        print_info "Введите пароль Proxmox для проверки: "
        read -s PROXMOX_PASSWORD
        echo
    fi

    print_info "Проверка учетных данных root@pam..."

    # Получение токена
    AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
        --data-urlencode "username=root@pam" \
        --data-urlencode "password=${PROXMOX_PASSWORD}" \
        "${PROXMOX_URL}/api2/json/access/ticket" 2>/dev/null)

    if echo "$AUTH_RESPONSE" | grep -q "ticket"; then
        print_success "Аутентификация успешна (root@pam)"

        # Извлекаем информацию о версии
        if command -v jq &> /dev/null; then
            TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket' 2>/dev/null)
            CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken' 2>/dev/null)

            # Получаем версию Proxmox
            VERSION_INFO=$(curl -k -s --connect-timeout 10 \
                -H "Cookie: PVEAuthCookie=${TICKET}" \
                -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
                "${PROXMOX_URL}/api2/json/version" 2>/dev/null)

            if [[ -n "$VERSION_INFO" ]]; then
                PVE_VERSION=$(echo "$VERSION_INFO" | jq -r '.data.version' 2>/dev/null || echo "unknown")
                print_info "Proxmox VE версия: ${PVE_VERSION}"
            fi
        fi
    else
        print_error "Ошибка аутентификации - проверьте логин и пароль"
        print_info "Текущий пароль в terraform.tfvars: '${PROXMOX_PASSWORD}'"
        return 1
    fi
}

# ==========================================
# 4. ПРОВЕРКА PROXMOX РЕСУРСОВ
# ==========================================
check_proxmox_resources() {
    print_header "4. Проверка ресурсов Proxmox"

    PROXMOX_HOST="192.168.123.41"
    PROXMOX_URL="https://${PROXMOX_HOST}:8006"
    NODE_NAME="pve1"

    load_vars "vm4"

    # Получаем токен для запросов
    AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
        --data-urlencode "username=root@pam" \
        --data-urlencode "password=${PROXMOX_PASSWORD}" \
        "${PROXMOX_URL}/api2/json/access/ticket" 2>/dev/null)

    if ! echo "$AUTH_RESPONSE" | grep -q "ticket"; then
        print_warning "Не удалось получить токен для проверки ресурсов"
        return 0
    fi

    if command -v jq &> /dev/null; then
        TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket' 2>/dev/null)
        CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken' 2>/dev/null)

        # Проверка существования ноды
        print_info "Проверка ноды ${NODE_NAME}..."
        NODE_STATUS=$(curl -k -s --connect-timeout 10 \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/status" 2>/dev/null)

        if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
            print_success "Нода ${NODE_NAME} существует и доступна"

            # Информация о ресурсах
            CPU_USAGE=$(echo "$NODE_STATUS" | jq -r '.data.cpu' 2>/dev/null || echo "N/A")
            MEM_TOTAL=$(echo "$NODE_STATUS" | jq -r '.data.memory.total' 2>/dev/null || echo "0")
            MEM_USED=$(echo "$NODE_STATUS" | jq -r '.data.memory.used' 2>/dev/null || echo "0")

            if [[ "$MEM_TOTAL" != "0" ]]; then
                MEM_TOTAL_GB=$((MEM_TOTAL / 1024 / 1024 / 1024))
                MEM_USED_GB=$((MEM_USED / 1024 / 1024 / 1024))
                MEM_FREE_GB=$((MEM_TOTAL_GB - MEM_USED_GB))

                print_info "  CPU загрузка: $(awk "BEGIN {printf \"%.1f%%\", ${CPU_USAGE:-0}*100}")"
                print_info "  Память: ${MEM_USED_GB}GB / ${MEM_TOTAL_GB}GB (свободно: ${MEM_FREE_GB}GB)"

                # Проверка достаточности памяти для VM4 (4GB) + VM5 (4GB) = 8GB
                if [[ $MEM_FREE_GB -ge 8 ]]; then
                    print_success "Достаточно памяти для VM4 и VM5 (требуется ~8GB, доступно ${MEM_FREE_GB}GB)"
                else
                    print_warning "Может не хватить памяти (требуется ~8GB, доступно ${MEM_FREE_GB}GB)"
                fi
            fi
        else
            print_error "Нода ${NODE_NAME} не найдена"
            print_info "Проверьте переменную proxmox_node в конфигурации"
        fi

        # Проверка хранилища
        print_info "Проверка хранилища 'local'..."
        STORAGE_STATUS=$(curl -k -s --connect-timeout 10 \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/storage/local/status" 2>/dev/null)

        if echo "$STORAGE_STATUS" | jq -e '.data' &>/dev/null; then
            print_success "Хранилище 'local' доступно"

            STORAGE_TOTAL=$(echo "$STORAGE_STATUS" | jq -r '.data.total' 2>/dev/null || echo "0")
            STORAGE_USED=$(echo "$STORAGE_STATUS" | jq -r '.data.used' 2>/dev/null || echo "0")

            if [[ "$STORAGE_TOTAL" != "0" ]]; then
                STORAGE_TOTAL_GB=$((STORAGE_TOTAL / 1024 / 1024 / 1024))
                STORAGE_USED_GB=$((STORAGE_USED / 1024 / 1024 / 1024))
                STORAGE_FREE_GB=$((STORAGE_TOTAL_GB - STORAGE_USED_GB))

                print_info "  Диск: ${STORAGE_USED_GB}GB / ${STORAGE_TOTAL_GB}GB (свободно: ${STORAGE_FREE_GB}GB)"

                # Проверка места для VM4 (50GB) + VM5 (50GB) = 100GB
                if [[ $STORAGE_FREE_GB -ge 100 ]]; then
                    print_success "Достаточно места для VM4 и VM5 (требуется ~100GB, доступно ${STORAGE_FREE_GB}GB)"
                else
                    print_warning "Может не хватить места (требуется ~100GB, доступно ${STORAGE_FREE_GB}GB)"
                fi
            fi
        else
            print_error "Хранилище 'local' не найдено или недоступно"
        fi

        # Проверка конфликта VM ID
        print_info "Проверка VM ID 740 и 750..."
        VM740_EXISTS=$(curl -k -s --connect-timeout 10 \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/740/status/current" 2>/dev/null)

        if echo "$VM740_EXISTS" | jq -e '.data' &>/dev/null; then
            print_warning "VM с ID 740 уже существует (конфликт с VM4)"
        else
            print_success "VM ID 740 свободен (для VM4)"
        fi

        VM750_EXISTS=$(curl -k -s --connect-timeout 10 \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/750/status/current" 2>/dev/null)

        if echo "$VM750_EXISTS" | jq -e '.data' &>/dev/null; then
            print_warning "VM с ID 750 уже существует (конфликт с VM5)"
        else
            print_success "VM ID 750 свободен (для VM5)"
        fi
    else
        print_warning "jq не установлен - пропускаем детальную проверку ресурсов"
    fi
}

# ==========================================
# 5. ПРОВЕРКА СЕТЕВЫХ ПАРАМЕТРОВ
# ==========================================
check_network() {
    print_header "5. Проверка сетевых параметров"

    # Проверка IP адресов VM4 и VM5
    VM4_IP="192.168.123.140"
    VM5_IP="192.168.123.150"
    GATEWAY="192.168.123.1"

    print_info "Проверка доступности подсети 192.168.123.0/24..."

    # Проверка gateway
    if ping -c 1 -W 2 "$GATEWAY" &> /dev/null; then
        print_success "Gateway ${GATEWAY} доступен"
    else
        print_warning "Gateway ${GATEWAY} недоступен - проверьте сетевые настройки"
    fi

    # Проверка что IP адреса свободны
    print_info "Проверка доступности IP адресов VM..."

    if ping -c 1 -W 1 "$VM4_IP" &> /dev/null; then
        print_warning "IP ${VM4_IP} уже занят - возможен конфликт с VM4"
    else
        print_success "IP ${VM4_IP} свободен (для VM4)"
    fi

    if ping -c 1 -W 1 "$VM5_IP" &> /dev/null; then
        print_warning "IP ${VM5_IP} уже занят - возможен конфликт с VM5"
    else
        print_success "IP ${VM5_IP} свободен (для VM5)"
    fi

    # Проверка bridge в Proxmox
    print_info "Сетевой bridge должен быть: vmbr0"
}

# ==========================================
# 6. ПРОВЕРКА SSH КЛЮЧЕЙ
# ==========================================
check_ssh_keys() {
    print_header "6. Проверка SSH ключей"

    # Проверяем наличие SSH ключей
    if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        print_success "SSH публичный ключ найден: ~/.ssh/id_rsa.pub"
        SSH_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
        print_info "Ключ: ${SSH_KEY:0:50}..."
    elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        print_success "SSH публичный ключ найден: ~/.ssh/id_ed25519.pub"
        SSH_KEY=$(cat "$HOME/.ssh/id_ed25519.pub")
        print_info "Ключ: ${SSH_KEY:0:50}..."
    else
        print_warning "SSH публичный ключ не найден в стандартных местах"
        print_info "Создайте SSH ключ: ssh-keygen -t rsa -b 4096"
    fi

    # Проверяем ключ в terraform.tfvars
    for project in vm4 vm5; do
        if [[ -f "$project/terraform.tfvars" ]]; then
            if grep -q "ssh_public_key" "$project/terraform.tfvars"; then
                KEY_IN_CONFIG=$(grep "ssh_public_key" "$project/terraform.tfvars" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | cut -c1-50)
                if [[ -n "$KEY_IN_CONFIG" ]]; then
                    print_success "SSH ключ настроен в $project/terraform.tfvars"
                else
                    print_warning "SSH ключ пустой в $project/terraform.tfvars"
                fi
            else
                print_error "SSH ключ не найден в $project/terraform.tfvars"
            fi
        fi
    done
}

# ==========================================
# 7. ПРОВЕРКА TERRAFORM КОНФИГУРАЦИИ
# ==========================================
check_terraform_config() {
    print_header "7. Проверка Terraform конфигурации"

    for project in vm4 vm5; do
        print_info "Проверка проекта $project..."

        if [[ ! -d "$project" ]]; then
            print_error "Директория $project не найдена"
            continue
        fi

        cd "$project" || continue

        # Проверка наличия основных файлов
        if [[ -f "main.tf" ]]; then
            print_success "$project/main.tf существует"
        else
            print_error "$project/main.tf не найден"
        fi

        if [[ -f "terraform.tfvars" ]]; then
            print_success "$project/terraform.tfvars существует"
        else
            print_error "$project/terraform.tfvars не найден"
        fi

        # Terraform validate
        if command -v terraform &> /dev/null; then
            print_info "Запуск terraform validate для $project..."

            if [[ ! -d ".terraform" ]]; then
                print_info "Инициализация Terraform..."
                if terraform init -input=false &> /dev/null; then
                    print_success "Terraform init выполнен успешно"
                else
                    print_error "Ошибка при terraform init"
                    cd .. || exit
                    continue
                fi
            fi

            if terraform validate &> /dev/null; then
                print_success "Terraform validate прошел успешно для $project"
            else
                print_error "Ошибка валидации Terraform для $project"
                terraform validate
            fi
        fi

        cd .. || exit
    done
}

# ==========================================
# 8. ПРОВЕРКА ДОСТУПА К ИНТЕРНЕТУ
# ==========================================
check_internet() {
    print_header "8. Проверка доступа к интернету"

    # Проверка доступа к Ubuntu Cloud Images
    UBUNTU_URL="https://cloud-images.ubuntu.com"

    print_info "Проверка доступа к ${UBUNTU_URL}..."
    if curl -s --connect-timeout 5 -I "$UBUNTU_URL" | grep -q "200\|301\|302"; then
        print_success "Доступ к Ubuntu Cloud Images есть"
    else
        print_warning "Нет доступа к Ubuntu Cloud Images - загрузка образов может не работать"
    fi

    # Проверка DNS
    if nslookup cloud-images.ubuntu.com &> /dev/null || host cloud-images.ubuntu.com &> /dev/null; then
        print_success "DNS разрешение работает"
    else
        print_warning "Проблемы с DNS разрешением"
    fi
}

# ==========================================
# ИТОГОВЫЙ ОТЧЕТ
# ==========================================
print_summary() {
    print_header "ИТОГОВЫЙ ОТЧЕТ"

    TOTAL=$((PASSED + FAILED + WARNINGS))

    echo -e "${GREEN}✅ Успешно: ${PASSED}${NC}"
    echo -e "${RED}❌ Ошибок: ${FAILED}${NC}"
    echo -e "${YELLOW}⚠️  Предупреждений: ${WARNINGS}${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Всего проверок: ${TOTAL}"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 Система готова к развертыванию VM4 и VM5!${NC}"
        echo ""
        echo -e "${BLUE}Следующие шаги:${NC}"
        echo "  1. cd vm4 && terraform apply"
        echo "  2. cd vm5 && terraform apply"
        return 0
    elif [[ $FAILED -lt 3 ]]; then
        echo -e "${YELLOW}⚠️  Система может быть готова, но есть предупреждения${NC}"
        echo "Проверьте ошибки выше перед развертыванием"
        return 1
    else
        echo -e "${RED}❌ Система НЕ готова к развертыванию${NC}"
        echo "Исправьте критические ошибки перед развертыванием"
        return 2
    fi
}

# ==========================================
# MAIN
# ==========================================
main() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Pre-flight Check для VM4 и VM5 проектов          ║"
    echo "║     Proxmox: 192.168.123.41:8006                      ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_dependencies
    check_proxmox_connection
    check_proxmox_auth
    check_proxmox_resources
    check_network
    check_ssh_keys
    check_terraform_config
    check_internet

    print_summary
}

# Запуск
main
