#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PHASE0_FILES=(
  "entry/src/main/ets/ui/pages/MainTabsPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets"
  "entry/src/main/ets/ui/components/common/AppTopBar.ets"
  "entry/src/main/ets/ui/components/common/AppTabBarItem.ets"
  "entry/src/main/ets/ui/components/common/AppListRow.ets"
)

HEX_PATTERN='#[0-9A-Fa-f]{3,8}'
HEX_VIOLATIONS=()

for file in "${PHASE0_FILES[@]}"; do
  full_path="$ROOT/$file"
  
  if [[ ! -f "$full_path" ]]; then
    echo "ERROR: Required file not found: $full_path" >&2
    exit 1
  fi
  
  while IFS=: read -r line_num line_content; do
    HEX_VIOLATIONS+=("$file:$line_num -> $line_content")
  done < <(grep -n "$HEX_PATTERN" "$full_path" || true)
done

if [[ ${#HEX_VIOLATIONS[@]} -gt 0 ]]; then
  echo "ERROR: Hardcoded color hex detected in Phase 0 shell/chatlist files:" >&2
  printf '%s\n' "${HEX_VIOLATIONS[@]}" >&2
  exit 1
fi

CHAT_LIST_ITEM="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets"
CHAT_LIST_PAGE="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"

if ! grep -q '@Reusable' "$CHAT_LIST_ITEM"; then
  echo "ERROR: ChatListItem must be marked with @Reusable." >&2
  exit 1
fi

if ! grep -q '\.reuseId(' "$CHAT_LIST_PAGE"; then
  echo "ERROR: ChatListPage must apply reuseId() for ChatListItem in LazyForEach." >&2
  exit 1
fi

echo "✅ Phase 0 UI smoke checks passed."
