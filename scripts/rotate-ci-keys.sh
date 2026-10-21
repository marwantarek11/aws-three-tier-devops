#!/usr/bin/env bash
# ci_auth_mode = "iam_user" only.
# Creates a fresh access key for each CI user and writes it straight into GitHub encrypted
# secrets. Keys are never printed or written to disk. Old keys are deleted afterwards, so
# re-running this script is a key rotation.
#
# Usage: AWS_PROFILE=<admin> ./scripts/rotate-ci-keys.sh [owner/repo]
set -euo pipefail

repo="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
project="${PROJECT:-threetier}"
environment="${ENVIRONMENT:-dev}"

rotate() {
  local user="$1"; shift
  local id_secret="$1" key_secret="$2"; shift 2
  local scope=("$@")   # e.g. --env dev, or empty for repository secrets

  local old_keys
  old_keys=$(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].AccessKeyId' --output text)

  local creds
  creds=$(aws iam create-access-key --user-name "$user" \
    --query '[AccessKey.AccessKeyId,AccessKey.SecretAccessKey]' --output text)

  gh secret set "$id_secret"  --repo "$repo" "${scope[@]}" --body "$(cut -f1 <<<"$creds")"
  gh secret set "$key_secret" --repo "$repo" "${scope[@]}" --body "$(cut -f2 <<<"$creds")"
  unset creds

  for k in $old_keys; do
    aws iam delete-access-key --user-name "$user" --access-key-id "$k"
  done
  echo "rotated $user -> ${scope[*]:-repository} secrets $id_secret/$key_secret"
}

rotate "${project}-ci-deploy" AWS_DEPLOY_ACCESS_KEY_ID AWS_DEPLOY_SECRET_ACCESS_KEY --env "$environment"
rotate "${project}-ci-plan"   AWS_PLAN_ACCESS_KEY_ID   AWS_PLAN_SECRET_ACCESS_KEY
