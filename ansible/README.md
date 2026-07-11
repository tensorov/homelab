# home-datacenter — Ansible Deployment

Infrastructure-as-Code for `/opt/services/` — Traefik, Authentik, GitLab,
Supabase, and auxiliary services.

## Prerequisites

- Python 3.12+ with pip
- Ansible Core 2.18+, ansible-lint, yamllint
- Collections: `community.docker`, `community.general`

```bash
pip install ansible-core ansible-lint yamllint pre-commit
ansible-galaxy collection install community.docker community.general
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

## Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── .ansible-lint                  # ansible-lint config
├── .yamllint                      # yamllint config
├── requirements.yml               # Galaxy dependencies
├── vault-password                 # Vault password file (gitignored)
├── group_vars/all/
│   ├── vars.yml                   # Non-secret variables
│   └── vault.yml                  # Encrypted secrets (ansible-vault)
├── inventories/
│   ├── production/hosts.yml       # Production inventory
│   └── staging/                   # Staging environment
├── roles/
│   ├── common/                    # Base: packages, Docker, UFW, sysctl
│   ├── traefik/                   # Reverse proxy (Traefik v3)
│   ├── authentik/                 # Identity provider
│   ├── gitlab/                    # Git & CI/CD
│   ├── supabase/                  # Supabase (Postgres + Auth + Storage)
│   └── services/                  # Auxiliary (SearXNG, MiroTalk, SMTP, Jupyter, etc.)
└── playbooks/
    ├── bootstrap.yml              # Initial server provisioning
    ├── deploy.yml                 # Full stack deployment (tag-selectable)
    ├── update.yml                 # Pull latest images + restart
    ├── backup.yml                 # Database dumps + restic remote sync
    ├── restore.yml                # Restore databases from backup
    ├── rotate-secrets.yml         # Rotate vault + service secrets
    └── health.yml                 # Health check all services
```

## Playbooks

| Playbook | Description |
|----------|-------------|
| `bootstrap.yml` | Initial provisioning (common role) |
| `deploy.yml` | Full stack deployment, tag-selectable |
| `update.yml` | Pull latest images + restart stacks |
| `backup.yml` | Database dumps + restic remote sync |
| `restore.yml` | Restore databases from dumps |
| `rotate-secrets.yml` | Rotate ansible-vault and service secrets |
| `health.yml` | HTTP health checks for all services |

## Tags

```bash
# Deploy specific groups
ansible-playbook playbooks/deploy.yml --tags base,devops

# Available tags:
#   base          — traefik + authentik
#   devops        — gitlab
#   database      — supabase
#   services      — searxng, mirotalk, smtp, jupyter, etc.
```

## Vault

Secrets use `ansible-vault`:

```bash
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
ansible-vault re-key group_vars/all/vault.yml
```

Vault password file (`vault-password`) is gitignored. For teams, use `gpg` or a password
manager instead of a plain file.

## Makefile

Common operations:

```bash
make lint       # Run all linters (ansible-lint, yamllint, shellcheck)
make deploy     # ansible-playbook playbooks/deploy.yml
make backup     # ansible-playbook playbooks/backup.yml
make update     # ansible-playbook playbooks/update.yml
make health     # ansible-playbook playbooks/health.yml
```

## CI

GitHub Actions (`.github/workflows/lint.yml`) runs on every push/PR:

- `ansible-lint` — Ansible best practices
- `yamllint` — YAML style
- `ansible-playbook --syntax-check` — all playbooks
- `pre-commit run --all-files` — all pre-commit hooks
- `shellcheck` — shell scripts in roles

## Pre-commit

```bash
pre-commit install
```

Hooks: ansible-lint, yamllint, trailing-whitespace, end-of-file-fixer,
check-yaml, check-json, detect-private-key, gitleaks.

## Traefik Dynamic Config

Service-specific Traefik middleware and router configurations are deployed
via the Traefik role. Each service under `/opt/services/` gets Traefik labels
in its docker-compose.yml.

See `roles/traefik/templates/` for current dynamic config templates.
