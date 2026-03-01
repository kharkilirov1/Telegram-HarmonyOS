#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Phase 0 files that must exist
phase0_files=(
  "entry/src/main/ets/ui/pages/MainTabsPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets"
  "entry/src/main/ets/ui/components/common/AppTopBar.ets"
  "entry/src/main/ets/ui/components/common/AppTabBarItem.ets"
  "entry/src/main/ets/ui/components/common/AppListRow.ets"
)

echo "Checking Phase 0 file existence..."
for file in "${phase0_files[@]}"; do
  full_path="$ROOT/$file"
  if [[ ! -f "$full_path" ]]; then
    echo "❌ Required file not found: $file"
    exit 1
  fi
done

echo "Checking for hardcoded color hex values..."
hex_pattern='#[0-9A-Fa-f]{3,8}'
violations=()

for file in "${phase0_files[@]}"; do
  full_path="$ROOT/$file"
  if grep -nE "$hex_pattern" "$full_path" >/dev/null 2>&1; then
    violations+=("$file contains hardcoded hex colors:")
    grep -nE "$hex_pattern" "$full_path" | while IFS= read -r line; do
      violations+=("  $line")
    done
  fi
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "❌ Hardcoded color hex detected in Phase 0 files:"
  printf '%s\n' "${violations[@]}"
  exit 1
fi

echo "Checking ChatListItem @Reusable decorator..."
if ! grep -q "@Reusable" "$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets"; then
  echo "❌ ChatListItem must be marked with @Reusable"
  exit 1
fi

echo "Checking ChatListPage reuseId() usage..."
if ! grep -q "\.reuseId(" "$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"; then
  echo "❌ ChatListPage must apply reuseId() for ChatListItem in LazyForEach"
  exit 1
fi

echo "✅ Phase 0 UI smoke checks passed"
