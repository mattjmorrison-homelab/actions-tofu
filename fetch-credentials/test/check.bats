#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export VAULT_ADDR="http://vault.invalid"
  export GITHUB_ENV="$BATS_TEST_TMPDIR/github_env"
  : > "$GITHUB_ENV"
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
