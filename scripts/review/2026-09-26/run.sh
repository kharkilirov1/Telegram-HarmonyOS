#!/usr/bin/env bash
set -euo pipefail
REVIEW_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node -e 'if (Number(process.versions.node.split(".")[0]) < 24) { throw new Error("Review probes require Node 24+"); }'
for probe in check_gateway data_parsing state_repro state_usecases ui_composer_repro media_races auth_logging build_guards; do
  node --disable-warning=ExperimentalWarning "$REVIEW_DIR/$probe.cjs"
done
bash "$REVIEW_DIR/native/run.sh"
