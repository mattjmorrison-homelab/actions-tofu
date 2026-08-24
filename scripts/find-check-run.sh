#!/bin/bash
set -euo pipefail

# Requires GH_ACTIONS_TOKEN, HEAD_SHA, and REPO (owner/repo) in the
# environment. Writes run_id to GITHUB_OUTPUT.

RUN_ID=$(curl -sf -H "Authorization: Bearer $GH_ACTIONS_TOKEN" \
  "https://api.github.com/repos/$REPO/actions/runs?head_sha=$HEAD_SHA&event=pull_request&status=success" \
  | jq -r '.workflow_runs[] | select(.name=="OpenTofu") | .id' | head -1)

if [ -z "$RUN_ID" ]; then
  echo "No successful check run found for head SHA $HEAD_SHA" >&2
  exit 1
fi

echo "run_id=$RUN_ID" >> "$GITHUB_OUTPUT"
