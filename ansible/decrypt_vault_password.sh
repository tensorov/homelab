#!/usr/bin/env bash
# Decrypt vault password using GPG.
# Usage: ./decrypt_vault_password.sh
#
# Setup:
#   1. echo -n "your-ansible-vault-password" | gpg --encrypt --recipient "your-gpg-key-id" > vault-password.gpg
#   2. chmod 600 vault-password.gpg
#   3. Update ansible.cfg: vault_password_file = decrypt_vault_password.sh
#
# Falls back to plain vault-password file if vault-password.gpg doesn't exist.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$DIR/vault-password.gpg" ]; then
  gpg --decrypt "$DIR/vault-password.gpg" 2>/dev/null
elif [ -f "$DIR/vault-password" ]; then
  cat "$DIR/vault-password"
else
  echo "ERROR: No vault-password.gpg or vault-password found in $DIR" >&2
  exit 1
fi
