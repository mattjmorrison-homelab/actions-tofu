#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export GH_ACTIONS_TOKEN="fake-token"
  export HEAD_SHA="abc123"
  export REPO="mattjmorrison-homelab/example"
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
  : > "$GITHUB_OUTPUT"
}

@test "outputs run_id for the matching OpenTofu run" {
  export MOCK_WORKFLOW_RUNS_JSON='{"workflow_runs":[{"id":12345,"name":"OpenTofu"},{"id":99999,"name":"SomethingElse"}]}'
  run bash "$BATS_TEST_DIRNAME/../find-check-run.sh"
  [ "$status" -eq 0 ]
  grep -q '^run_id=12345$' "$GITHUB_OUTPUT"
}

@test "exits non-zero when no matching run is found" {
  export MOCK_WORKFLOW_RUNS_JSON='{"workflow_runs":[]}'
  run bash "$BATS_TEST_DIRNAME/../find-check-run.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No successful check run found"* ]]
}
