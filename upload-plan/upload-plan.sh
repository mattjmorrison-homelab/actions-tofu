#!/bin/bash
set -euo pipefail

command -v aws >/dev/null || { sudo apt-get update && sudo apt-get install -y awscli; }

aws s3 cp "$FILE" "s3://$BUCKET/$KEY" --endpoint-url "$ENDPOINT"
