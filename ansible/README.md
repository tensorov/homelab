# home-datacenter — Ansible Deployment
# =====================================

Infrastructure-as-Code for `/opt/services/` — Traefik, Authentik, GitLab, Matrix,
Supabase, and auxiliary services.

## Quick Start

```bash
# 1. Edit inventory
vi inventory.yml

# 2. Edit variables (especially domains)
vi group_vars/all/vars.yml

# 3. Set vault password
echo "your-secret" > vault-password
chmod 600 vault-password

# 4. Encrypt secrets
ansible-vault encrypt group_vars/all/vault.yml

# 5. Bootstrap (first run on a fresh host)
ansible-playbook playbooks/bootstrap.yml

# 6. Deploy full stack
ansible-playbook playbooks/deploy.yml

# 7. Or deploy specific roles
ansible-playbook playbooks/deploy.yml --tags traefik,authentik
```

## Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory.yml             # Host inventory
├── requirements.yml          # Galaxy dependencies
├── vault-password            # Vault password file (gitignored)
├── group_vars/
│   └── all/
│       ├── vars.yml          # All non-secret variables
│       └── vault.yml         # Encrypted secrets (ansible-vault)
├── host_vars/                # Per-host overrides
├── roles/
│   ├── common/               # Base setup (required first)
│   ├── traefik/              # Reverse proxy (Traefik v3)
│   ├── authentik/             # Identity provider
│   ├── gitlab/                # Git & CI/CD
│   ├── matrix/                # Matrix/Synapse + Element + bridges
│   ├── supabase/              # Supabase (Postgres + Auth + Storage)
│   └── services/              # Auxiliary (SearXNG, MiroTalk, SMTP, Jupyter, etc.)
└── playbooks/
    ├── bootstrap.yml          # Initial server provisioning
    ├── deploy.yml             # Full stack deployment
    ├── update.yml             # Pull latest images + restart
    ├── backup.yml             # Database backups
    └── health.yml             # Health checks
```

## Tags

```bash
# Available tags (from deploy.yml):
#   base          — traefik + authentik
#   devops        — gitlab
#   communication — matrix
#   database      — supabase
#   services      — auxiliary services (searxng, mirotalk, etc.)

ansible-playbook playbooks/deploy.yml --tags database
```

## Vault

Secrets are encrypted with `ansible-vault`:

```bash
# Edit vault
ansible-vault edit group_vars/all/vault.yml

# View
ansible-vault view group_vars/all/vault.yml

# Re-key (change password)
ansible-vault re-key group_vars/all/vault.yml
```

## Traefik Dynamic Config

Additional Traefik middleware and router configurations are deployed via the Traefik role.
Each service under `/opt/services/` gets Traefik labels in its docker-compose.yml.

See `roles/traefik/templates/` for current dynamic config templates.
