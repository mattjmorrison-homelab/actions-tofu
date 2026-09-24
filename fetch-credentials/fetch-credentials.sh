#!/bin/bash
set -euo pipefail

# Requires VAULT_ADDR, ROLE, KV_PREFIX, and NEEDS_GITHUB_TOKEN
# ("true"/"false") in the environment. Writes AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY, and (when requested) GITHUB_TOKEN to
# GITHUB_ENV.

LOGIN_PAYLOAD=$(jq -nc \
  --arg jwt "$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  --arg role "$ROLE" \
  '{jwt: $jwt, role: $role}')
CLIENT_TOKEN=$(curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/login" -d "$LOGIN_PAYLOAD" \
  | jq -r '.auth.client_token')

fetch_secret() {
  curl -sf -H "X-Vault-Token: $CLIENT_TOKEN" "$VAULT_ADDR/v1/kv/data/homelab/$1/$2" \
    | jq -r '.data.data.value'
}

ACCESS_KEY_ID=$(fetch_secret "$KV_PREFIX" tofu-state-access-key-id)
SECRET_ACCESS_KEY=$(fetch_secret "$KV_PREFIX" tofu-state-secret-access-key)

echo "::add-mask::$ACCESS_KEY_ID"
echo "::add-mask::$SECRET_ACCESS_KEY"
echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID" >> "$GITHUB_ENV"
echo "AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> "$GITHUB_ENV"

if [ "$NEEDS_GITHUB_TOKEN" = "true" ]; then
  GH_ORG_TOKEN=$(fetch_secret admin-github github-token)
  echo "::add-mask::$GH_ORG_TOKEN"
  echo "GITHUB_TOKEN=$GH_ORG_TOKEN" >> "$GITHUB_ENV"
fi
