INV := inventory/local.yml
VAULT_ARGS ?=
INV_ARG := -i $(INV)
.DEFAULT_GOAL := help
G := \033[32m
N := \033[0m

.PHONY: deploy register upgrade snapshot execution otel health status sync monitor logs restart backup cleanup recovery diagnose ping ssh info check vault-edit vault-encrypt vault-decrypt help

# Deployment
deploy: ## Full validator deployment
	ansible-playbook $(INV_ARG) playbooks/deploy-validator.yml $(VAULT_ARGS)

register: ## Register validator (requires synced node + 100k MON)
	ansible-playbook $(INV_ARG) playbooks/register-validator.yml $(VAULT_ARGS)

upgrade: ## Upgrade monad packages
	ansible-playbook $(INV_ARG) playbooks/upgrade-node.yml $(VAULT_ARGS)

snapshot: ## Download and apply latest snapshot
	ansible-playbook $(INV_ARG) playbooks/snapshot.yml $(VAULT_ARGS)

execution: ## Setup execution layer (separate from consensus)
	ansible-playbook $(INV_ARG) playbooks/setup-execution.yml $(VAULT_ARGS)

otel: ## Setup OpenTelemetry collector for metrics export
	ansible-playbook $(INV_ARG) playbooks/setup-otel.yml $(VAULT_ARGS)

# Monitoring
health: ## Run health checks
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags health $(VAULT_ARGS)

status: ## Show service status and disk usage
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags status $(VAULT_ARGS)

sync: ## Check node sync progress
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags sync $(VAULT_ARGS)

watch: ## Watch sync progress in real-time
	@ssh root@$$(ansible-inventory $(INV_ARG) --list 2>/dev/null | jq -r '._meta.hostvars | to_entries | map(select(.value.type == "validator")) | .[0].value.ansible_host') "tail -f /opt/monad-consensus/log/monad-consensus.log | grep --line-buffered -E 'round|block|commit|sync|statesync'"

logs: ## View recent logs (last 50 lines)
	@ansible $(INV_ARG) validators -m shell -a "tail -50 /opt/monad-consensus/log/monad-consensus.log" $(VAULT_ARGS)

# Operations
restart: ## Restart monad service
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags restart $(VAULT_ARGS)

backup: ## Backup config and keys
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags backup $(VAULT_ARGS)

cleanup: ## Cleanup old backups
	ansible-playbook $(INV_ARG) playbooks/maintenance.yml --tags cleanup $(VAULT_ARGS)

# Recovery
recovery: ## Full recovery procedure
	ansible-playbook $(INV_ARG) playbooks/recovery.yml $(VAULT_ARGS)

diagnose: ## Show diagnostic info (service status, errors)
	ansible-playbook $(INV_ARG) playbooks/recovery.yml --tags diagnose $(VAULT_ARGS)

# Utilities
ping: ## Test connectivity to all hosts
	ansible $(INV_ARG) all -m ping $(VAULT_ARGS)

ssh: ## SSH to first validator
	@ssh root@$$(ansible-inventory $(INV_ARG) --list 2>/dev/null | jq -r '._meta.hostvars | to_entries | map(select(.value.type == "validator")) | .[0].value.ansible_host')

info: ## Show validators info [ENV=testnet|mainnet] [NODE=name]
	@./scripts/validator-info.sh "$(ENV)" "$(NODE)"

check: ## Syntax check playbooks
	ansible-playbook $(INV_ARG) playbooks/deploy-validator.yml --syntax-check

# Vault
vault-edit: ## Edit encrypted vault
	ansible-vault edit group_vars/vault.yml

vault-encrypt: ## Encrypt vault file
	ansible-vault encrypt group_vars/vault.yml

vault-decrypt: ## Decrypt vault file
	ansible-vault decrypt group_vars/vault.yml

# ------------------------------------------------------------------------

help: ## Show available targets
	@echo "Monad Validator Manager"
	@echo ""
	@echo "Usage: make <target> [INV=inventory/local.yml]"
	@echo ""
	@awk 'BEGIN {FS=":.*##"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  $(G)%-16s$(N) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
