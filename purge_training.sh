#!/usr/bin/env bash
# =============================================================================
# DCM training - full cleanup (README section 7)
#
#   ./purge_training.sh <connection>          asks for confirmation
#   ./purge_training.sh <connection> --yes    no prompt
#
# 1. Runs dcm_training_purge.sql.
#    !!! DESTRUCTIVE: drops every object the projects manage (including table
#    data), the projects, the deployer roles, DCM_TRAINING and DCM_TRAINING_WH.
# 2. Only if the purge succeeded: puts the MYORG-MYACCOUNT placeholder back in
#    both manifests and deletes the CLI out/ folders (setup_training.sh --reset).
# =============================================================================
set -euo pipefail

CONN="${1:?usage: $0 <connection> [--yes]}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ "${2:-}" != "--yes" ]]; then
  echo "This permanently drops ORDERS_DEV/QA/PRD (with data), the ORDERS_* and DCM_* roles,"
  echo "ORDERS_WH_* / DCM_TRAINING_WH and the DCM_TRAINING database, using connection '$CONN'."
  read -r -p "Type PURGE to continue: " answer
  [[ "$answer" == "PURGE" ]] || { echo "Aborted. Nothing changed."; exit 1; }
fi

snow sql -c "$CONN" -f "$ROOT/dcm_training_purge.sql"

# Reached only if the purge succeeded (set -e), so a failed purge keeps your
# account in the manifests for troubleshooting with snow dcm.
bash "$ROOT/setup_training.sh" --reset
echo "Purge finished. The last four result sets above should all say 'No data'."
