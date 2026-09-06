#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export FILE="$BATS_TEST_TMPDIR/tfplan"
  printf 'fake plan bytes' > "$FILE"
  export KEY="plans/mattjmorrison-homelab/admin-openbao/abc123/tfplan"
  export BUCKET="tofu-state"
  export ENDPOINT="http://garage.garage.svc.cluster.local:3900"
  export AWS_CALL_LOG="$BATS_TEST_TMPDIR/aws-calls.log"
  export AWS_UPLOAD_CAPTURE_FILE="$BATS_TEST_TMPDIR/uploaded"
}

@test "uploads the file's exact content to the given bucket/key" {
  run bash "$BATS_TEST_DIRNAME/../upload-plan.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$AWS_UPLOAD_CAPTURE_FILE")" = "fake plan bytes" ]
}

@test "targets s3://<bucket>/<key> at the given endpoint" {
  run bash "$BATS_TEST_DIRNAME/../upload-plan.sh"
  [ "$status" -eq 0 ]
  grep -qF "s3://tofu-state/plans/mattjmorrison-homelab/admin-openbao/abc123/tfplan" "$AWS_CALL_LOG"
  grep -qF -- "--endpoint-url http://garage.garage.svc.cluster.local:3900" "$AWS_CALL_LOG"
}
