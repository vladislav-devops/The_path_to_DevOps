#!/bin/bash
# Полная проверка ресурсов Proxmox

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"
NODE_NAME="pve01"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ПОЛНЫЙ АУДИТ РЕСУРСОВ PROXMOX                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Читаем пароль
if [ -f "vm4/terraform.tfvars" ]; then
    PROXMOX_PASSWORD=$(grep "^proxmox_password" vm4/terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/')
fi

# Получаем токен
echo "🔐 Аутентификация..."
AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
    --data-urlencode "username=root@pam" \
    --data-urlencode "password=${PROXMOX_PASSWORD}" \
    "${PROXMOX_URL}/api2/json/access/ticket" 2>/dev/null)

TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket' 2>/dev/null)
CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken' 2>/dev/null)

if [ -z "$TICKET" ] || [ "$TICKET" == "null" ]; then
    echo "❌ Ошибка аутентификации"
    exit 1
fi

echo "✅ Подключено к Proxmox"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. ВЕРСИЯ И ОБЩАЯ ИНФОРМАЦИЯ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. ИНФОРМАЦИЯ О СИСТЕМЕ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VERSION_INFO=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/version" 2>/dev/null)

if [ -n "$VERSION_INFO" ]; then
    PVE_VERSION=$(echo "$VERSION_INFO" | jq -r '.data.version' 2>/dev/null || echo "unknown")
    PVE_RELEASE=$(echo "$VERSION_INFO" | jq -r '.data.release' 2>/dev/null || echo "unknown")
    echo "  Proxmox VE Version: $PVE_VERSION"
    echo "  Release: $PVE_RELEASE"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. CPU РЕСУРСЫ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. CPU РЕСУРСЫ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NODE_STATUS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/status" 2>/dev/null)

if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
    CPU_COUNT=$(echo "$NODE_STATUS" | jq -r '.data.cpuinfo.cpus' 2>/dev/null || echo "N/A")
    CPU_CORES=$(echo "$NODE_STATUS" | jq -r '.data.cpuinfo.cores' 2>/dev/null || echo "N/A")
    CPU_SOCKETS=$(echo "$NODE_STATUS" | jq -r '.data.cpuinfo.sockets' 2>/dev/null || echo "N/A")
    CPU_MODEL=$(echo "$NODE_STATUS" | jq -r '.data.cpuinfo.model' 2>/dev/null || echo "N/A")
    CPU_USAGE=$(echo "$NODE_STATUS" | jq -r '.data.cpu' 2>/dev/null || echo "0")
    CPU_PERCENT=$(awk "BEGIN {printf \"%.2f%%\", ${CPU_USAGE}*100}")

    echo "  CPU Model: $CPU_MODEL"
    echo "  Total CPUs: $CPU_COUNT"
    echo "  Cores per Socket: $CPU_CORES"
    echo "  Sockets: $CPU_SOCKETS"
    echo "  Current Usage: $CPU_PERCENT"
    echo ""
    echo "  📊 Доступно для VM:"
    echo "    - Можно выделить до $CPU_COUNT vCPU суммарно"
    echo "    - Рекомендуется: не более $(($CPU_COUNT * 2)) vCPU (с overcommit)"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. ПАМЯТЬ (RAM)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. ПАМЯТЬ (RAM)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
    MEM_TOTAL=$(echo "$NODE_STATUS" | jq -r '.data.memory.total' 2>/dev/null || echo "0")
    MEM_USED=$(echo "$NODE_STATUS" | jq -r '.data.memory.used' 2>/dev/null || echo "0")
    MEM_FREE=$(echo "$NODE_STATUS" | jq -r '.data.memory.free' 2>/dev/null || echo "0")

    if [ "$MEM_TOTAL" != "0" ]; then
        MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_TOTAL}/1024/1024/1024}")
        MEM_USED_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_USED}/1024/1024/1024}")
        MEM_FREE_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_FREE}/1024/1024/1024}")
        MEM_PERCENT=$(awk "BEGIN {printf \"%.2f%%\", (${MEM_USED}/${MEM_TOTAL})*100}")

        echo "  Total RAM: ${MEM_TOTAL_GB} GB"
        echo "  Used: ${MEM_USED_GB} GB ($MEM_PERCENT)"
        echo "  Free: ${MEM_FREE_GB} GB"
        echo ""
        echo "  📊 Примеры VM которые можно создать:"

        VM_2GB=$(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/2}")
        VM_4GB=$(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/4}")
        VM_8GB=$(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/8}")
        VM_16GB=$(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/16}")

        echo "    - VM с 2GB RAM: до $VM_2GB штук"
        echo "    - VM с 4GB RAM: до $VM_4GB штук"
        echo "    - VM с 8GB RAM: до $VM_8GB штук"
        echo "    - VM с 16GB RAM: до $VM_16GB штук"
    fi
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. ХРАНИЛИЩЕ (STORAGE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. ХРАНИЛИЩЕ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Список всех хранилищ
STORAGES=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/storage" 2>/dev/null)

if echo "$STORAGES" | jq -e '.data' &>/dev/null; then
    STORAGE_LIST=$(echo "$STORAGES" | jq -r '.data[].storage')

    for STORAGE in $STORAGE_LIST; do
        STORAGE_STATUS=$(curl -k -s --connect-timeout 10 \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/storage/${STORAGE}/status" 2>/dev/null)

        if echo "$STORAGE_STATUS" | jq -e '.data' &>/dev/null; then
            STOR_TYPE=$(echo "$STORAGE_STATUS" | jq -r '.data.type' 2>/dev/null || echo "N/A")
            STOR_TOTAL=$(echo "$STORAGE_STATUS" | jq -r '.data.total' 2>/dev/null || echo "0")
            STOR_USED=$(echo "$STORAGE_STATUS" | jq -r '.data.used' 2>/dev/null || echo "0")
            STOR_AVAIL=$(echo "$STORAGE_STATUS" | jq -r '.data.avail' 2>/dev/null || echo "0")
            STOR_ACTIVE=$(echo "$STORAGE_STATUS" | jq -r '.data.active' 2>/dev/null || echo "0")
            STOR_ENABLED=$(echo "$STORAGE_STATUS" | jq -r '.data.enabled' 2>/dev/null || echo "0")
            STOR_CONTENT=$(echo "$STORAGE_STATUS" | jq -r '.data.content' 2>/dev/null || echo "N/A")

            echo "  📦 Storage: $STORAGE"
            echo "    Type: $STOR_TYPE"
            echo "    Status: $([ "$STOR_ACTIVE" == "1" ] && echo "Active ✅" || echo "Inactive ❌")"
            echo "    Enabled: $([ "$STOR_ENABLED" == "1" ] && echo "Yes ✅" || echo "No ❌")"
            echo "    Content Types: $STOR_CONTENT"

            if [ "$STOR_TOTAL" != "0" ] && [ "$STOR_TOTAL" != "null" ]; then
                STOR_TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_TOTAL}/1024/1024/1024}")
                STOR_USED_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_USED}/1024/1024/1024}")
                STOR_AVAIL_GB=$(awk "BEGIN {printf \"%.2f\", ${STOR_AVAIL}/1024/1024/1024}")
                STOR_PERCENT=$(awk "BEGIN {printf \"%.2f%%\", (${STOR_USED}/${STOR_TOTAL})*100}")

                echo "    Total: ${STOR_TOTAL_GB} GB"
                echo "    Used: ${STOR_USED_GB} GB ($STOR_PERCENT)"
                echo "    Available: ${STOR_AVAIL_GB} GB"

                # Примеры VM
                VM_20GB=$(awk "BEGIN {printf \"%d\", ${STOR_AVAIL_GB}/20}")
                VM_50GB=$(awk "BEGIN {printf \"%d\", ${STOR_AVAIL_GB}/50}")
                VM_100GB=$(awk "BEGIN {printf \"%d\", ${STOR_AVAIL_GB}/100}")

                echo "    📊 Можно создать VM:"
                echo "      - 20GB диск: $VM_20GB VM"
                echo "      - 50GB диск: $VM_50GB VM"
                echo "      - 100GB диск: $VM_100GB VM"
            fi
            echo ""
        fi
    done
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. СЕТЬ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. СЕТЕВЫЕ ИНТЕРФЕЙСЫ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NETWORK=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/network" 2>/dev/null)

if echo "$NETWORK" | jq -e '.data' &>/dev/null; then
    # Все интерфейсы
    INTERFACES=$(echo "$NETWORK" | jq -r '.data[] | "\(.iface)|\(.type)|\(.active // "0")|\(.address // "N/A")|\(.gateway // "N/A")"')

    echo "$INTERFACES" | while IFS='|' read -r iface type active address gateway; do
        ACTIVE_STATUS=$([ "$active" == "1" ] && echo "Active ✅" || echo "Inactive")

        echo "  🌐 Interface: $iface"
        echo "    Type: $type"
        echo "    Status: $ACTIVE_STATUS"
        [ "$address" != "N/A" ] && echo "    IP: $address"
        [ "$gateway" != "N/A" ] && echo "    Gateway: $gateway"
        echo ""
    done
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. ТЕКУЩИЕ VM (если есть)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. ТЕКУЩИЕ ВИРТУАЛЬНЫЕ МАШИНЫ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VMS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu" 2>/dev/null)

VM_COUNT=$(echo "$VMS" | jq '.data | length' 2>/dev/null || echo "0")

if [ "$VM_COUNT" -eq 0 ]; then
    echo "  ✅ Нет VM - все ресурсы свободны"
else
    echo "  Количество VM: $VM_COUNT"
    echo ""

    # Подсчет использованных ресурсов
    TOTAL_VM_CPU=0
    TOTAL_VM_MEM=0

    echo "$VMS" | jq -r '.data[] | "\(.vmid)|\(.name)|\(.status)|\(.cpus)|\(.maxmem)|\(.maxdisk)"' | while IFS='|' read -r vmid name status cpus maxmem maxdisk; do
        MEM_GB=$(awk "BEGIN {printf \"%.1f\", ${maxmem}/1024/1024/1024}")
        DISK_GB=$(awk "BEGIN {printf \"%.1f\", ${maxdisk}/1024/1024/1024}")

        echo "  VM $vmid: $name"
        echo "    Status: $status"
        echo "    CPU: $cpus cores"
        echo "    RAM: ${MEM_GB} GB"
        echo "    Disk: ${DISK_GB} GB"
        echo ""
    done
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. ИТОГОВАЯ СВОДКА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. ИТОГОВАЯ СВОДКА РЕСУРСОВ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$CPU_COUNT" ] && [ -n "$MEM_FREE_GB" ]; then
    echo "  🖥️  Свободные Ресурсы:"
    echo "    CPU: $CPU_COUNT cores (загрузка: $CPU_PERCENT)"
    echo "    RAM: ${MEM_FREE_GB} GB свободно из ${MEM_TOTAL_GB} GB"
    echo ""

    echo "  📊 Рекомендации для новых VM:"
    echo ""
    echo "    Сценарий 1: Много маленьких VM (тестовые окружения)"
    echo "      → $(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/2}") VM × (1 CPU, 2GB RAM, 20GB disk)"
    echo ""
    echo "    Сценарий 2: Средние VM (dev/staging)"
    echo "      → $(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/4}") VM × (2 CPU, 4GB RAM, 50GB disk)"
    echo ""
    echo "    Сценарий 3: Крупные VM (production)"
    echo "      → $(awk "BEGIN {printf \"%d\", ${MEM_FREE_GB}/8}") VM × (4 CPU, 8GB RAM, 100GB disk)"
    echo ""
fi

# Uptime
if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
    UPTIME=$(echo "$NODE_STATUS" | jq -r '.data.uptime' 2>/dev/null || echo "0")
    if [ "$UPTIME" != "0" ]; then
        UPTIME_DAYS=$((UPTIME / 86400))
        UPTIME_HOURS=$(((UPTIME % 86400) / 3600))
        UPTIME_MINS=$(((UPTIME % 3600) / 60))
        echo "  ⏱️  System Uptime: ${UPTIME_DAYS} дней ${UPTIME_HOURS} часов ${UPTIME_MINS} минут"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Аудит завершен                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
