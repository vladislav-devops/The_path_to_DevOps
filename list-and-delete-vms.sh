#!/bin/bash
# Скрипт для проверки и удаления всех VM в Proxmox

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"
NODE_NAME="pve01"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Проверка и удаление VM в Proxmox                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Читаем пароль
if [ -f "vm4/terraform.tfvars" ]; then
    PROXMOX_PASSWORD=$(grep "^proxmox_password" vm4/terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/')
fi

if [ -z "$PROXMOX_PASSWORD" ]; then
    echo "❌ Пароль не найден"
    exit 1
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

echo "✅ Аутентификация успешна"
echo ""

# Получаем список всех VM
echo "📋 Получение списка VM..."
VMS=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu" 2>/dev/null)

echo "Список всех VM на ноде ${NODE_NAME}:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! echo "$VMS" | jq -e '.data' &>/dev/null; then
    echo "⚠️  Нет VM или ошибка получения списка"
    exit 0
fi

VM_COUNT=$(echo "$VMS" | jq '.data | length')

if [ "$VM_COUNT" -eq 0 ]; then
    echo "✅ VM не найдено - ничего удалять не нужно"
    exit 0
fi

echo "Найдено VM: $VM_COUNT"
echo ""

# Показываем таблицу VM
echo "$VMS" | jq -r '.data[] | "\(.vmid)\t\(.name)\t\(.status)\t\(.maxmem/1024/1024/1024|floor)GB RAM\t\(.cpus) CPU"' | while IFS=$'\t' read -r vmid name status mem cpu; do
    echo "  VM ID: $vmid"
    echo "    Имя: $name"
    echo "    Статус: $status"
    echo "    Память: $mem"
    echo "    CPU: $cpu"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Спрашиваем подтверждение
read -p "❓ Удалить ВСЕ эти VM? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Удаление отменено"
    exit 0
fi

echo ""
echo "🗑️  Начинаем удаление VM..."
echo ""

# Получаем список VM ID
VM_IDS=$(echo "$VMS" | jq -r '.data[].vmid')

for VMID in $VM_IDS; do
    echo "━━━ Удаление VM $VMID ━━━"

    # Получаем информацию о VM
    VM_INFO=$(curl -k -s --connect-timeout 10 \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/current" 2>/dev/null)

    VM_NAME=$(echo "$VM_INFO" | jq -r '.data.name' 2>/dev/null || echo "unknown")
    VM_STATUS=$(echo "$VM_INFO" | jq -r '.data.status' 2>/dev/null || echo "unknown")

    echo "  Имя: $VM_NAME"
    echo "  Статус: $VM_STATUS"

    # Если VM запущена - останавливаем
    if [ "$VM_STATUS" == "running" ]; then
        echo "  ⏹️  Остановка VM..."
        STOP_RESPONSE=$(curl -k -s --connect-timeout 30 \
            -X POST \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/stop" 2>/dev/null)

        # Ждем остановки
        echo "  ⏳ Ожидание остановки..."
        for i in {1..30}; do
            sleep 2
            STATUS=$(curl -k -s --connect-timeout 10 \
                -H "Cookie: PVEAuthCookie=${TICKET}" \
                -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
                "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/current" 2>/dev/null | jq -r '.data.status')

            if [ "$STATUS" == "stopped" ]; then
                echo "  ✅ VM остановлена"
                break
            fi

            if [ $i -eq 30 ]; then
                echo "  ⚠️  VM не остановилась за 60 секунд, пытаемся удалить принудительно"
            fi
        done
    fi

    # Удаляем VM
    echo "  🗑️  Удаление VM $VMID..."
    DELETE_RESPONSE=$(curl -k -s --connect-timeout 30 \
        -X DELETE \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}?purge=1" 2>/dev/null)

    if echo "$DELETE_RESPONSE" | jq -e '.data' &>/dev/null; then
        echo "  ✅ VM $VMID ($VM_NAME) успешно удалена"
    else
        echo "  ❌ Ошибка удаления VM $VMID"
        echo "$DELETE_RESPONSE" | jq '.' 2>/dev/null || echo "$DELETE_RESPONSE"
    fi

    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверяем результат
echo "🔍 Проверка результата..."
sleep 3

VMS_AFTER=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu" 2>/dev/null)

VM_COUNT_AFTER=$(echo "$VMS_AFTER" | jq '.data | length' 2>/dev/null || echo "0")

echo ""
echo "Результат:"
echo "  До удаления: $VM_COUNT VM"
echo "  После удаления: $VM_COUNT_AFTER VM"
echo ""

if [ "$VM_COUNT_AFTER" -eq 0 ]; then
    echo "✅ Все VM успешно удалены!"
else
    echo "⚠️  Осталось VM: $VM_COUNT_AFTER"
    echo ""
    echo "Оставшиеся VM:"
    echo "$VMS_AFTER" | jq -r '.data[] | "  - VM \(.vmid): \(.name) (\(.status))"'
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Операция завершена                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
