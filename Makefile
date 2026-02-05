INV := inventory/local.yml
A := -i $(INV) $(if $(NODE),--limit $(NODE),)
G := \033[32m
N := \033[0m

.DEFAULT_GOAL := help
.PHONY: deploy register upgrade snapshot execution otel health status sync logs restart backup cleanup recovery diagnose ping ssh info check vault-edit vault-encrypt vault-decrypt help

# Deployment
deploy: ## Deploy validators [NODE=]
	ansible-playbook $(A) playbooks/deploy-validator.yml

register: ## Register validator [NODE=]
	ansible-playbook $(A) playbooks/register-validator.yml

upgrade: ## Upgrade packages [NODE=]
	ansible-playbook $(A) playbooks/upgrade-node.yml

snapshot: ## Apply snapshot [NODE=]
	ansible-playbook $(A) playbooks/snapshot.yml

execution: ## Setup execution [NODE=]
	ansible-playbook $(A) playbooks/setup-execution.yml

otel: ## Setup OpenTelemetry [NODE=]
	ansible-playbook $(A) playbooks/setup-otel.yml

# Monitoring
health: ## Health checks [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags health

status: ## Service status [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags status

sync: ## Sync progress [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags sync

logs: ## View logs [NODE=]
	ansible $(A) validators -m shell -a "tail -50 /opt/monad-consensus/log/monad-consensus.log"

# Operations
restart: ## Restart service [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags restart

backup: ## Backup keys [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags backup

cleanup: ## Cleanup backups [NODE=]
	ansible-playbook $(A) playbooks/maintenance.yml --tags cleanup

# Recovery
recovery: ## Full recovery [NODE=]
	ansible-playbook $(A) playbooks/recovery.yml

diagnose: ## Diagnostic info [NODE=]
	ansible-playbook $(A) playbooks/recovery.yml --tags diagnose

# Utilities
ping: ## Test connectivity [NODE=]
	ansible $(A) all -m ping

ssh: ## SSH to validator [ENV=] [NODE=]
	@./scripts/get-host.sh "$(ENV)" "$(NODE)" | xargs -I {} ssh root@{}

info: ## Show validator info [ENV=] [NODE=]
	@./scripts/validator-info.sh "$(ENV)" "$(NODE)"

check: ## Syntax check
	ansible-playbook $(A) playbooks/deploy-validator.yml --syntax-check

# Vault
vault-edit: ## Edit vault
	ansible-vault edit group_vars/vault.yml

vault-encrypt: ## Encrypt vault
	ansible-vault encrypt group_vars/vault.yml

vault-decrypt: ## Decrypt vault
	ansible-vault decrypt group_vars/vault.yml

# Help
help: ## Show targets
	@echo "Monad Validator Manager"
	@echo ""
	@echo "Usage: make <target> [NODE=name] [ENV=testnet|mainnet]"
	@echo ""
	@awk 'BEGIN {FS=":.*##"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  $(G)%-14s$(N) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
