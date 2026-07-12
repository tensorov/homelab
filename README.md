<p align="center">
  <h1 align="center">home-datacenter</h1>
  <p align="center">Infrastructure-as-Code for <strong>zeitoven.ru</strong>'s homelab datacenter.</p>
</p>

<p align="center">
  <a href="https://github.com/tensorov/homelab/actions/workflows/lint.yml"><img src="https://github.com/tensorov/homelab/actions/workflows/lint.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Ansible-2.14+-EE060A?style=flat&logo=ansible&logoColor=white" alt="Ansible">
  <img src="https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-E95420?style=flat&logo=ubuntu&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Docker-24+-2496ED?style=flat&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat" alt="License">
</p>

<p align="center">
  Ansible-managed deployment for <code>/opt/services/</code> on bare-metal Ubuntu/Debian hosts.
  Docker Compose stacks orchestrated by roles, secrets encrypted with <code>ansible-vault</code>,
  backups via restic with remote sync.
</p>

## Architecture

```
                     +---------------------+
                     |   GitHub Actions     |
                     |  lint + syntax-check |
                     +----------+----------+
                                |
              push / PR          v
+==========================================================+
|                    /opt/services/                         |
|                                                          |
|  +----------------------------------------------------+  |
|  | LAYER 1: Ingress                                    |  |
|  |  Traefik (reverse proxy, TLS, dynamic config)      |  |
|  +----------------------------------------------------+  |
|                         |                                |
|  +----------------------------------------------------+  |
|  | LAYER 2: Identity                                   |  |
|  |  Authentik (SSO, forwardAuth middleware)           |  |
|  +----------------------------------------------------+  |
|                         |                                |
|  +----------------------------------------------------+  |
|  | LAYER 3: Applications                               |  |
|  |  GitLab (CE + Postgres + Redis + Runner)           |  |
|  |  Matrix  (Synapse + Element + Sliding Sync + Bridges)|  |
|  |  Supabase (Postgres + Auth + Storage + Realtime)   |  |
|  +----------------------------------------------------+  |
|                         |                                |
|  +----------------------------------------------------+  |
|  | LAYER 4: Auxiliary Services                         |  |
|  |  SearXNG | MiroTalk | Jupyter | SMTP               |  |
|  |  opencode-webhook | opencode-web                    |  |
|  +----------------------------------------------------+  |
+==========================================================+
```

All services sit behind Traefik, protected by Authentik forwardAuth. Each layer deploys independently via tags.

## Table of Contents

- [Quick Start](#quick-start)
- [Services](#services)
- [Tags](#tags)
- [Vault & Secrets](#vault--secrets)
- [Backup & Retention](#backup--retention)
- [CI/CD](#cicd)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Makefile Targets](#makefile-targets)
- [Project Structure](#project-structure)
- [Contributing](#contributing)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/tensorov/homelab.git
cd homelab/ansible

# 1. Set vault password
echo "your-secret" > vault-password
chmod 600 vault-password

# 2. Encrypt secrets (from vault.yml.sample)
ansible-vault encrypt group_vars/all/vault.yml

# 3. Bootstrap a fresh host
ansible-playbook playbooks/bootstrap.yml

# 4. Deploy the full stack
ansible-playbook playbooks/deploy.yml
```

Deploy specific roles by tag:

```bash
ansible-playbook playbooks/deploy.yml --tags traefik,authentik
```

## Services

| Role | Stack | Description |
|------|-------|-------------|
| **common** | Packages, Docker, UFW, sysctl | Base layer for all hosts |
| **traefik** | Reverse proxy + TLS | Routes traffic via dynamic config |
| **authentik** | SSO / IdP | Server + worker + Postgres + Redis |
| **gitlab** | Git + CI/CD | CE + Postgres + Redis + Runner |
| **matrix** | Messaging | Synapse + Element + Sliding Sync + bridges |
| **supabase** | Backend-as-a-Service | Postgres + Auth + Storage + Realtime |
| **services** | Auxiliary | SearXNG, MiroTalk, Jupyter, SMTP, opencode-webhook, opencode-web |

## Tags

```bash
ansible-playbook playbooks/deploy.yml --tags <tag>
```

| Tag | What it deploys |
|-----|-----------------|
| `base` | Traefik + Authentik |
| `devops` | GitLab (CE + Postgres + Redis + Runner) |
| `communication` | Matrix (Synapse + Element + bridges) |
| `database` | Supabase (Postgres + Auth + Storage + Realtime) |
| `services` | SearXNG, MiroTalk, SMTP, Jupyter, opencode-webhook, opencode-web |

Combine tags: `--tags base,devops`

## Vault & Secrets

All sensitive values are encrypted with `ansible-vault` in `group_vars/all/vault.yml`.

```bash
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
ansible-vault re-key group_vars/all/vault.yml
```

Non-secret variables live in `group_vars/all/vars.yml` (plain text). A `vault.yml.sample` is provided for reference.

**Never commit `vault.yml` unencrypted.** The `.gitignore` enforces this.

## Backup & Retention

```bash
# Local database dumps only
ansible-playbook playbooks/backup.yml

# Local dumps + restic remote sync
ansible-playbook playbooks/backup.yml --tags remote
```

Remote sync requires `restic_repository` and `vault_restic_password` in your vault.

**Retention:** 30 daily snapshots, 12 monthly snapshots. Old snapshots are pruned automatically by restic.

## CI/CD

GitHub Actions runs on every push and PR that touches `ansible/`:

| Check | Tool |
|-------|------|
| YAML linting | yamllint |
| Ansible linting | ansible-lint |
| Playbook syntax | `ansible-playbook --syntax-check` |

Workflow: `.github/workflows/lint.yml`

## Pre-commit Hooks

```bash
pip install pre-commit && pre-commit install
```

| Hook | Purpose |
|------|---------|
| ansible-lint | Ansible best practices |
| yamllint | YAML formatting |
| trailing-whitespace | Strip trailing spaces |
| check-yaml | Validate YAML syntax |
| gitleaks | Detect leaked secrets |

## Makefile Targets

```bash
make lint           # All linters (pre-commit + ansible-lint + yamllint + shellcheck)
make deploy         # Full stack deployment
make update         # Pull latest images + restart
make backup         # Database dumps + restic sync
make restore        # Restore from backup
make health         # Run health checks
make bootstrap      # First-run provisioning
make syntax-check   # Syntax-check all playbooks
make rotate-secrets # Rotate vault encryption keys
```

## Project Structure

```
ansible/
  ansible.cfg, .ansible-lint, .yamllint   # Configuration
  requirements.yml                         # Galaxy dependencies
  vault-password                           # Vault password (gitignored)
  group_vars/all/
    vars.yml                               # Non-secret variables
    vault.yml                              # Encrypted secrets
  inventories/
    production/hosts.yml                   # Production inventory
    staging/                               # Staging overrides
  roles/
    common/                                # Packages, Docker, UFW, sysctl
    traefik/                               # Reverse proxy, 17+ dynamic config templates
    authentik/                             # Identity provider (SSO)
    gitlab/                                # Git + CI/CD
    matrix/                                # Synapse + Element + bridges
    supabase/                              # Postgres + Auth + Storage + Realtime
    services/                              # SearXNG, MiroTalk, Jupyter, SMTP, etc.
  playbooks/
    bootstrap.yml                          # Initial provisioning
    deploy.yml                             # Full stack (tag-selectable)
    update.yml                             # Pull latest images + restart
    backup.yml                             # DB dumps + restic remote sync
    health.yml                             # Health checks
    restore.yml                            # Restore from backup
    rotate-secrets.yml                     # Vault key rotation
.github/workflows/lint.yml                 # CI pipeline
Makefile                                   # Common tasks
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/add-service`)
3. Run linters before committing: `make lint`
4. Open a pull request against `main`

All PRs must pass CI checks (yamllint, ansible-lint, syntax-check) before merge.

## License

[MIT](LICENSE)
