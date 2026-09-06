#!/bin/bash
set -euo pipefail

if ! command -v aws >/dev/null; then
  # Ubuntu's "awscli" package doesn't exist on this runner image (noble) --
  # use AWS's own official installer instead.
  command -v unzip >/dev/null || { sudo apt-get update && sudo apt-get install -y unzip; }
  tmpdir=$(mktemp -d)
  curl -sfL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  sudo "$tmpdir/aws/install"
  rm -rf "$tmpdir"
fi

# Recent aws-cli/botocore versions default to sending checksum-related
# request/response parameters that Garage (like several other
# S3-compatible, non-AWS backends) rejects with a 400 -- restore the
# older behavior of only using them when the operation actually requires
# it.
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

aws s3 cp "$FILE" "s3://$BUCKET/$KEY" --endpoint-url "$ENDPOINT"
