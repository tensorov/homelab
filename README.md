# home-datacenter

Infrastructure-as-Code for zeitoven.ru's homelab datacenter.

Ansible-managed deployment for `/opt/services/`.

## Structure

```
ansible/
├── ansible.cfg
├── inventory.yml
├── requirements.yml
├── vault-password           # vault password file (gitignored)
├── group_vars/all/
│   ├── vars.yml             # non-secret variables
│   └── vault.yml            # encrypted secrets (ansible-vault)
├── roles/
│   ├── common/              # base: packages, Docker, UFW, sysctl
│   ├── traefik/             # reverse proxy with 17+ dynamic config templates
│   ├── authentik/           # identity provider (server + worker + postgres + redis)
│   ├── gitlab/              # git + CI/CD (ce + postgres + redis + runner)
│   ├── matrix/              # synapse + element + sliding-sync + bridges
│   ├── supabase/            # postgres + auth + storage + realtime
│   └── services/            # searxng, mirotalk, jupyter, smtp, opencode-webhook, opencode-web
└── playbooks/
    ├── bootstrap.yml        # initial provisioning
    ├── deploy.yml           # full stack deployment (tag-selectable)
    ├── update.yml           # pull latest images + restart
    ├── backup.yml           # database dumps
    └── health.yml           # health checks
```

## Quick Start

```bash
cd ansible

# 1. Edit inventory and variables
vi inventory.yml
vi group_vars/all/vars.yml

# 2. Set vault password
echo "your-secret" > vault-password
chmod 600 vault-password

# 3. Encrypt secrets from vault.yml.sample
ansible-vault encrypt group_vars/all/vault.yml

# 4. Bootstrap (first run on a fresh host)
ansible-playbook playbooks/bootstrap.yml

# 5. Deploy full stack
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
