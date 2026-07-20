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
  "entry/src/main/ets/ui/tg_ui/atoms/TgRootSearchDock.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets"
  "entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets"
  "entry/src/main/ets/ui/utils/RootTabBarGeometry.ets"
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
TG_UI_TOKENS="$ROOT/entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets"
CHAT_ITEM_VO="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets"
CHAT_ITEM_VO_TEST="$ROOT/entry/src/ohosTest/ets/test/ChatItemVO.test.ets"
MEDIA_GALLERY_POLICY="$ROOT/entry/src/main/ets/ui/tg_ui/utils/TgMediaGalleryPolicy.ets"
MEDIA_GALLERY_POLICY_TEST="$ROOT/entry/src/ohosTest/ets/test/TgMediaGalleryPolicy.test.ets"
MEDIA_GALLERY_ITEM="$ROOT/entry/src/main/ets/models/MediaGalleryItem.ets"
MEDIA_GALLERY_PAGE="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets"
MEDIA_BUBBLE_SHELL="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgMediaBubbleShellV2.ets"
VIDEO_BUBBLE="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgVideoBubble.ets"
CHAT_META="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets"
CHAT_LIST_PAGE="$ROOT/entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets"
ARCHIVED_CHAT_LIST_PAGE="$ROOT/entry/src/main/ets/ui/pages/chatlist/TgArchivedChatsPage.ets"
CHAT_LIST_NAV="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets"
ROOT_SEARCH_DOCK="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgRootSearchDock.ets"
TG_UI_FEATURE_FLAGS="$ROOT/entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets"
CHAT_TOP_BAR="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets"
BASE_STRING_RESOURCES="$ROOT/entry/src/main/resources/base/element/string.json"
RU_STRING_RESOURCES="$ROOT/entry/src/main/resources/ru_RU/element/string.json"
ZH_STRING_RESOURCES="$ROOT/entry/src/main/resources/zh_CN/element/string.json"
MESSAGE_META="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgMessageMeta.ets"
MESSAGE_META_TEXT="$ROOT/entry/src/main/ets/ui/tg_ui/utils/TgMessageMetaText.ets"
MESSAGE_ROUTER="$ROOT/entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets"
BUBBLE_TAIL="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgBubbleTail.ets"
MESSAGE_TIME_CONTRACT_DEMO="$ROOT/entry/src/main/ets/ui/tg_ui/demos/TgMessageTimeContractDemo.ets"
VOICE_BUBBLE="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgVoiceBubble.ets"
DATE_SEPARATOR="$ROOT/entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets"
CHAT_TIMELINE="$ROOT/entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets"
CHAT_TIMELINE_TEST="$ROOT/entry/src/ohosTest/ets/test/ChatTimelineVO.test.ets"
PENDING_CHAT_UNREAD_SNAPSHOT="$ROOT/entry/src/main/ets/ui/pages/chat/PendingChatUnreadSnapshot.ets"
MAIN_TABS_PAGE="$ROOT/entry/src/main/ets/ui/pages/MainTabsPage.ets"
CHAT_SCREEN_PAGE="$ROOT/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets"
ROOT_TAB_BAR_GEOMETRY="$ROOT/entry/src/main/ets/ui/utils/RootTabBarGeometry.ets"
SAFE_AREA_UTILS="$ROOT/entry/src/main/ets/ui/utils/SafeAreaUtils.ets"
CONTACTS_PAGE="$ROOT/entry/src/main/ets/ui/pages/contacts/ContactsPage.ets"
CALLS_PAGE="$ROOT/entry/src/main/ets/ui/pages/calls/CallsPage.ets"
SETTINGS_PAGE="$ROOT/entry/src/main/ets/ui/pages/settings/SettingsPage.ets"
BASE_COLOR_RESOURCES="$ROOT/entry/src/main/resources/base/element/color.json"
DARK_COLOR_RESOURCES="$ROOT/entry/src/main/resources/dark/element/color.json"

ROOT_TAB_BAR_GEOMETRY_CONTRACTS=(
  "export const ROOT_TAB_BAR_VISIBLE_HEIGHT: number = 48;"
  "export const ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN: number = 30;"
  "export const ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT: number = 110;"
  "export function resolveRootTabBarRenderState("
  "export function computeRootTabContentBottomInset("
  "export const ROOT_TAB_BAR_FALLBACK_CONTENT_INSET: number = 82;"
)
for contract in "${ROOT_TAB_BAR_GEOMETRY_CONTRACTS[@]}"; do
  if ! grep -Fq -- "$contract" "$ROOT_TAB_BAR_GEOMETRY"; then
    echo "ERROR: RootTabBarGeometry contract declaration missing: $contract" >&2
    exit 1
  fi
done

SAFE_AREA_COMPACT_SOURCE="$(tr -d '[:space:]' < "$SAFE_AREA_UTILS")"
SAFE_AREA_GEOMETRY_IMPORT="import{computeRootTabContentBottomInset,ROOT_TAB_BAR_FALLBACK_CONTENT_INSET}from'./RootTabBarGeometry';"
if [[ "$SAFE_AREA_COMPACT_SOURCE" != *"$SAFE_AREA_GEOMETRY_IMPORT"* ]]; then
  echo "ERROR: SafeAreaUtils must import the exact shared root tab content contract." >&2
  exit 1
fi

SAFE_AREA_GEOMETRY_CONTRACTS=(
  "return computeRootTabContentBottomInset(systemBottomInset, navigationBottomInset);"
  "return ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;"
)
for contract in "${SAFE_AREA_GEOMETRY_CONTRACTS[@]}"; do
  if ! grep -Fq -- "$contract" "$SAFE_AREA_UTILS"; then
    echo "ERROR: SafeAreaUtils active root tab content contract missing: $contract" >&2
    exit 1
  fi
done

ROOT_CONTENT_PAGES=("$CHAT_LIST_PAGE" "$CONTACTS_PAGE" "$CALLS_PAGE" "$SETTINGS_PAGE")
ROOT_TAB_CONTENT_CONSUMERS=("$SAFE_AREA_UTILS" "${ROOT_CONTENT_PAGES[@]}")
LEGACY_ROOT_TAB_SYMBOLS=(
  "TAB_BAR_FLAT_HEIGHT"
  "TAB_BAR_ISLAND_BOTTOM_MARGIN"
  "TAB_BAR_CONTENT_SAFE_BOTTOM"
)
for consumer in "${ROOT_TAB_CONTENT_CONSUMERS[@]}"; do
  for legacy_symbol in "${LEGACY_ROOT_TAB_SYMBOLS[@]}"; do
    if grep -Fq -- "$legacy_symbol" "$consumer"; then
      echo "ERROR: Root tab content consumer must not reference legacy geometry symbol $legacy_symbol: $consumer" >&2
      exit 1
    fi
  done
done

ROOT_CONTENT_PAGE_IMPORT="import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';"
for page in "${ROOT_CONTENT_PAGES[@]}"; do
  if ! grep -Fq -- "$ROOT_CONTENT_PAGE_IMPORT" "$page"; then
    echo "ERROR: Root content page must import the exact shared fallback: $page" >&2
    exit 1
  fi
  fallback_mention_count="$(awk '{ count += gsub(/ROOT_TAB_BAR_FALLBACK_CONTENT_INSET/, "&") } END { print count + 0 }' "$page")"
  if (( fallback_mention_count < 3 )); then
    echo "ERROR: Root content page must have import plus two active fallback mentions: $page" >&2
    exit 1
  fi
done

if grep -Eq '^[[:space:]]*const TAB_BAR_(FLOATING_VISIBLE_HEIGHT|FLOATING_BOTTOM_MARGIN|BACKPLATE_HEIGHT)([[:space:]]*:[[:space:]]*[^=]+)?[[:space:]]*=' "$MAIN_TABS_PAGE"; then
  echo "ERROR: MainTabsPage must not own local root tab-bar geometry constants." >&2
  exit 1
fi

MAIN_TABS_GEOMETRY_CONTRACTS=(
  "resolveRootTabBarRenderState"
  "RootTabBarRenderState"
  "from '../utils/RootTabBarGeometry';"
  "this.keyboardVisible"
  ".barOverlap(this.rootTabBarRenderState().overlap)"
  ".barHeight(this.rootTabBarRenderState().height)"
  ".barFloatingStyle("
  "barBottomMargin: this.rootTabBarRenderState().bottomMargin"
  "barOpacity: this.rootTabBarOpacity()"
  ".barBackgroundStyle("
  "maskHeight: this.rootTabBarRenderState().maskHeight"
  "hdsMaterial.MaterialType.ADAPTIVE"
  "hdsMaterial.MaterialLevel.ADAPTIVE"
  ".expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])"
)
for contract in "${MAIN_TABS_GEOMETRY_CONTRACTS[@]}"; do
  if ! grep -Fq -- "$contract" "$MAIN_TABS_PAGE"; then
    echo "ERROR: MainTabsPage native root tab contract missing: $contract" >&2
    exit 1
  fi
done

if ! grep -q '@ComponentV2' "$CHAT_ROW"; then
  echo "ERROR: TgChatRow must be marked with @ComponentV2." >&2
  exit 1
fi

for line_meta_contract in 'TgChatMetaTop({' 'TgChatMetaBottom({'; do
  if ! grep -Fq "$line_meta_contract" "$CHAT_ROW"; then
    echo "ERROR: TgChatRow must reserve top and bottom trailing metadata independently: $line_meta_contract" >&2
    exit 1
  fi
done

if grep -Fq '.width(TgUiTokens.CHAT_ROW_META_FIXED_WIDTH)' "$CHAT_ROW"; then
  echo "ERROR: TgChatRow must not apply one fixed right-meta width to both title and preview lines." >&2
  exit 1
fi

if ! grep -Fq 'static readonly CHAT_ROW_HEIGHT: number = 72;' "$TG_UI_TOKENS"; then
  echo "ERROR: ChatList rows must keep the current Telegram iOS 72vp density contract." >&2
  exit 1
fi

if [[ ! -f "$CHAT_ITEM_VO_TEST" ]] ||
   ! grep -Fq "return status === 'online' && !isBot;" "$CHAT_ITEM_VO"; then
  echo "ERROR: ChatItemVO must suppress the ordinary online avatar marker for bot peers." >&2
  exit 1
fi

if [[ ! -f "$MEDIA_GALLERY_POLICY" || ! -f "$MEDIA_GALLERY_POLICY_TEST" ]] ||
   ! grep -Fq "return 'downloadAndOpen';" "$MEDIA_GALLERY_POLICY" ||
   ! grep -Fq 'resolveVisualMediaTapMode(' "$VIDEO_BUBBLE" ||
   ! grep -Fq "minithumb: string = '';" "$MEDIA_GALLERY_ITEM" ||
   ! grep -Fq 'resolveGalleryPreviewKind(item.thumbnailPath, item.minithumb)' "$MEDIA_GALLERY_PAGE"; then
  echo "ERROR: Remote visual media must open the gallery immediately and retain a TDLib minithumb fallback." >&2
  exit 1
fi
if ! grep -A1 -Fq '.geometryTransition(mediaGeometryTransitionId(this.messageId))' "$MEDIA_BUBBLE_SHELL" ||
   ! grep -A1 -Fq '.transition(TransitionEffect.OPACITY)' "$MEDIA_BUBBLE_SHELL" ||
   ! grep -A1 -Fq '.geometryTransition(mediaGeometryTransitionId(item.sourceMessageId))' "$MEDIA_GALLERY_PAGE" ||
   ! grep -A1 -Fq '.transition(TransitionEffect.OPACITY)' "$MEDIA_GALLERY_PAGE"; then
  echo "ERROR: Media shared-element endpoints must retain an opacity transition inside the animateTo transaction." >&2
  exit 1
fi
if ! grep -Fq 'export function resolveGalleryDoubleTapTransform(' "$MEDIA_GALLERY_POLICY" ||
   ! grep -Fq 'export function resolveGalleryPhotoOffset(' "$MEDIA_GALLERY_POLICY" ||
   ! grep -Fq 'export function resolveGalleryPinchTransform(' "$MEDIA_GALLERY_POLICY" ||
   ! grep -Fq 'GestureGroup(GestureMode.Exclusive,' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq 'TapGesture({ count: 2 })' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq 'TapGesture({ count: 1 })' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq 'event.pinchCenterX' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq 'event.pinchCenterY' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq ".tag('gallery_photo_dismiss_pan')" "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq ".tag('gallery_photo_zoom_pan')" "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq '.onGestureRecognizerJudgeBegin(' "$MEDIA_GALLERY_PAGE" ||
   ! grep -Fq 'GestureJudgeResult.REJECT' "$MEDIA_GALLERY_PAGE"; then
  echo "ERROR: Gallery photo gestures must arbitrate taps, preserve the pinch focal point, clamp zoom/pan, and judge separate dismiss/zoom recognizers at gesture begin." >&2
  exit 1
fi

if ! grep -Fq 'static readonly BUBBLE_MAX_WIDTH_RATIO: number = 0.85;' "$TG_UI_TOKENS"; then
  echo "ERROR: Compact message bubbles must retain the Telegram iOS 0.85 maximum-width fill contract." >&2
  exit 1
fi

if ! grep -Fq "static readonly CHAT_TOP_BAR_ACTION_FOREGROUND: Resource = \$r('app.color.text_primary');" "$TG_UI_TOKENS" ||
   [[ "$(grep -Fc 'tintColor: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND' "$CHAT_TOP_BAR")" -ne 3 ]]; then
  echo "ERROR: TgChatTopBar back/search/close actions must retain their shipped iOS theme-foreground token." >&2
  exit 1
fi

TOP_BAR_SUBTITLE_CONTRACTS=(
  "localized(\$r('app.string.online').id, 'online')"
  "localized(\$r('app.string.member_role_bot').id, 'bot')"
  "localized(\$r('app.string.last_seen_recently').id, 'last seen recently')"
  "localized(\$r('app.string.chat_preview_recording_voice').id, 'recording voice...')"
  "localized(\$r('app.string.chat_preview_choosing_location').id, 'choosing location...')"
)
for contract in "${TOP_BAR_SUBTITLE_CONTRACTS[@]}"; do
  if ! grep -Fq "$contract" "$CHAT_SCREEN_PAGE"; then
    echo "ERROR: Chat top-bar subtitle localization contract missing: $contract" >&2
    exit 1
  fi
done
if grep -Fq "return 'online';" "$CHAT_SCREEN_PAGE" ||
   grep -Eq "actionLabel = '(recording|sending|choosing|playing)" "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: Chat top-bar user/activity subtitles must not bypass app-language resources." >&2
  exit 1
fi

TOP_BAR_SUBTITLE_RESOURCES=(
  online
  last_seen_recently
  last_seen_within_week
  last_seen_within_month
  last_seen_long_ago
  member_role_bot
  subscribers_count
  channel_label
  group_label
  chat_preview_choosing_location
  chat_preview_choosing_contact
  chat_preview_playing_game
)
for string_resource in "$BASE_STRING_RESOURCES" "$RU_STRING_RESOURCES" "$ZH_STRING_RESOURCES"; do
  for resource_name in "${TOP_BAR_SUBTITLE_RESOURCES[@]}"; do
    if ! grep -Fq "\"name\": \"$resource_name\"" "$string_resource"; then
      echo "ERROR: Chat top-bar subtitle localization '$resource_name' missing: $string_resource" >&2
      exit 1
    fi
  done
done

if ! grep -Fq 'export function composeMessageMetaText(' "$MESSAGE_META_TEXT" ||
   ! grep -Fq 'Text(this.metaText())' "$MESSAGE_META" ||
   ! grep -Fq 'row.editedText = message.editDate > 0' "$CHAT_TIMELINE"; then
  echo "ERROR: Edited messages must preserve the TDLib editDate -> localized meta text -> rendered meta path." >&2
  exit 1
fi
for string_resource in \
  "$ROOT/entry/src/main/resources/base/element/string.json" \
  "$ROOT/entry/src/main/resources/ru_RU/element/string.json" \
  "$ROOT/entry/src/main/resources/zh_CN/element/string.json"; do
  if ! grep -Fq '"name": "message_edited"' "$string_resource"; then
    echo "ERROR: Edited-message localization missing: $string_resource" >&2
    exit 1
  fi
done

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

ROOT_SEARCH_DOCK_CONTRACTS=(
  "$TG_UI_FEATURE_FLAGS|static readonly USE_HDS_ROOT_SEARCH_MINIBAR: boolean = true;"
  "$MAIN_TABS_PAGE|miniBarBuilder: () => this.buildRootSearchMiniBar()"
  "$MAIN_TABS_PAGE|this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);"
  "$MAIN_TABS_PAGE|this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE);"
  "$ROOT_SEARCH_DOCK|Search({"
  "$ROOT_SEARCH_DOCK|.id(ROOT_CHAT_LIST_SEARCH_INPUT_ID)"
  "$CHAT_LIST_PAGE|@Param searchQuery: string = '';"
)
for contract in "${ROOT_SEARCH_DOCK_CONTRACTS[@]}"; do
  file="${contract%%|*}"
  text="${contract#*|}"
  if [[ ! -f "$file" ]] || ! grep -Fq -- "$text" "$file"; then
    echo "ERROR: Native HDS root Search mini-bar contract missing: $text" >&2
    exit 1
  fi
done

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

if ! grep -Fq '"value": "#1E2E3D"' "$DARK_COLOR_RESOURCES" ||
   ! grep -Fq '"value": "#406D97"' "$DARK_COLOR_RESOURCES"; then
  echo "ERROR: Dark chat bubbles must retain the shipped iOS runtime color calibration." >&2
  exit 1
fi

if ! grep -Fq '"name": "message_meta_outgoing"' "$BASE_COLOR_RESOURCES" ||
   ! grep -Fq '"value": "#8E8E93"' "$BASE_COLOR_RESOURCES" ||
   ! grep -Fq '"name": "message_meta_outgoing"' "$DARK_COLOR_RESOURCES" ||
   ! grep -Fq '"value": "#9BBDE0"' "$DARK_COLOR_RESOURCES"; then
  echo "ERROR: Outgoing message meta must retain its bubble-aware light/dark semantic calibration." >&2
  exit 1
fi

for token in MSG_META_TEXT_OUTGOING MSG_META_STATUS_SENT MSG_META_STATUS_READ \
  VOICE_WAVE_INACTIVE_OUTGOING VOICE_BUBBLE_DURATION_OUTGOING DOCUMENT_ROW_META_OUTGOING; do
  if ! grep -Fq "static readonly $token: Resource = \$r('app.color.message_meta_outgoing');" "$TG_UI_TOKENS"; then
    echo "ERROR: $token must use the dedicated outgoing message-meta semantic resource." >&2
    exit 1
  fi
done

for contract in \
  "static readonly VOICE_BUBBLE_BUTTON_BG_INCOMING: Resource = \$r('app.color.telegram_blue');" \
  "static readonly VOICE_BUBBLE_BUTTON_BG_OUTGOING: Resource = \$r('app.color.text_primary');" \
  "static readonly VOICE_BUBBLE_BUTTON_ICON_INCOMING: Resource = \$r('app.color.unread_text');" \
  "static readonly VOICE_BUBBLE_BUTTON_ICON_OUTGOING: Resource = \$r('app.color.chat_bubble_outgoing');"; do
  if ! grep -Fq "$contract" "$TG_UI_TOKENS"; then
    echo "ERROR: Voice control direction contract missing: $contract" >&2
    exit 1
  fi
done

if ! grep -Fq 'isService: true' "$CHAT_SCREEN_PAGE"; then
  echo "ERROR: Live service-event entries must opt into the independent service capsule geometry." >&2
  exit 1
fi

for contract in \
  'export function composeChatDateSeparatorLabel(' \
  'export function formatChatDateSeparatorLabel(' \
  "localizedString(\$r('app.string.chat_date_header').id, '{month} {day}')" \
  'dateEntry.dateText = formatChatDateSeparatorLabel(message.timestamp);'; do
  if ! grep -Fq "$contract" "$CHAT_TIMELINE"; then
    echo "ERROR: Chat date-label iOS contract missing: $contract" >&2
    exit 1
  fi
done
if grep -Fq 'dayDiff > 1 && dayDiff < 7' "$CHAT_TIMELINE" ||
   ! grep -Fq "expect(label).assertEqual('July 14');" "$CHAT_TIMELINE_TEST" ||
   ! grep -Fq "expect(label).assertEqual('July 14, 2025');" "$CHAT_TIMELINE_TEST" ||
   ! grep -Fq "expect(label).assertEqual('14 июля');" "$CHAT_TIMELINE_TEST"; then
  echo "ERROR: Chat date labels must use localized month/day (and cross-year year), not recent-weekday abbreviations." >&2
  exit 1
fi
for string_resource in \
  "$ROOT/entry/src/main/resources/base/element/string.json" \
  "$ROOT/entry/src/main/resources/ru_RU/element/string.json" \
  "$ROOT/entry/src/main/resources/zh_CN/element/string.json"; do
  for resource_name in chat_date_header chat_date_header_year chat_month_jan chat_month_jul chat_month_dec; do
    if ! grep -Fq "\"name\": \"$resource_name\"" "$string_resource"; then
      echo "ERROR: Chat date-label localization missing $resource_name in $string_resource" >&2
      exit 1
    fi
  done
done

for contract in \
  'private buttonBackgroundColor(): ResourceColor' \
  'private buttonForegroundColor(): ResourceColor' \
  '.color(this.buttonForegroundColor())' \
  'tintColor: this.buttonForegroundColor()' \
  '.backgroundColor(this.buttonBackgroundColor())'; do
  if ! grep -Fq "$contract" "$VOICE_BUBBLE"; then
    echo "ERROR: Voice control iOS palette path missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'static readonly VOICE_BUBBLE_PADDING_V: number = 0;' \
  'static readonly VOICE_BUBBLE_WAVE_MAX_HEIGHT: number = 18;' \
  'static readonly VOICE_BUBBLE_WAVE_AREA_HEIGHT: number = 18;' \
  'static readonly VOICE_BUBBLE_WAVE_DURATION_GAP: number = 4;' \
  'static readonly VOICE_BUBBLE_STATUS_OVERLAP: number = 5;' \
  'static readonly VOICE_BUBBLE_STATUS_BOTTOM_INSET: number = 0;'; do
  if ! grep -Fq "$contract" "$TG_UI_TOKENS"; then
    echo "ERROR: Voice waveform geometry contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'static readonly DATE_SEPARATOR_PADDING_H: number = 6;' \
  'static readonly DATE_SEPARATOR_PADDING_V: number = 3;' \
  'static readonly DATE_SEPARATOR_RADIUS: number = 11;' \
  'static readonly DATE_SEPARATOR_MIN_HEIGHT: number = 22;' \
  'static readonly SERVICE_SEPARATOR_PADDING_V: number = 4;' \
  'static readonly SERVICE_SEPARATOR_RADIUS: number = 12;' \
  'static readonly SERVICE_SEPARATOR_MIN_HEIGHT: number = 34;'; do
  if ! grep -Fq "$contract" "$TG_UI_TOKENS"; then
    echo "ERROR: Date/service separator geometry contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'static readonly UNREAD_MARKER_FONT_SIZE: number = 13;' \
  'static readonly UNREAD_MARKER_FONT_WEIGHT = FontWeight.Regular;' \
  'static readonly UNREAD_MARKER_HEIGHT: number = 25;' \
  'static readonly UNREAD_MARKER_RADIUS: number = 0;' \
  'static readonly UNREAD_MARKER_SIDE_INSET: number = 0;' \
  'static readonly UNREAD_MARKER_MAX_WIDTH_RATIO: number = 1.0;' \
  'static readonly UNREAD_MARKER_MARGIN_TOP: number = 6;' \
  'static readonly UNREAD_MARKER_MARGIN_BOTTOM: number = 5;'; do
  if ! grep -Fq "$contract" "$TG_UI_TOKENS"; then
    echo "ERROR: Unread-marker iOS geometry contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  '.height(TgUiTokens.UNREAD_MARKER_HEIGHT)' \
  '.justifyContent(FlexAlign.Center)' \
  '.alignItems(VerticalAlign.Center)'; do
  if ! grep -Fq "$contract" "$DATE_SEPARATOR"; then
    echo "ERROR: Unread-marker atom contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'top: TgUiTokens.UNREAD_MARKER_MARGIN_TOP,' \
  'bottom: TgUiTokens.UNREAD_MARKER_MARGIN_BOTTOM'; do
  if ! grep -Fq "$contract" "$CHAT_SCREEN_PAGE"; then
    echo "ERROR: Unread-marker page spacing contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'const hasStickyUnreadBoundary = stickyLastReadId.length > 0;' \
  'const lastReadInbox = hasStickyUnreadBoundary ? stickyLastReadId : chat.lastReadInboxMessageId;'; do
  if ! grep -Fq "$contract" "$CHAT_TIMELINE"; then
    echo "ERROR: Unread sticky-boundary runtime contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  "it('should preserve a zero sticky unread boundary after live read fields reset'" \
  "it('should not insert an unread marker without a sticky or live unread boundary'"; do
  if ! grep -Fq "$contract" "$CHAT_TIMELINE_TEST"; then
    echo "ERROR: Unread sticky-boundary test contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'static set(chatId: number, lastReadInboxMessageId: string, unreadCount: number): void {' \
  'static consume(chatId: number): ChatUnreadEntrySnapshot | undefined {'; do
  if ! grep -Fq "$contract" "$PENDING_CHAT_UNREAD_SNAPSHOT"; then
    echo "ERROR: Unread entry-snapshot contract missing: $contract" >&2
    exit 1
  fi
done

for source in "$CHAT_LIST_PAGE" "$ARCHIVED_CHAT_LIST_PAGE"; do
  if ! grep -Fq 'PendingChatUnreadSnapshot.set(' "$source"; then
    echo "ERROR: Chat-list unread snapshot must be captured before navigation: $source" >&2
    exit 1
  fi
done

for contract in \
  'PendingChatUnreadSnapshot.consume(this.activeChatId);' \
  'private hasRestoredUnreadBoundary: boolean = false;' \
  'const targetIndex = this.unreadRestoreIndex;' \
  'this.listInitialIndex = this.unreadRestoreIndex;'; do
  if ! grep -Fq "$contract" "$CHAT_SCREEN_PAGE"; then
    echo "ERROR: Unread marker restore contract missing: $contract" >&2
    exit 1
  fi
done

if grep -Fq 'UNREAD_TRACE' "$CHAT_TIMELINE"; then
  echo 'ERROR: Temporary unread diagnostics must not ship.' >&2
  exit 1
fi

for contract in \
  '@Param isService: boolean = false;' \
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_PADDING_V : TgUiTokens.DATE_SEPARATOR_PADDING_V;' \
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_MIN_HEIGHT : TgUiTokens.DATE_SEPARATOR_MIN_HEIGHT;' \
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_RADIUS : TgUiTokens.DATE_SEPARATOR_RADIUS;'; do
  if ! grep -Fq "$contract" "$DATE_SEPARATOR"; then
    echo "ERROR: Date/service separator variant contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'top: -TgUiTokens.VOICE_BUBBLE_STATUS_OVERLAP,' \
  'bottom: TgUiTokens.VOICE_BUBBLE_STATUS_BOTTOM_INSET'; do
  if ! grep -Fq "$contract" "$MESSAGE_ROUTER"; then
    echo "ERROR: Voice status compaction contract missing: $contract" >&2
    exit 1
  fi
done

for contract in \
  'Column({ space: TgUiTokens.VOICE_BUBBLE_WAVE_DURATION_GAP })' \
  '.height(TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT)' \
  '.textAlign(TextAlign.Start)'; do
  if ! grep -Fq "$contract" "$VOICE_BUBBLE"; then
    echo "ERROR: Voice waveform/duration lane contract missing: $contract" >&2
    exit 1
  fi
done

if ! grep -Fq 'this.getUIContext().getHostContext() as common.UIAbilityContext' "$VOICE_BUBBLE" ||
   ! grep -Fq 'getColorSync(TgUiTokens.VOICE_WAVE_INACTIVE_OUTGOING.id)' "$VOICE_BUBBLE"; then
  echo "ERROR: Outgoing inactive voice waveform must resolve its qualified secondary color for Canvas." >&2
  exit 1
fi

if ! grep -Fq "static readonly MSG_STICKER_META_OVERLAY_BG: string = 'rgba(0,0,0,0.2)';" "$TG_UI_TOKENS"; then
  echo "ERROR: Standalone sticker meta must keep the iOS FreeOutgoing 20% service-date fill." >&2
  exit 1
fi
if ! grep -Fq 'this.buildOverlayMetaPill(true)' "$MESSAGE_ROUTER" ||
   ! grep -Fq '.backgroundColor(isStandaloneSticker ?' "$MESSAGE_ROUTER"; then
  echo "ERROR: Sticker status must route through the dedicated free-date overlay semantic." >&2
  exit 1
fi

if [[ "$(grep -Fc '.borderRadius(this.bubbleRadius())' "$MESSAGE_ROUTER")" -lt 4 ]] ||
   grep -Fq '.borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)' "$MESSAGE_ROUTER"; then
  echo "ERROR: Contact, location, poll and non-visual media must share the timeline grouped-corner resolver." >&2
  exit 1
fi

for contract in \
  'const w = this.getUIContext().vp2px(TgUiTokens.BUBBLE_TAIL_WIDTH);' \
  'const h = this.getUIContext().vp2px(TgUiTokens.BUBBLE_TAIL_HEIGHT);'; do
  if ! grep -Fq "$contract" "$BUBBLE_TAIL"; then
    echo "ERROR: Bubble tail must use the instance-bound UIContext conversion: $contract" >&2
    exit 1
  fi
done

for contract in \
  "groupingFlags: 'top'" \
  "groupingFlags: 'middle'" \
  "groupingFlags: 'bottom'"; do
  if ! grep -Fq "$contract" "$MESSAGE_TIME_CONTRACT_DEMO"; then
    echo "ERROR: Message demo grouped-corner state missing: $contract" >&2
    exit 1
  fi
done

echo "tg_ui shell smoke checks passed."
