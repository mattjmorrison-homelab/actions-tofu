#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export VAULT_ADDR="http://vault.invalid"
  export GITHUB_ENV="$BATS_TEST_TMPDIR/github_env"
  : > "$GITHUB_ENV"

  # Match action.yml's own defaults -- the shared github-actions-runner
  # role/admin-github prefix, so existing tests exercise the same
  # behavior every not-yet-migrated repo's CI still relies on today.
  export ROLE="github-actions-runner"
  export KV_PREFIX="admin-github"

  MOCK_CALL_LOG="$BATS_TEST_TMPDIR/curl_calls.log"
  export MOCK_CALL_LOG
  : > "$MOCK_CALL_LOG"
}

@test "fetches AWS creds but not GITHUB_TOKEN when NEEDS_GITHUB_TOKEN is false" {
  export NEEDS_GITHUB_TOKEN=false
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [ "$status" -eq 0 ]
  grep -q '^AWS_ACCESS_KEY_ID=fake-access-key$' "$GITHUB_ENV"
  grep -q '^AWS_SECRET_ACCESS_KEY=fake-secret-key$' "$GITHUB_ENV"
  ! grep -q '^GITHUB_TOKEN=' "$GITHUB_ENV"
}

@test "also fetches GITHUB_TOKEN when NEEDS_GITHUB_TOKEN is true" {
  export NEEDS_GITHUB_TOKEN=true
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [ "$status" -eq 0 ]
  grep -q '^GITHUB_TOKEN=fake-gh-token$' "$GITHUB_ENV"
}

@test "masks every fetched secret in output" {
  export NEEDS_GITHUB_TOKEN=true
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [[ "$output" == *"::add-mask::fake-access-key"* ]]
  [[ "$output" == *"::add-mask::fake-secret-key"* ]]
  [[ "$output" == *"::add-mask::fake-gh-token"* ]]
}

@test "default role/kv-prefix log in as github-actions-runner and read from admin-github" {
  export NEEDS_GITHUB_TOKEN=false
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [ "$status" -eq 0 ]
  grep -q '"role":"github-actions-runner"' "$MOCK_CALL_LOG"
  grep -q 'kv/data/homelab/admin-github/tofu-state-access-key-id' "$MOCK_CALL_LOG"
  grep -q 'kv/data/homelab/admin-github/tofu-state-secret-access-key' "$MOCK_CALL_LOG"
}

@test "a custom role and kv-prefix log in and read from the caller's own dedicated path instead" {
  export ROLE="admin-discord-tofu-state"
  export KV_PREFIX="service/k8s-garage/admin-discord"
  export NEEDS_GITHUB_TOKEN=false
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [ "$status" -eq 0 ]
  grep -q '"role":"admin-discord-tofu-state"' "$MOCK_CALL_LOG"
  grep -q 'kv/data/homelab/service/k8s-garage/admin-discord/tofu-state-access-key-id' "$MOCK_CALL_LOG"
  grep -q 'kv/data/homelab/service/k8s-garage/admin-discord/tofu-state-secret-access-key' "$MOCK_CALL_LOG"
  ! grep -q 'admin-github' "$MOCK_CALL_LOG"
}

@test "needs-github-token always reads admin-github's token regardless of kv-prefix" {
  export ROLE="admin-discord-tofu-state"
  export KV_PREFIX="service/k8s-garage/admin-discord"
  export NEEDS_GITHUB_TOKEN=true
  run bash "$BATS_TEST_DIRNAME/../fetch-credentials.sh"
  [ "$status" -eq 0 ]
  grep -q '^GITHUB_TOKEN=fake-gh-token$' "$GITHUB_ENV"
  grep -q 'kv/data/homelab/admin-github/github-token' "$MOCK_CALL_LOG"
}
