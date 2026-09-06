#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export FILE="$BATS_TEST_TMPDIR/tfplan"
  export KEY="plans/mattjmorrison-homelab/admin-openbao/abc123/tfplan"
  export BUCKET="tofu-state"
  export ENDPOINT="http://garage.garage.svc.cluster.local:3900"
  export REGION="garage"
  export AWS_CALL_LOG="$BATS_TEST_TMPDIR/aws-calls.log"
}

@test "writes the downloaded content to the given local file" {
  export MOCK_DOWNLOADED_CONTENT="fake plan bytes"
  run bash "$BATS_TEST_DIRNAME/../download-plan.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$FILE")" = "fake plan bytes" ]
}

@test "fetches from s3://<bucket>/<key> at the given endpoint" {
  run bash "$BATS_TEST_DIRNAME/../download-plan.sh"
  [ "$status" -eq 0 ]
  grep -qF "s3://tofu-state/plans/mattjmorrison-homelab/admin-openbao/abc123/tfplan" "$AWS_CALL_LOG"
  grep -qF -- "--endpoint-url http://garage.garage.svc.cluster.local:3900" "$AWS_CALL_LOG"
}

@test "signs the request with the given region, not aws-cli's us-east-1 default" {
  run bash "$BATS_TEST_DIRNAME/../download-plan.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--region garage" "$AWS_CALL_LOG"
}
