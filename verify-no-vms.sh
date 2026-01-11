#!/bin/bash
# Финальная проверка что VM удалены

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"
NODE_NAME="pve01"

echo "🔍 Финальная проверка состояния Proxmox..."
echo ""

# Читаем пароль
if [ -f "vm4/terraform.tfvars" ]; then
    PROXMOX_PASSWORD=$(grep "^proxmox_password" vm4/terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/')
fi

# Получаем токен
AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
    --data-urlencode "username=root@pam" \
    --data-urlencode "password=${PROXMOX_PASSWORD}" \
    "${PROXMOX_URL}/api2/json/access/ticket" 2>/dev/null)

TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket' 2>/dev/null)
CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken' 2>/dev/null)

# Получаем список VM
VMS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu" 2>/dev/null)

VM_COUNT=$(echo "$VMS" | jq '.data | length' 2>/dev/null || echo "0")

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  СТАТУС PROXMOX ПОСЛЕ УДАЛЕНИЯ                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Нода: $NODE_NAME"
echo "  Количество VM: $VM_COUNT"
echo ""

if [ "$VM_COUNT" -eq 0 ]; then
    echo "✅ Успех! Все виртуальные машины удалены"
    echo ""
    echo "Proxmox сервер чист и готов к новым развертываниям:"
    echo "  - cd vm4 && terraform apply  # Развернуть VM4"
    echo "  - cd vm5 && terraform apply  # Развернуть VM5"
else
    echo "⚠️  Найдено VM: $VM_COUNT"
    echo ""
    echo "Список оставшихся VM:"
    echo "$VMS" | jq -r '.data[] | "  - VM \(.vmid): \(.name) (\(.status)) - \(.maxmem/1024/1024/1024|floor)GB RAM, \(.cpus) CPU"'
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Ресурсы Proxmox                                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Получаем статус ноды
NODE_STATUS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/status" 2>/dev/null)

if echo "$NODE_STATUS" | jq -e '.data' &>/dev/null; then
    CPU_USAGE=$(echo "$NODE_STATUS" | jq -r '.data.cpu' 2>/dev/null || echo "0")
    MEM_TOTAL=$(echo "$NODE_STATUS" | jq -r '.data.memory.total' 2>/dev/null || echo "0")
    MEM_USED=$(echo "$NODE_STATUS" | jq -r '.data.memory.used' 2>/dev/null || echo "0")
    MEM_FREE=$(echo "$NODE_STATUS" | jq -r '.data.memory.free' 2>/dev/null || echo "0")

    if [ "$MEM_TOTAL" != "0" ]; then
        MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", ${MEM_TOTAL}/1024/1024/1024}")
        MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", ${MEM_USED}/1024/1024/1024}")
        MEM_FREE_GB=$(awk "BEGIN {printf \"%.1f\", ${MEM_FREE}/1024/1024/1024}")
        CPU_PERCENT=$(awk "BEGIN {printf \"%.1f%%\", ${CPU_USAGE}*100}")

        echo "  CPU:"
        echo "    Загрузка: $CPU_PERCENT"
        echo ""
        echo "  Память:"
        echo "    Всего: ${MEM_TOTAL_GB} GB"
        echo "    Использовано: ${MEM_USED_GB} GB"
        echo "    Свободно: ${MEM_FREE_GB} GB"
        echo ""
        echo "  ✅ Доступно для новых VM:"
        echo "    - Можно развернуть VM4 (4GB RAM, 2 CPU)"
        echo "    - Можно развернуть VM5 (4GB RAM, 2 CPU)"
        echo "    - Свободно памяти: ${MEM_FREE_GB}GB"
    fi
fi

echo ""
