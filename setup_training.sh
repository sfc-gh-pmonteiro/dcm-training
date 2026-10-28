#!/usr/bin/env bash
# =============================================================================
# DCM training - one-time setup (README section 2)
#
#   ./setup_training.sh <connection>     set your account in the manifests, then set up
#   ./setup_training.sh --reset          put the MYORG-MYACCOUNT placeholder back
#                                        (purge_training.sh calls this)
#
# 1. Reads ORG-ACCOUNT from the connection and writes it into account_identifier
#    of both manifests (works on any previous value, so it is safe to re-run).
#    The local files keep it during the session: the snow dcm --target commands
#    in the lab read them.
# 2. Runs dcm_training_setup.sql (roles, project objects, source upload).
#    Safe to re-run. Deploys nothing.
# =============================================================================
set -euo pipefail

PLACEHOLDER="MYORG-MYACCOUNT"
ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS=("$ROOT/orders_project_1-0/manifest.yml" "$ROOT/orders_project_1-1/manifest.yml")

# Replaces the placeholder or any earlier identifier, so re-runs are safe.
set_account() {
  for m in "${MANIFESTS[@]}"; do
    sed -i.bak -E "s/^([[:space:]]*account_identifier:[[:space:]]*)[^[:space:]#]+/\1$1/" "$m"
    rm -f "$m.bak"
    echo "  $(grep -c "account_identifier: $1" "$m") targets set to $1 in ${m#$ROOT/}"
  done
}

if [[ "${1:-}" == "--reset" ]]; then
  set_account "$PLACEHOLDER"
  # CLI plan artifacts (git-ignored) also contain the rendered account identifier.
  rm -rf "$ROOT"/orders_project_1-*/out
  exit 0
fi

CONN="${1:?usage: $0 <connection> | --reset}"

ACCOUNT_ID="$(snow sql -c "$CONN" --format json \
  -q "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS ID" 2>/dev/null \
  | jq -r '.[0].ID')"
if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "null" ]]; then
  echo "Could not read the account identifier with connection '$CONN'." >&2; exit 1
fi
echo "Account identifier: $ACCOUNT_ID"

# Must happen before setup: the setup script uploads the manifests.
set_account "$ACCOUNT_ID"

snow sql -c "$CONN" -f "$ROOT/dcm_training_setup.sql" -D "root=$ROOT"
echo "Setup finished. The last two result sets above should show 3 DCM projects"
echo "(each owned by its deployer role) and 18 files."
