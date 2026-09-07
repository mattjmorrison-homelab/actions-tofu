#!/bin/bash
set -euo pipefail

if ! command -v aws >/dev/null; then
  # Ubuntu's "awscli" package doesn't exist on this runner image (noble) --
  # use AWS's own official installer instead. Runners can be amd64 or
  # arm64 (e.g. k8s-arm64 for Pi-targeted builds) -- the x86_64 build
  # silently fails to execute on arm64, so pick the matching installer.
  case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  command -v unzip >/dev/null || { sudo apt-get update && sudo apt-get install -y unzip; }
  tmpdir=$(mktemp -d)
  curl -sfL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o "$tmpdir/awscliv2.zip"
  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  sudo "$tmpdir/aws/install"
  rm -rf "$tmpdir"
fi

aws s3 cp "$FILE" "s3://$BUCKET/$KEY" --endpoint-url "$ENDPOINT" --region "$REGION"
