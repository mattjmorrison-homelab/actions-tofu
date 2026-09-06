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

aws s3 cp "s3://$BUCKET/$KEY" "$FILE" --endpoint-url "$ENDPOINT"
