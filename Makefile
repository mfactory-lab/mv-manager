VAULT_ARGS ?= --ask-vault-pass

.PHONY: deploy register upgrade health status sync restart backup cleanup recovery diagnose vault-edit vault-encrypt ping

deploy:
	ansible-playbook playbooks/deploy-validator.yml $(VAULT_ARGS)

register:
	ansible-playbook playbooks/register-validator.yml $(VAULT_ARGS)

upgrade:
	ansible-playbook playbooks/upgrade-node.yml $(VAULT_ARGS)

health:
	ansible-playbook playbooks/maintenance.yml --tags health $(VAULT_ARGS)

status:
	ansible-playbook playbooks/maintenance.yml --tags status $(VAULT_ARGS)

sync:
	ansible-playbook playbooks/maintenance.yml --tags sync $(VAULT_ARGS)

restart:
	ansible-playbook playbooks/maintenance.yml --tags restart $(VAULT_ARGS)

backup:
	ansible-playbook playbooks/maintenance.yml --tags backup $(VAULT_ARGS)

cleanup:
	ansible-playbook playbooks/maintenance.yml --tags cleanup $(VAULT_ARGS)

recovery:
	ansible-playbook playbooks/recovery.yml $(VAULT_ARGS)

diagnose:
	ansible-playbook playbooks/recovery.yml --tags diagnose $(VAULT_ARGS)

vault-edit:
	ansible-vault edit group_vars/vault.yml

vault-encrypt:
	ansible-vault encrypt group_vars/vault.yml

ping:
	ansible all -m ping $(VAULT_ARGS)
