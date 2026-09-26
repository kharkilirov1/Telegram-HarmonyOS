#!/usr/bin/env bash
set -euo pipefail

# Host-only audit reproduction. Requires a C++17 compiler and POSIX threads.
# No SDK, TDLib binary, dependency downloads, or repository build output needed.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_BUILD_DIR="$(mktemp -d /tmp/telegram-native-review.XXXXXX)"
trap 'rm -rf -- "$REVIEW_BUILD_DIR"' EXIT
REVIEW_COMPILER="${CXX:-c++}"

"$REVIEW_COMPILER" -std=c++17 -pthread -I "$SCRIPT_DIR/include" \
  "$SCRIPT_DIR/bridge_mock.cpp" -o "$REVIEW_BUILD_DIR/bridge_mock"
"$REVIEW_BUILD_DIR/bridge_mock"
