#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PHASE0_FILES=(
  "entry/src/main/ets/ui/pages/MainTabsPage.ets"
  "entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
  "entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgTopBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets"
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
CHAT_META="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets"
CHAT_LIST_PAGE="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
CHAT_LIST_NAV="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets"
MAIN_TABS_PAGE="$ROOT/entry/src/main/ets/ui/pages/MainTabsPage.ets"
CHAT_SCREEN_PAGE="$ROOT/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets"

if ! grep -q '@ComponentV2' "$CHAT_ROW"; then
  echo "ERROR: TgChatRow must be marked with @ComponentV2." >&2
  exit 1
fi

if grep -Eq '(^|[^[:alnum:]_])Badge\(' "$CHAT_META"; then
  echo "ERROR: TgChatMeta must use the project-owned chat-list unread capsule, not the stock ArkUI Badge halo." >&2
  exit 1
fi

if grep -Eq 'UNREAD_BADGE_MAX_VISIBLE_COUNT|99\+' "$CHAT_META"; then
  echo "ERROR: TgChatMeta unread counts must use compact K/M formatting instead of 99+ clamping." >&2
  exit 1
fi

if ! grep -q '\.reuseId(' "$CHAT_LIST_PAGE"; then
  echo "ERROR: ChatListPage must apply reuseId() for TgChatRow in LazyForEach." >&2
  exit 1
fi

if ! grep -q 'HdsTabs(' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must compose HdsTabs for the API23 shell." >&2
  exit 1
fi

if ! grep -q 'barFloatingStyle(' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must keep HdsTabs floating bar style enabled." >&2
  exit 1
fi

if ! grep -q 'chatScreenVisible' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must react to chatScreenVisible so the root tab bar can be hidden on chat detail screens." >&2
  exit 1
fi

if ! grep -q 'barOpacity' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must fade the HDS root tab bar out while a chat detail screen is visible." >&2
  exit 1
fi

if ! grep -q 'barHeight(' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must collapse the HDS root tab bar height while a chat detail screen is visible." >&2
  exit 1
fi

if ! grep -q '@kit\.UIDesignKit' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must source HDS shell components from @kit.UIDesignKit." >&2
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

if ! grep -q 'TgComposerInput(' "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: TgChatScreenPage must compose TgComposerInput." >&2
  exit 1
fi

if ! grep -q 'TgMessageRouter(' "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: TgChatScreenPage must compose TgMessageRouter." >&2
  exit 1
fi

echo "tg_ui shell smoke checks passed."
