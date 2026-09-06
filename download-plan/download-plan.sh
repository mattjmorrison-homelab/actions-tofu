#!/bin/bash
set -euo pipefail

command -v aws >/dev/null || { sudo apt-get update && sudo apt-get install -y awscli; }

aws s3 cp "s3://$BUCKET/$KEY" "$FILE" --endpoint-url "$ENDPOINT"
