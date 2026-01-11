#!/bin/bash
# Детальная проверка ресурсов Proxmox через API

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"
NODE_NAME="pve1"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Детальная проверка ресурсов Proxmox                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Читаем пароль
if [ -f "vm4/terraform.tfvars" ]; then
    PROXMOX_PASSWORD=$(grep "^proxmox_password" vm4/terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/')
fi

if [ -z "$PROXMOX_PASSWORD" ]; then
    echo "❌ Пароль не найден в vm4/terraform.tfvars"
    exit 1
fi

# Получаем токен аутентификации
echo "🔐 Получение токена аутентификации..."
AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
    --data-urlencode "username=root@pam" \
    --data-urlencode "password=${PROXMOX_PASSWORD}" \
    "${PROXMOX_URL}/api2/json/access/ticket" 2>/dev/null)

if ! echo "$AUTH_RESPONSE" | grep -q "ticket"; then
    echo "❌ Ошибка аутентификации"
    exit 1
fi

TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket' 2>/dev/null)
CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken' 2>/dev/null)

echo "✅ Аутентификация успешна"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. ВЕРСИЯ PROXMOX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━ 1. Версия Proxmox ━━━"
VERSION_INFO=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/version" 2>/dev/null)

if [ -n "$VERSION_INFO" ]; then
    PVE_VERSION=$(echo "$VERSION_INFO" | jq -r '.data.version' 2>/dev/null || echo "unknown")
    PVE_RELEASE=$(echo "$VERSION_INFO" | jq -r '.data.release' 2>/dev/null || echo "unknown")
    echo "  Proxmox VE: $PVE_VERSION"
    echo "  Release: $PVE_RELEASE"
else
    echo "  ⚠️  Не удалось получить версию"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. СТАТУС НОДЫ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━ 2. Статус ноды $NODE_NAME ━━━"
NODE_STATUS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/status" 2>/dev/null)

if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
    echo "  ✅ Нода доступна"

    # CPU
    CPU_COUNT=$(echo "$NODE_STATUS" | jq -r '.data.cpuinfo.cpus' 2>/dev/null || echo "N/A")
    CPU_USAGE=$(echo "$NODE_STATUS" | jq -r '.data.cpu' 2>/dev/null || echo "0")
    CPU_PERCENT=$(awk "BEGIN {printf \"%.1f%%\", ${CPU_USAGE}*100}")

    echo "  CPU:"
    echo "    Количество: $CPU_COUNT cores"
    echo "    Загрузка: $CPU_PERCENT"

    # Память
    MEM_TOTAL=$(echo "$NODE_STATUS" | jq -r '.data.memory.total' 2>/dev/null || echo "0")
    MEM_USED=$(echo "$NODE_STATUS" | jq -r '.data.memory.used' 2>/dev/null || echo "0")
    MEM_FREE=$(echo "$NODE_STATUS" | jq -r '.data.memory.free' 2>/dev/null || echo "0")

    if [ "$MEM_TOTAL" != "0" ]; then
        MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_TOTAL}/1024/1024/1024}")
        MEM_USED_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_USED}/1024/1024/1024}")
        MEM_FREE_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_FREE}/1024/1024/1024}")
        MEM_PERCENT=$(awk "BEGIN {printf \"%.1f%%\", (${MEM_USED}/${MEM_TOTAL})*100}")

        echo "  Память:"
        echo "    Всего: ${MEM_TOTAL_GB} GB"
        echo "    Использовано: ${MEM_USED_GB} GB ($MEM_PERCENT)"
        echo "    Свободно: ${MEM_FREE_GB} GB"

        # Проверка для VM4 (4GB) + VM5 (4GB)
        REQUIRED_GB=8
        if awk "BEGIN {exit !($MEM_FREE_GB >= $REQUIRED_GB)}"; then
            echo "    ✅ Достаточно памяти для VM4+VM5 (требуется ${REQUIRED_GB}GB)"
        else
            echo "    ⚠️  Может не хватить памяти (требуется ${REQUIRED_GB}GB, доступно ${MEM_FREE_GB}GB)"
        fi
    fi

    # Uptime
    UPTIME=$(echo "$NODE_STATUS" | jq -r '.data.uptime' 2>/dev/null || echo "0")
    if [ "$UPTIME" != "0" ]; then
        UPTIME_DAYS=$((UPTIME / 86400))
        UPTIME_HOURS=$(((UPTIME % 86400) / 3600))
        echo "  Uptime: ${UPTIME_DAYS}д ${UPTIME_HOURS}ч"
    fi
else
    echo "  ❌ Нода не найдена или недоступна"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. ХРАНИЛИЩЕ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━ 3. Хранилище ━━━"

# Получаем список хранилищ
STORAGES=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/storage" 2>/dev/null)

if echo "$STORAGES" | jq -e '.data' &>/dev/null; then
    # Проверяем хранилище 'local'
    LOCAL_STORAGE=$(curl -k -s --connect-timeout 10 \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/storage/local/status" 2>/dev/null)

    if echo "$LOCAL_STORAGE" | jq -e '.data' &>/dev/null; then
        echo "  Хранилище 'local':"

        STOR_TOTAL=$(echo "$LOCAL_STORAGE" | jq -r '.data.total' 2>/dev/null || echo "0")
        STOR_USED=$(echo "$LOCAL_STORAGE" | jq -r '.data.used' 2>/dev/null || echo "0")
        STOR_AVAIL=$(echo "$LOCAL_STORAGE" | jq -r '.data.avail' 2>/dev/null || echo "0")

        if [ "$STOR_TOTAL" != "0" ]; then
            STOR_TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_TOTAL}/1024/1024/1024}")
            STOR_USED_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_USED}/1024/1024/1024}")
            STOR_AVAIL_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_AVAIL}/1024/1024/1024}")
            STOR_PERCENT=$(awk "BEGIN {printf \"%.1f%%\", (${STOR_USED}/${STOR_TOTAL})*100}")

            echo "    Всего: ${STOR_TOTAL_GB} GB"
            echo "    Использовано: ${STOR_USED_GB} GB ($STOR_PERCENT)"
            echo "    Доступно: ${STOR_AVAIL_GB} GB"

            # Проверка для VM4 (50GB) + VM5 (50GB) + образы (~5GB)
            REQUIRED_GB=105
            if awk "BEGIN {exit !($STOR_AVAIL_GB >= $REQUIRED_GB)}"; then
                echo "    ✅ Достаточно места для VM4+VM5 (требуется ~${REQUIRED_GB}GB)"
            else
                echo "    ⚠️  Может не хватить места (требуется ~${REQUIRED_GB}GB, доступно ${STOR_AVAIL_GB}GB)"
            fi
        fi

        # Проверяем поддержку типов контента
        STOR_CONTENT=$(echo "$LOCAL_STORAGE" | jq -r '.data.content' 2>/dev/null || echo "")
        if [ -n "$STOR_CONTENT" ]; then
            echo "    Типы контента: $STOR_CONTENT"
        fi
    else
        echo "  ❌ Хранилище 'local' не найдено"
    fi
else
    echo "  ⚠️  Не удалось получить список хранилищ"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. СУЩЕСТВУЮЩИЕ VM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━ 4. Проверка VM ID ━━━"

# Проверка VM 740 (для VM4)
VM740_STATUS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/740/status/current" 2>/dev/null)

if echo "$VM740_STATUS" | jq -e '.data' &>/dev/null; then
    VM740_NAME=$(echo "$VM740_STATUS" | jq -r '.data.name' 2>/dev/null || echo "unknown")
    VM740_STATUS_TEXT=$(echo "$VM740_STATUS" | jq -r '.data.status' 2>/dev/null || echo "unknown")
    echo "  ⚠️  VM ID 740 уже существует:"
    echo "    Имя: $VM740_NAME"
    echo "    Статус: $VM740_STATUS_TEXT"
    echo "    Действие: Terraform пересоздаст или обновит эту VM"
else
    echo "  ✅ VM ID 740 свободен (для VM4)"
fi

# Проверка VM 750 (для VM5)
VM750_STATUS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/750/status/current" 2>/dev/null)

if echo "$VM750_STATUS" | jq -e '.data' &>/dev/null; then
    VM750_NAME=$(echo "$VM750_STATUS" | jq -r '.data.name' 2>/dev/null || echo "unknown")
    VM750_STATUS_TEXT=$(echo "$VM750_STATUS" | jq -r '.data.status' 2>/dev/null || echo "unknown")
    echo "  ⚠️  VM ID 750 уже существует:"
    echo "    Имя: $VM750_NAME"
    echo "    Статус: $VM750_STATUS_TEXT"
    echo "    Действие: Terraform пересоздаст или обновит эту VM"
else
    echo "  ✅ VM ID 750 свободен (для VM5)"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. СЕТЕВЫЕ ИНТЕРФЕЙСЫ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━ 5. Сетевые интерфейсы ━━━"

NETWORK=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/network" 2>/dev/null)

if echo "$NETWORK" | jq -e '.data' &>/dev/null; then
    # Проверяем vmbr0
    VMBR0=$(echo "$NETWORK" | jq -r '.data[] | select(.iface=="vmbr0")' 2>/dev/null)

    if [ -n "$VMBR0" ]; then
        echo "  ✅ Bridge vmbr0 существует"
        VMBR0_TYPE=$(echo "$VMBR0" | jq -r '.type' 2>/dev/null || echo "unknown")
        VMBR0_ACTIVE=$(echo "$VMBR0" | jq -r '.active' 2>/dev/null || echo "0")
        echo "    Тип: $VMBR0_TYPE"
        echo "    Активен: $([ "$VMBR0_ACTIVE" == "1" ] && echo 'Да' || echo 'Нет')"
    else
        echo "  ❌ Bridge vmbr0 не найден"
        echo "     Конфигурация VM требует vmbr0"
    fi
else
    echo "  ⚠️  Не удалось получить список сетевых интерфейсов"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ИТОГОВАЯ СВОДКА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ИТОГОВАЯ СВОДКА                                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Требования для развертывания:"
echo "  VM4: 2 CPU, 4GB RAM, 50GB диск"
echo "  VM5: 2 CPU, 4GB RAM, 50GB диск"
echo "  Итого: 4 CPU, 8GB RAM, 100GB диск + ~5GB для образов"
echo ""
echo "Готовность к развертыванию:"
if [ -n "$MEM_FREE_GB" ] && [ -n "$STOR_AVAIL_GB" ]; then
    if awk "BEGIN {exit !($MEM_FREE_GB >= 8)}" && awk "BEGIN {exit !($STOR_AVAIL_GB >= 105)}"; then
        echo "  ✅ Система готова к развертыванию"
    else
        echo "  ⚠️  Проверьте доступные ресурсы"
    fi
else
    echo "  ℹ️  Выполните проверку выше для оценки"
fi
echo ""
