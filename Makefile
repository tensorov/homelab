ANSIBLE_DIR := ansible
PLAYBOOKS   := $(ANSIBLE_DIR)/playbooks
VAULT_ARG   := $(shell [ -f $(ANSIBLE_DIR)/vault-password ] && echo "--vault-password-file $(ANSIBLE_DIR)/vault-password")

.PHONY: lint deploy backup update health shellcheck pre-commit all

all: lint

# ── Lint ────────────────────────────────────────────

lint: pre-commit ansible-lint yamllint shellcheck

pre-commit:
	pre-commit run --all-files

ansible-lint:
	cd $(ANSIBLE_DIR) && ansible-lint

yamllint:
	cd $(ANSIBLE_DIR) && yamllint --strict .

shellcheck:
	@echo "--- shellcheck ---"
	@find $(ANSIBLE_DIR) -name '*.sh' -not -path '*/vendor/*' -exec shellcheck {} + || true

# ── Ansible ─────────────────────────────────────────

deploy:
	ansible-playbook $(PLAYBOOKS)/deploy.yml $(VAULT_ARG)

update:
	ansible-playbook $(PLAYBOOKS)/update.yml $(VAULT_ARG)

backup:
	ansible-playbook $(PLAYBOOKS)/backup.yml $(VAULT_ARG)

restore:
	ansible-playbook $(PLAYBOOKS)/restore.yml $(VAULT_ARG)

rotate-secrets:
	ansible-playbook $(PLAYBOOKS)/rotate-secrets.yml $(VAULT_ARG)

health:
	ansible-playbook $(PLAYBOOKS)/health.yml

bootstrap:
	ansible-playbook $(PLAYBOOKS)/bootstrap.yml $(VAULT_ARG)

# ── Syntax check all ────────────────────────────────

syntax-check:
	@for pb in $(PLAYBOOKS)/*.yml; do \
		echo "=== $$pb ==="; \
		ansible-playbook --syntax-check $$pb; \
	done
