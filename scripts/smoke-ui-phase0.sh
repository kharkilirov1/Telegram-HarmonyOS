#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PHASE0_FILES=(
  "entry/src/main/ets/ui/pages/MainTabsPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
  "entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgTopBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets"
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

CHAT_ROW="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets"
CHAT_LIST_PAGE="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
CHAT_LIST_NAV="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets"
MAIN_TABS_PAGE="$ROOT/entry/src/main/ets/ui/pages/MainTabsPage.ets"
CHAT_SCREEN_PAGE="$ROOT/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets"

if ! grep -q '@Reusable' "$CHAT_ROW"; then
  echo "ERROR: TgChatRow must be marked with @Reusable." >&2
  exit 1
fi

if ! grep -q '\.reuseId(' "$CHAT_LIST_PAGE"; then
  echo "ERROR: ChatListPage must apply reuseId() for TgChatRow in LazyForEach." >&2
  exit 1
fi

if ! grep -q 'TgTabBar(' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must compose TgTabBar." >&2
  exit 1
fi

if ! grep -q 'TgChatListNavigationBar(' "$CHAT_LIST_PAGE"; then
  echo "ERROR: ChatListPage must compose TgChatListNavigationBar." >&2
  exit 1
fi

if ! grep -q 'Search(' "$CHAT_LIST_NAV"; then
  echo "ERROR: TgChatListNavigationBar must compose a Search component." >&2
  exit 1
fi

if ! grep -q 'TgChatTopBar(' "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: TgChatScreenPage must compose TgChatTopBar." >&2
  exit 1
fi

if ! grep -q 'TgMessageRouter(' "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: TgChatScreenPage must compose TgMessageRouter." >&2
  exit 1
fi

echo "✅ tg_ui shell smoke checks passed."
