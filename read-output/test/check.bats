#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export STATE_KEY="admin-discord/terraform.tfstate"
  export OUTPUT_NAME="webhook_urls"
  export MAP_KEY=""
  export BUCKET="tofu-state"
  export ENDPOINT="http://garage.garage.svc.cluster.local:3900"
  export REGION="garage"
  export AWS_CALL_LOG="$BATS_TEST_TMPDIR/aws-calls.log"
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
  : > "$GITHUB_OUTPUT"
}

@test "extracts one map key from the output and masks it" {
  export MAP_KEY="github-actions"
  export MOCK_STATE_JSON='{"outputs":{"webhook_urls":{"value":{"github-actions":"https://discord.com/api/webhooks/fake"}}}}'
  run bash "$BATS_TEST_DIRNAME/../read-output.sh"
  [ "$status" -eq 0 ]
  grep -qF "::add-mask::https://discord.com/api/webhooks/fake" <<< "$output"
  grep -qF "value=https://discord.com/api/webhooks/fake" "$GITHUB_OUTPUT"
}

@test "returns the whole output value when no map key is given" {
  export MOCK_STATE_JSON='{"outputs":{"webhook_urls":{"value":"single-value"}}}'
  run bash "$BATS_TEST_DIRNAME/../read-output.sh"
  [ "$status" -eq 0 ]
  grep -qF "value=single-value" "$GITHUB_OUTPUT"
}

@test "fetches the state file from s3://<bucket>/<state-key> at the given endpoint/region" {
  export MAP_KEY="github-actions"
  export MOCK_STATE_JSON='{"outputs":{"webhook_urls":{"value":{"github-actions":"https://discord.com/api/webhooks/fake"}}}}'
  run bash "$BATS_TEST_DIRNAME/../read-output.sh"
  [ "$status" -eq 0 ]
  grep -qF "s3://tofu-state/admin-discord/terraform.tfstate" "$AWS_CALL_LOG"
  grep -qF -- "--endpoint-url http://garage.garage.svc.cluster.local:3900" "$AWS_CALL_LOG"
  grep -qF -- "--region garage" "$AWS_CALL_LOG"
}

@test "exits non-zero and leaves GITHUB_OUTPUT untouched when the map key is missing" {
  export MAP_KEY="does-not-exist"
  export MOCK_STATE_JSON='{"outputs":{"webhook_urls":{"value":{"github-actions":"https://discord.com/api/webhooks/fake"}}}}'
  run bash "$BATS_TEST_DIRNAME/../read-output.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found in admin-discord/terraform.tfstate"* ]]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "exits non-zero and leaves GITHUB_OUTPUT untouched when the output name is missing" {
  export OUTPUT_NAME="does_not_exist"
  export MOCK_STATE_JSON='{"outputs":{"webhook_urls":{"value":"single-value"}}}'
  run bash "$BATS_TEST_DIRNAME/../read-output.sh"
  [ "$status" -ne 0 ]
  [ ! -s "$GITHUB_OUTPUT" ]
}
