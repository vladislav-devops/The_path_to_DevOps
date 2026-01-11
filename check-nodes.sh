#!/bin/bash
# Проверка доступных нод в Proxmox

PROXMOX_HOST="192.168.123.41"
PROXMOX_URL="https://${PROXMOX_HOST}:8006"

echo "Проверка доступных нод в Proxmox..."
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

# Получаем список нод
NODES=$(curl -k -s --connect-timeout 10 \
    -H "Cookie: PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    "${PROXMOX_URL}/api2/json/nodes" 2>/dev/null)

echo "Доступные ноды:"
echo "$NODES" | jq -r '.data[] | "  \(.node) - Статус: \(.status) - CPU: \(.cpu*100|floor)% - Память: \(.mem/1024/1024/1024|floor)GB/\(.maxmem/1024/1024/1024|floor)GB"' 2>/dev/null

echo ""
echo "Список имен нод:"
echo "$NODES" | jq -r '.data[].node' 2>/dev/null

echo ""
echo "Текущая конфигурация проектов использует ноду:"
grep "proxmox_node" vm4/main.tf vm5/variables.tf 2>/dev/null | grep -v "#"
