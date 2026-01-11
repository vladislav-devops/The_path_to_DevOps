#!/bin/bash
# Простая проверка готовности к развертыванию VM4 и VM5

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Проверка готовности к развертыванию VM4 и VM5                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

PROXMOX_HOST="192.168.123.41"
PROXMOX_PORT="8006"

# 1. Проверка зависимостей
echo "━━━ 1. Зависимости ━━━"
command -v terraform >/dev/null 2>&1 && echo "✅ Terraform: $(terraform version 2>&1 | head -1)" || echo "❌ Terraform не установлен"
command -v curl >/dev/null 2>&1 && echo "✅ curl установлен" || echo "❌ curl не установлен"
command -v jq >/dev/null 2>&1 && echo "✅ jq установлен" || echo "⚠️  jq не установлен (опционально)"
command -v ssh >/dev/null 2>&1 && echo "✅ SSH установлен" || echo "❌ SSH не установлен"
echo ""

# 2. Проверка Proxmox подключения
echo "━━━ 2. Proxmox подключение ━━━"
echo "Проверка хоста: $PROXMOX_HOST"

if ping -c 1 -W 2 "$PROXMOX_HOST" >/dev/null 2>&1; then
    echo "✅ Proxmox хост доступен"
else
    echo "❌ Proxmox хост недоступен"
fi

if timeout 3 bash -c "echo >/dev/tcp/${PROXMOX_HOST}/${PROXMOX_PORT}" 2>/dev/null; then
    echo "✅ Proxmox API порт ${PROXMOX_PORT} открыт"
else
    echo "❌ Proxmox API порт ${PROXMOX_PORT} недоступен"
fi

if curl -k -s --connect-timeout 5 "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/version" >/dev/null 2>&1; then
    echo "✅ Proxmox API HTTPS доступен"
else
    echo "❌ Proxmox API HTTPS недоступен"
fi
echo ""

# 3. Проверка учетных данных
echo "━━━ 3. Учетные данные ━━━"

# Читаем пароль из vm4/terraform.tfvars
if [ -f "vm4/terraform.tfvars" ]; then
    PROXMOX_PASSWORD=$(grep "^proxmox_password" vm4/terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/')
    if [ -n "$PROXMOX_PASSWORD" ]; then
        echo "✅ Пароль Proxmox найден в vm4/terraform.tfvars: '$PROXMOX_PASSWORD'"

        # Проверка аутентификации
        AUTH_RESPONSE=$(curl -k -s --connect-timeout 10 \
            --data-urlencode "username=root@pam" \
            --data-urlencode "password=${PROXMOX_PASSWORD}" \
            "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/access/ticket" 2>/dev/null)

        if echo "$AUTH_RESPONSE" | grep -q "ticket"; then
            echo "✅ Аутентификация успешна (root@pam)"
        else
            echo "❌ Ошибка аутентификации - проверьте пароль"
        fi
    else
        echo "⚠️  Пароль не найден в terraform.tfvars"
    fi
else
    echo "❌ Файл vm4/terraform.tfvars не найден"
fi
echo ""

# 4. Сетевые настройки
echo "━━━ 4. Сетевые параметры ━━━"
echo "Gateway: 192.168.123.1"
if ping -c 1 -W 2 192.168.123.1 >/dev/null 2>&1; then
    echo "✅ Gateway 192.168.123.1 доступен"
else
    echo "⚠️  Gateway 192.168.123.1 недоступен"
fi

echo "VM4 IP: 192.168.123.140"
if ping -c 1 -W 1 192.168.123.140 >/dev/null 2>&1; then
    echo "⚠️  IP 192.168.123.140 уже занят"
else
    echo "✅ IP 192.168.123.140 свободен"
fi

echo "VM5 IP: 192.168.123.150"
if ping -c 1 -W 1 192.168.123.150 >/dev/null 2>&1; then
    echo "⚠️  IP 192.168.123.150 уже занят"
else
    echo "✅ IP 192.168.123.150 свободен"
fi
echo ""

# 5. SSH ключи
echo "━━━ 5. SSH ключи ━━━"
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    echo "✅ SSH ключ найден: ~/.ssh/id_rsa.pub"
    head -c 60 "$HOME/.ssh/id_rsa.pub"
    echo "..."
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo "✅ SSH ключ найден: ~/.ssh/id_ed25519.pub"
    head -c 60 "$HOME/.ssh/id_ed25519.pub"
    echo "..."
else
    echo "⚠️  SSH ключ не найден - создайте: ssh-keygen -t rsa -b 4096"
fi

# Проверка в конфигах
for project in vm4 vm5; do
    if [ -f "$project/terraform.tfvars" ]; then
        if grep -q "ssh_public_key" "$project/terraform.tfvars"; then
            echo "✅ SSH ключ настроен в $project/terraform.tfvars"
        else
            echo "❌ SSH ключ НЕ настроен в $project/terraform.tfvars"
        fi
    fi
done
echo ""

# 6. Terraform конфигурация
echo "━━━ 6. Terraform конфигурация ━━━"
for project in vm4 vm5; do
    echo "Проект: $project"
    [ -f "$project/main.tf" ] && echo "  ✅ main.tf" || echo "  ❌ main.tf отсутствует"
    [ -f "$project/terraform.tfvars" ] && echo "  ✅ terraform.tfvars" || echo "  ❌ terraform.tfvars отсутствует"

    if [ -d "$project" ]; then
        cd "$project" || continue
        if [ -d ".terraform" ]; then
            echo "  ✅ Terraform инициализирован"
        else
            echo "  ⚠️  Требуется: terraform init"
        fi
        cd .. || exit
    fi
done
echo ""

# 7. Интернет доступ
echo "━━━ 7. Доступ к интернету ━━━"
if curl -s --connect-timeout 5 -I "https://cloud-images.ubuntu.com" 2>&1 | grep -q "200\|301\|302"; then
    echo "✅ Доступ к Ubuntu Cloud Images"
else
    echo "⚠️  Нет доступа к Ubuntu Cloud Images"
fi
echo ""

# 8. Конфигурация проектов
echo "━━━ 8. Параметры проектов ━━━"
echo "VM4:"
[ -f "vm4/terraform.tfvars" ] && grep -E "^(vm_ip|vm_cores|vm_memory|proxmox_password)" vm4/terraform.tfvars 2>/dev/null | sed 's/^/  /'
echo ""
echo "VM5:"
[ -f "vm5/terraform.tfvars" ] && grep -E "^(vm_ip|vm_cores|vm_memory|proxmox_password)" vm5/terraform.tfvars 2>/dev/null | sed 's/^/  /'
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ИТОГ                                                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Следующие шаги для развертывания:"
echo "  1. cd vm4 && terraform init"
echo "  2. cd vm4 && terraform plan"
echo "  3. cd vm4 && terraform apply"
echo ""
echo "  Или для vm5:"
echo "  1. cd vm5 && terraform init"
echo "  2. cd vm5 && terraform plan"
echo "  3. cd vm5 && terraform apply"
echo ""
