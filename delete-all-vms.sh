#!/bin/bash
# Автоматическое удаление ВСЕХ VM в Proxmox

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"
NODE_NAME="pve01"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  АВТОМАТИЧЕСКОЕ УДАЛЕНИЕ ВСЕХ VM                               ║"
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

if ! echo "$VMS" | jq -e '.data' &>/dev/null; then
    echo "⚠️  Нет VM или ошибка получения списка"
    exit 0
fi

VM_COUNT=$(echo "$VMS" | jq '.data | length')

if [ "$VM_COUNT" -eq 0 ]; then
    echo "✅ VM не найдено - ничего удалять не нужно"
    exit 0
fi

echo "Найдено VM для удаления: $VM_COUNT"
echo ""

# Получаем список VM ID
VM_IDS=$(echo "$VMS" | jq -r '.data[].vmid')

SUCCESS_COUNT=0
FAIL_COUNT=0

for VMID in $VM_IDS; do
    echo "━━━ Обработка VM $VMID ━━━"

    # Получаем информацию о VM
    VM_INFO=$(curl -k -s --connect-timeout 10 \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/current" 2>/dev/null)

    VM_NAME=$(echo "$VM_INFO" | jq -r '.data.name' 2>/dev/null || echo "unknown")
    VM_STATUS=$(echo "$VM_INFO" | jq -r '.data.status' 2>/dev/null || echo "unknown")

    echo "  VM: $VMID - $VM_NAME (статус: $VM_STATUS)"

    # Если VM запущена - останавливаем
    if [ "$VM_STATUS" == "running" ]; then
        echo "  ⏹️  Остановка VM..."
        curl -k -s --connect-timeout 30 \
            -X POST \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/stop" >/dev/null 2>&1

        # Ждем остановки (максимум 60 секунд)
        echo "  ⏳ Ожидание остановки (макс. 60 сек)..."
        for i in {1..30}; do
            sleep 2
            STATUS=$(curl -k -s --connect-timeout 10 \
                -H "Cookie: PVEAuthCookie=${TICKET}" \
                -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
                "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}/status/current" 2>/dev/null | jq -r '.data.status' 2>/dev/null)

            if [ "$STATUS" == "stopped" ]; then
                echo "  ✅ VM остановлена"
                break
            fi

            if [ $i -eq 30 ]; then
                echo "  ⚠️  Таймаут остановки, пытаемся удалить принудительно"
            fi
        done
    fi

    # Удаляем VM (с purge для полного удаления дисков)
    echo "  🗑️  Удаление VM..."
    DELETE_RESPONSE=$(curl -k -s --connect-timeout 60 \
        -X DELETE \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu/${VMID}?purge=1" 2>/dev/null)

    # Проверяем результат
    if echo "$DELETE_RESPONSE" | jq -e '.data' &>/dev/null; then
        echo "  ✅ VM $VMID ($VM_NAME) успешно удалена"
        ((SUCCESS_COUNT++))
    else
        ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.errors // empty' 2>/dev/null)
        if [ -n "$ERROR_MSG" ]; then
            echo "  ❌ Ошибка: $ERROR_MSG"
        else
            echo "  ❌ Ошибка удаления VM $VMID"
        fi
        ((FAIL_COUNT++))
    fi

    echo ""

    # Небольшая пауза между удалениями
    sleep 1
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверяем результат
echo "🔍 Финальная проверка..."
sleep 5

VMS_AFTER=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes/${NODE_NAME}/qemu" 2>/dev/null)

VM_COUNT_AFTER=$(echo "$VMS_AFTER" | jq '.data | length' 2>/dev/null || echo "0")

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  РЕЗУЛЬТАТ УДАЛЕНИЯ                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Было VM: $VM_COUNT"
echo "  Осталось VM: $VM_COUNT_AFTER"
echo ""
echo "  ✅ Успешно удалено: $SUCCESS_COUNT"
echo "  ❌ Ошибок: $FAIL_COUNT"
echo ""

if [ "$VM_COUNT_AFTER" -eq 0 ]; then
    echo "🎉 Все VM успешно удалены!"
    echo ""
else
    echo "⚠️  Внимание: осталось VM: $VM_COUNT_AFTER"
    echo ""
    echo "Оставшиеся VM:"
    echo "$VMS_AFTER" | jq -r '.data[] | "  - VM \(.vmid): \(.name) (\(.status))"' 2>/dev/null
    echo ""
    echo "Возможные причины:"
    echo "  - VM заблокирована задачей"
    echo "  - Недостаточно прав"
    echo "  - VM используется другим процессом"
    echo ""
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Операция завершена                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
