# home-datacenter

Infrastructure-as-Code for zeitoven.ru's homelab datacenter.

Ansible-managed deployment for `/opt/services/`.

## Structure

```
.github/workflows/lint.yml    # CI — ansible-lint + yamllint на push/PR
.pre-commit-config.yaml        # pre-commit хуки
ansible/
├── ansible.cfg
├── .ansible-lint              # ansible-lint конфиг
├── .yamllint                  # yamllint конфиг
├── requirements.yml
├── vault-password             # vault password (gitignored)
├── group_vars/all/
│   ├── vars.yml               # non-secret variables
│   └── vault.yml              # encrypted secrets (ansible-vault)
├── inventories/
│   └── production/hosts.yml   # production inventory
├── roles/
│   ├── common/                # base: packages, Docker, UFW, sysctl
│   ├── traefik/               # reverse proxy with 17+ dynamic config templates
│   ├── authentik/             # identity provider (server + worker + postgres + redis)
│   ├── gitlab/                # git + CI/CD (ce + postgres + redis + runner)
│   ├── matrix/                # synapse + element + sliding-sync + bridges
│   ├── supabase/              # postgres + auth + storage + realtime
│   └── services/              # searxng, mirotalk, jupyter, smtp, opencode-webhook, opencode-web
└── playbooks/
    ├── bootstrap.yml          # initial provisioning
    ├── deploy.yml             # full stack deployment (tag-selectable)
    ├── update.yml             # pull latest images + restart
    ├── backup.yml             # database dumps + restic remote sync
    └── health.yml             # health checks
```

## Quick Start

```bash
cd ansible

# 1. Set vault password
echo "your-secret" > vault-password
chmod 600 vault-password

# 2. Encrypt secrets from vault.yml.sample
ansible-vault encrypt group_vars/all/vault.yml

# 3. Bootstrap (first run on a fresh host)
ansible-playbook playbooks/bootstrap.yml

# 4. Deploy full stack
ansible-playbook playbooks/deploy.yml
```

Or deploy specific roles by tag:

```bash
ansible-playbook playbooks/deploy.yml --tags traefik,authentik
```

## Tags

| Tag | Description |
|-----|-------------|
| `base` | Traefik + Authentik |
| `devops` | GitLab |
| `communication` | Matrix |
| `database` | Supabase |
| `services` | SearXNG, MiroTalk, SMTP, Jupyter, etc. |

## Vault

Secrets are encrypted with `ansible-vault`:

```bash
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
ansible-vault re-key group_vars/all/vault.yml
```

## CI/CD

GitHub Actions runs `ansible-lint`, `yamllint`, and `ansible-playbook --syntax-check`
on every push/PR affecting `ansible/`.

## Pre-commit

```bash
pip install pre-commit && pre-commit install
```

Installs hooks: ansible-lint, yamllint, trailing-whitespace, check-yaml, gitleaks.

## Backup

```bash
# Local dump of all databases
ansible-playbook playbooks/backup.yml

# With restic remote sync (requires restic_repository + vault_restic_password)
ansible-playbook playbooks/backup.yml --tags remote
```

Retention: 30 daily + 12 monthly snapshots.

## Releases

```bash
git tag v0.2.0 && git push --tags
```

Changelog: https://github.com/tensorov/homelab/releases
