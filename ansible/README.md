# home-datacenter / ansible

[![CI](https://github.com/tensorov/home-datacenter/actions/workflows/lint.yml/badge.svg)](https://github.com/tensorov/home-datacenter/actions/workflows/lint.yml)
[![license](https://img.shields.io/github/license/tensorov/home-datacenter)](LICENSE)
[![ansible-core](https://img.shields.io/badge/ansible--core-%3E%3D2.18-blue)](https://github.com/ansible/ansible)
[![python](https://img.shields.io/badge/python-%3E%3D3.12-blue)](https://www.python.org/)

Infrastructure-as-Code for a single-node homelab datacenter.

Ansible manages the full `/opt/services/` stack on Ubuntu/Debian: reverse
proxy, identity provider, Git hosting, database, and auxiliary services. This
directory is the deployment deep-dive; see the [root README](../README.md) for
a high-level overview.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.12+ | Runtime for Ansible |
| ansible-core | 2.18+ | Playbook engine |
| ansible-lint | latest | Best-practice linting |
| yamllint | latest | YAML style enforcement |
| pre-commit | latest | Git hook runner |
| shellcheck | latest | Shell script linting |

Install everything in one pass:

```bash
pip install 'ansible-core>=2.18,<2.19' ansible-lint yamllint pre-commit
ansible-galaxy collection install -r requirements.yml
```

Collections required: `community.docker`, `community.general`, `community.crypto`, `ansible.posix`.

---

## Quick start

```bash
cd ansible

# 1. Create a vault password file
echo "your-secret" > vault-password
chmod 600 vault-password

# 2. Copy and fill in secrets from the sample
cp group_vars/all/vault.yml.sample group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml

# 3. Bootstrap a fresh host (Docker, UFW, sysctl, packages)
ansible-playbook playbooks/bootstrap.yml

# 4. Deploy the full stack
ansible-playbook playbooks/deploy.yml

# 5. Verify everything is healthy
ansible-playbook playbooks/health.yml
```

Deploy only what you need by combining tags:

```bash
ansible-playbook playbooks/deploy.yml --tags base,devops
```

---

## Directory layout

```
ansible/
├── ansible.cfg                          # defaults, pipelining, roles_path
├── .ansible-lint                        # lint skip/warn lists
├── .yamllint                            # YAML rules (line-length 200, truthy off)
├── requirements.yml                     # Galaxy collections
├── vault-password                       # vault password file (gitignored)
│
├── group_vars/all/
│   ├── vars.yml                         # non-secret variables
│   └── vault.yml.sample                 # template for encrypted secrets
│
├── inventories/
│   ├── production/hosts.yml             # primary inventory
│   └── staging/                         # staging overrides
│
├── roles/
│   ├── common/                          # base: packages, Docker, UFW, sysctl
│   ├── traefik/                         # reverse proxy v3 + 17 dynamic configs
│   │   └── templates/                   # Jinja2 templates per service
│   ├── authentik/                       # identity provider (server + worker + Postgres + Redis)
│   ├── gitlab/                          # GitLab CE + runner + Postgres + Redis
│   ├── supabase/                        # Postgres + Auth + Storage + Realtime
│   └── services/                        # SearXNG, MiroTalk, SMTP, Jupyter, etc.
│
├── playbooks/
│   ├── bootstrap.yml                    # initial server provisioning
│   ├── deploy.yml                       # full stack (tag-selectable)
│   ├── update.yml                       # pull latest images, restart
│   ├── backup.yml                       # DB dumps + restic remote sync
│   ├── restore.yml                      # restore from backup
│   ├── rotate-secrets.yml               # vault + service secret rotation
│   └── health.yml                       # HTTP health checks
│
├── vendor/
│   └── ssh-rtg/                         # reverse-ssh-gateway (git submodule)
│
└── extras/
    └── molecule/                        # Molecule test scaffolding
```

---

## Playbooks

| Playbook | What it does | Typical invocation |
|----------|-------------|-------------------|
| `bootstrap.yml` | Installs Docker, configures UFW, sysctl, base packages | First run on a bare host |
| `deploy.yml` | Deploys the full stack; tag-selectable per role group | `make deploy` |
| `update.yml` | Pulls latest container images and restarts stacks | `make update` |
| `backup.yml` | Dumps all databases, syncs via restic (optional) | `make backup` |
| `restore.yml` | Restores databases from backup snapshots | Manual recovery |
| `rotate-secrets.yml` | Re-keys the vault and rotates service-level secrets | Periodic rotation |
| `health.yml` | Hits every service's health endpoint, reports status | `make health` |

---

## Tags

Tags let you deploy subsets of the stack without running everything:

| Tag | Roles included |
|-----|---------------|
| `base` | Traefik, Authentik |
| `devops` | GitLab |
| `database` | Supabase |
| `services` | SearXNG, MiroTalk, SMTP, Jupyter, and other auxiliary services |

```bash
# Example: deploy only Traefik + Authentik
ansible-playbook playbooks/deploy.yml --tags base

# Combine multiple tags
ansible-playbook playbooks/deploy.yml --tags base,devops
```

---

## Vault

All secrets live in `group_vars/all/vault.yml`, encrypted with `ansible-vault`.
A sample file (`vault.yml.sample`) is tracked in git as a template.

```bash
ansible-vault view group_vars/all/vault.yml        # read
ansible-vault edit group_vars/all/vault.yml        # edit
ansible-vault re-key group_vars/all/vault.yml      # change vault password
ansible-vault encrypt group_vars/all/vault.yml     # encrypt a plaintext file
ansible-vault decrypt group_vars/all/vault.yml     # decrypt to plaintext
```

The `vault-password` file is gitignored. For team setups, swap it for a GPG-backed
password store or an environment variable (`ANSIBLE_VAULT_PASSWORD`).

---

## Makefile

All common operations are wrapped in a root-level Makefile:

```bash
make deploy          # full stack deployment
make update          # pull images + restart
make backup          # database dumps + restic
make restore         # restore from backup
make rotate-secrets  # vault + service secret rotation
make health          # health checks

make lint            # all linters (pre-commit + ansible-lint + yamllint + shellcheck)
make ansible-lint    # ansible-lint only
make yamllint        # yamllint --strict only
make shellcheck      # shellcheck on role scripts
make pre-commit      # pre-commit run --all-files
make syntax-check    # syntax-check every playbook
```

The Makefile auto-detects `vault-password` and passes it via `--vault-password-file`
when present.

---

## CI/CD

GitHub Actions (`.github/workflows/lint.yml`) runs on every push or PR that
touches `ansible/`, the Makefile, or `.pre-commit-config.yaml`. Concurrency
groups cancel in-progress runs for the same ref.

| Step | What it checks |
|------|---------------|
| **yamllint** | YAML formatting (strict mode, 200-char lines) |
| **ansible-lint** | Ansible best practices against `.ansible-lint` config |
| **syntax-check** | `ansible-playbook --syntax-check` on every playbook |
| **pre-commit** | All configured hooks with diff output |
| **shellcheck** | Lints every `.sh` file under `roles/` |
| **vault sample** | Rejects `vault.yml.sample` if it contains encrypted data |

CI installs: Python 3.12, ansible-core, ansible-lint, yamllint, pre-commit,
and collections: `community.docker`, `community.general`, `community.crypto`, `ansible.posix`.

---

## Pre-commit hooks

```bash
pre-commit install     # activate locally
```

| Hook | Source | Scope |
|------|--------|-------|
| ansible-lint | `ansible/ansible-lint` | `ansible/` |
| yamllint | `adrienverge/yamllint` | `ansible/` |
| trailing-whitespace | `pre-commit-hooks` | all files |
| end-of-file-fixer | `pre-commit-hooks` | non-Jinja2 |
| check-yaml | `pre-commit-hooks` | non-Jinja2 |
| check-json | `pre-commit-hooks` | all files |
| check-added-large-files | `pre-commit-hooks` | max 500 KB |
| detect-private-key | `pre-commit-hooks` | excludes `.pub` |
| gitleaks | `gitleaks/gitleaks` | all files |

---

## Traefik dynamic config

Each service behind Traefik gets its own Jinja2 template in
`roles/traefik/templates/`. The Traefik role renders these into
`/opt/services/traefik/config/` at deploy time.

Templates include middleware definitions, router rules, TLS settings, and
Authentik forwardAuth callbacks. Each service's `docker-compose.yml` carries
the matching Traefik labels.

Current templates: `config.yml.j2`, `traefik.yml.j2`, `env.j2`, and
per-service files for Amadeus, DeepTutor, Distill, Guacamole, MiroTalk,
Multica, OnlyBridge, Polymarket, Renderfarm, SearXNG, X99-Proxy, and others.

---

## Environments

| Environment | Inventory | Purpose |
|-------------|-----------|---------|
| Production | `inventories/production/hosts.yml` | Default. All playbooks target this unless overridden. |
| Staging | `inventories/staging/` | Parallel test environment with its own group/host vars. |

Select an inventory explicitly with `-i`:

```bash
ansible-playbook -i inventories/staging/hosts.yml playbooks/deploy.yml
```

---

## Vendor submodule

`vendor/ssh-rtg/` is a git submodule providing the
[reverse-ssh-gateway](https://github.com/tensorov/ssh-rtg) Ansible roles for
tunnel management. It is included in `roles_path` via `ansible.cfg` so its
roles are available alongside first-party ones.

```bash
git submodule update --init --recursive   # fetch after clone
```
