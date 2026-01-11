# 🚀 VM5 Enhanced Makefile
# Modern Make with Just-inspired syntax and features

.PHONY: help deploy quick-deploy test-ssh monitor health ssh clean
.DEFAULT_GOAL := help

# Colors
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

# Dynamic variables from terraform
VM_IP := $(shell terraform output -raw vm5_info 2>/dev/null | jq -r '.ip_address' 2>/dev/null || echo "192.168.88.150")
VM_NAME := $(shell terraform output -raw vm5_info 2>/dev/null | jq -r '.name' 2>/dev/null || echo "vm5-server")
SSH_USER := $(shell terraform output -raw vm5_info 2>/dev/null | jq -r '.username' 2>/dev/null || echo "devops")

help: ## Show all available commands
	@echo "$(BLUE)🚀 VM5 Enhanced - Modern Make Automation$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Current VM: $(VM_NAME) ($(VM_IP))$(NC)"

# ==================
# DEPLOYMENT
# ==================

deploy: ## Deploy VM5 infrastructure with validation
	@echo "$(BLUE)🚀 Deploying $(VM_NAME) infrastructure...$(NC)"
	@$(MAKE) validate
	terraform init
	terraform plan
	terraform apply
	@echo "$(GREEN)✅ $(VM_NAME) deployed successfully!$(NC)"

quick-deploy: ## Quick deployment without interactive prompts
	@echo "$(BLUE)⚡ Quick deploy $(VM_NAME) (auto-approve)...$(NC)"
	terraform init -upgrade
	terraform apply -auto-approve
	@echo "$(GREEN)🎯 Quick deployment completed!$(NC)"

plan: ## Plan infrastructure changes
	@echo "$(BLUE)📋 Planning $(VM_NAME) changes...$(NC)"
	terraform init
	terraform plan

validate: ## Validate all configurations
	@echo "$(BLUE)🔍 Validating VM5 configurations...$(NC)"
	terraform validate
	@echo "$(GREEN)✅ Terraform configuration valid$(NC)"

# ==================
# CONNECTION & SSH
# ==================

ssh: ## SSH into the VM
	@echo "$(BLUE)🔐 Connecting to $(VM_NAME) ($(VM_IP))...$(NC)"
	ssh $(SSH_USER)@$(VM_IP)

ssh-exec: ## Execute command on VM (usage: make ssh-exec CMD="command")
	@echo "$(BLUE)🔐 Executing on $(VM_NAME): $(CMD)$(NC)"
	ssh $(SSH_USER)@$(VM_IP) "$(CMD)"

test-ssh: ## Test SSH connectivity
	@echo "$(BLUE)🔐 Testing SSH connection to $(VM_IP)...$(NC)"
	@if ssh -o ConnectTimeout=5 -o BatchMode=yes $(SSH_USER)@$(VM_IP) 'echo "✅ SSH connection successful"' 2>/dev/null; then \
		echo "$(GREEN)✅ SSH test passed$(NC)"; \
	else \
		echo "$(RED)❌ SSH connection failed$(NC)"; \
		exit 1; \
	fi

# ==================
# MONITORING & HEALTH
# ==================

health: ## Check VM health and services
	@echo "$(BLUE)🔍 Checking $(VM_NAME) health...$(NC)"
	@echo "$(BLUE)📊 Network connectivity:$(NC)"
	@if ping -c 3 $(VM_IP) >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Network reachable$(NC)"; \
	else \
		echo "  $(RED)❌ Network unreachable$(NC)"; \
	fi
	@echo "$(BLUE)📊 SSH connectivity:$(NC)"
	@$(MAKE) test-ssh
	@echo "$(BLUE)📊 System services:$(NC)"
	@$(MAKE) ssh-exec CMD="systemctl --no-pager status docker qemu-guest-agent"

monitor: ## Monitor VM resources and services
	@echo "$(BLUE)📊 Monitoring $(VM_NAME) resources...$(NC)"
	@$(MAKE) ssh-exec CMD='echo "=== System Info ===" && uptime && echo && echo "=== Memory ===" && free -h && echo && echo "=== Disk ===" && df -h'

docker-status: ## Check Docker services status
	@echo "$(BLUE)🐳 Docker services on $(VM_NAME):$(NC)"
	@$(MAKE) ssh-exec CMD='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

monitor-all: health docker-status ## Complete monitoring for VM
	@echo "$(BLUE)📊 Monitoring URLs:$(NC)"
	@echo "  🎨 Grafana: http://$(VM_IP):3000"
	@echo "  📈 Prometheus: http://$(VM_IP):9090"
	@echo "  📊 Node Exporter: http://$(VM_IP):9100"

# ==================
# DOCKER & SERVICES
# ==================

compose-up: ## Start Docker Compose services
	@echo "$(BLUE)🐳 Starting Docker Compose services...$(NC)"
	@$(MAKE) ssh-exec CMD="cd monitoring && docker-compose up -d"

compose-down: ## Stop Docker Compose services
	@echo "$(BLUE)🐳 Stopping Docker Compose services...$(NC)"
	@$(MAKE) ssh-exec CMD="cd monitoring && docker-compose down"

compose-restart: ## Restart Docker Compose services
	@echo "$(BLUE)🐳 Restarting Docker Compose services...$(NC)"
	@$(MAKE) ssh-exec CMD="cd monitoring && docker-compose restart"

compose-logs: ## Show Docker Compose logs
	@echo "$(BLUE)🐳 Docker Compose logs:$(NC)"
	@$(MAKE) ssh-exec CMD="cd monitoring && docker-compose logs -f --tail=50"

restart-monitoring: compose-restart ## Restart monitoring stack
	@echo "$(GREEN)✅ Monitoring restarted!$(NC)"

check-monitoring: ## Check monitoring stack health
	@echo "$(BLUE)📊 Checking monitoring stack...$(NC)"
	@echo "$(BLUE)🎨 Grafana health:$(NC)"
	@if curl -s -o /dev/null -w "%{http_code}" http://$(VM_IP):3000 | grep -q "200"; then \
		echo "  $(GREEN)✅ Grafana accessible$(NC)"; \
	else \
		echo "  $(RED)❌ Grafana not accessible$(NC)"; \
	fi
	@echo "$(BLUE)📈 Prometheus health:$(NC)"
	@if curl -s http://$(VM_IP):9090/api/v1/status/config >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Prometheus API responding$(NC)"; \
	else \
		echo "  $(RED)❌ Prometheus not responding$(NC)"; \
	fi

# ==================
# TERRAFORM OPERATIONS
# ==================

info: ## Show VM information
	@echo "$(BLUE)📋 $(VM_NAME) Information:$(NC)"
	terraform output vm5_summary

outputs: ## Show all terraform outputs
	@echo "$(BLUE)📊 All VM5 outputs:$(NC)"
	terraform output

refresh: ## Refresh terraform state
	@echo "$(BLUE)🔄 Refreshing Terraform state...$(NC)"
	terraform refresh

# ==================
# MAINTENANCE
# ==================

destroy: ## Destroy VM infrastructure
	@echo "$(RED)🗑️  Destroying $(VM_NAME) infrastructure...$(NC)"
	@echo "$(YELLOW)⚠️  This will permanently delete the VM!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy; \
	else \
		echo "$(RED)❌ Destruction cancelled$(NC)"; \
	fi

recreate: destroy deploy test-full ## Recreate VM from scratch
	@echo "$(GREEN)✅ $(VM_NAME) recreated successfully!$(NC)"

clean: ## Clean terraform temporary files
	@echo "$(BLUE)🧹 Cleaning Terraform temporary files...$(NC)"
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

update-packages: ## Update VM packages
	@echo "$(BLUE)📦 Updating packages on $(VM_NAME)...$(NC)"
	@$(MAKE) ssh-exec CMD="sudo apt update && sudo apt upgrade -y"
	@echo "$(GREEN)✅ Packages updated$(NC)"

# ==================
# TESTING
# ==================

test-basic: ## Run basic connectivity tests
	@echo "$(BLUE)🧪 Basic connectivity tests...$(NC)"
	@echo "$(BLUE)📊 Network test:$(NC)"
	ping -c 3 $(VM_IP)
	@echo "$(BLUE)📊 SSH test:$(NC)"
	@$(MAKE) test-ssh
	@echo "$(GREEN)✅ Basic tests completed$(NC)"

test-full: test-basic health check-monitoring ## Run comprehensive tests
	@echo "$(GREEN)✅ Full test suite completed$(NC)"

benchmark: ## Run performance benchmark
	@echo "$(BLUE)⚡ Running performance benchmark...$(NC)"
	@$(MAKE) ssh-exec CMD='echo "=== CPU Info ===" && nproc && echo && echo "=== Memory Test ===" && free -h && echo && echo "=== Disk Speed ===" && sudo hdparm -t /dev/sda'

# ==================
# QUICK SHORTCUTS
# ==================

status: ## Quick status check
	@echo "$(BLUE)📊 $(VM_NAME) Status:$(NC)"
	@terraform output vm5_info 2>/dev/null || echo "$(RED)❌ VM not deployed$(NC)"

deploy-and-test: deploy test-full ## Deploy and test VM
	@echo "$(GREEN)🎉 $(VM_NAME) deployed and tested successfully!$(NC)"

config: ## Show current configuration
	@echo "$(BLUE)⚙️  Current VM5 configuration:$(NC)"
	@echo "  VM Name: $(VM_NAME)"
	@echo "  VM IP: $(VM_IP)"
	@echo "  SSH User: $(SSH_USER)"