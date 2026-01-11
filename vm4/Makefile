# 🚀 VM4 Makefile для автоматизации развертывания и тестирования

.PHONY: help init plan apply destroy test-ssh test-ping clean status deploy-and-test

# Цвета для вывода
GREEN := \033[32m
BLUE := \033[34m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

help: ## Показать справку
	@echo "$(BLUE)🚀 VM4 - Управление виртуальной машиной$(NC)"
	@echo ""
	@echo "$(GREEN)Доступные команды:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

init: ## Инициализировать Terraform
	@echo "$(BLUE)🔧 Инициализация Terraform...$(NC)"
	terraform init

plan: ## Показать план развертывания
	@echo "$(BLUE)📋 Планирование развертывания...$(NC)"
	terraform plan

apply: ## Развернуть VM
	@echo "$(BLUE)🚀 Развертывание VM4...$(NC)"
	terraform apply -auto-approve
	@echo "$(GREEN)✅ VM4 развернута!$(NC)"

test-ping: ## Тест доступности по сети
	@echo "$(BLUE)🏓 Тестирование доступности...$(NC)"
	@VM_IP=$$(terraform output -raw vm4_info 2>/dev/null | jq -r '.ip_address' 2>/dev/null || echo "192.168.88.140"); \
	if ping -c 3 $$VM_IP > /dev/null 2>&1; then \
		echo "$(GREEN)✅ VM доступна по адресу $$VM_IP$(NC)"; \
	else \
		echo "$(RED)❌ VM недоступна по адресу $$VM_IP$(NC)"; \
		exit 1; \
	fi

test-ssh: ## Полное SSH тестирование
	@echo "$(BLUE)🔐 SSH тестирование...$(NC)"
	./test-ssh.sh

status: ## Показать статус VM
	@echo "$(BLUE)📊 Статус VM4:$(NC)"
	@terraform output vm4_info 2>/dev/null || echo "$(YELLOW)VM не развернута$(NC)"

deploy-and-test: init apply test-ping test-ssh ## Полный цикл: развертывание и тестирование
	@echo "$(GREEN)🎉 Развертывание и тестирование завершено!$(NC)"

destroy: ## Удалить VM
	@echo "$(RED)🗑️  Удаление VM4...$(NC)"
	terraform destroy -auto-approve
	@echo "$(YELLOW)VM4 удалена$(NC)"

clean: ## Очистить временные файлы Terraform
	@echo "$(BLUE)🧹 Очистка временных файлов...$(NC)"
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

# Быстрые команды
quick-deploy: apply test-ping ## Быстрое развертывание с базовой проверкой
	@echo "$(GREEN)⚡ Быстрое развертывание завершено!$(NC)"

recreate: destroy deploy-and-test ## Пересоздать VM с полным тестированием
	@echo "$(GREEN)🔄 VM пересоздана и протестирована!$(NC)"