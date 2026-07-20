Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$phase0Files = @(
  'entry/src/main/ets/ui/pages/MainTabsPage.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets',
  'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgArchivedChatsRow.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgTopBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgRootSearchDock.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatBackground.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets',
  'entry/src/main/ets/ui/utils/RootTabBarGeometry.ets'
) | ForEach-Object { Join-Path $root $_ }

$hexPattern = '#[0-9A-Fa-f]{3,8}'
$hexViolations = @()

foreach ($file in $phase0Files) {
  if (-not (Test-Path $file)) {
    throw "Required file not found: $file"
  }

  $matches = Select-String -Path $file -Pattern $hexPattern
  foreach ($match in $matches) {
    $hexViolations += "{0}:{1} -> {2}" -f $file, $match.LineNumber, $match.Line.Trim()
  }
}

if ($hexViolations.Count -gt 0) {
  $details = $hexViolations -join "`n"
  Write-Error ("Hardcoded color hex detected in Phase 0 shell/chatlist files:`n{0}" -f $details)
  exit 1
}

$chatRowFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets'
$tgUiTokensFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$archivedChatsRowFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgArchivedChatsRow.ets'
$chatMetaFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets'
$chatItemVOFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets'
$chatPreviewTextTestFile = Join-Path $root 'entry/src/ohosTest/ets/test/ChatPreviewText.test.ets'
$chatItemVOTestFile = Join-Path $root 'entry/src/ohosTest/ets/test/ChatItemVO.test.ets'
$mediaGalleryPolicyFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMediaGalleryPolicy.ets'
$mediaGalleryPolicyTestFile = Join-Path $root 'entry/src/ohosTest/ets/test/TgMediaGalleryPolicy.test.ets'
$mediaGalleryItemFile = Join-Path $root 'entry/src/main/ets/models/MediaGalleryItem.ets'
$mediaGalleryPageFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets'
$mediaBubbleShellFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMediaBubbleShellV2.ets'
$groupedPhotoBubbleFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgGroupedPhotoBubble.ets'
$videoBubbleFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgVideoBubble.ets'
$chatListPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$archivedChatListPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/TgArchivedChatsPage.ets'
$chatListNavFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets'
$rootSearchDockFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgRootSearchDock.ets'
$tgUiFeatureFlagsFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets'
$chatTopBarFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets'
$chatScreenFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$messageMetaFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMessageMeta.ets'
$messageMetaTextFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMessageMetaText.ets'
$messageRouterFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$bubbleTailFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgBubbleTail.ets'
$messageTimeContractDemoFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgMessageTimeContractDemo.ets'
$voiceBubbleFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgVoiceBubble.ets'
$dateSeparatorFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets'
$chatTimelineFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets'
$chatTimelineTestFile = Join-Path $root 'entry/src/ohosTest/ets/test/ChatTimelineVO.test.ets'
$pendingChatUnreadSnapshotFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/PendingChatUnreadSnapshot.ets'
$baseStringResourceFile = Join-Path $root 'entry/src/main/resources/base/element/string.json'
$ruStringResourceFile = Join-Path $root 'entry/src/main/resources/ru_RU/element/string.json'
$zhStringResourceFile = Join-Path $root 'entry/src/main/resources/zh_CN/element/string.json'
$mainTabsFile = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$replyHydrationCoordinatorFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ReplyHydrationCoordinator.ets'
$loadRepliedMessageFile = Join-Path $root 'entry/src/main/ets/domain/usecases/loadRepliedMessage.ets'
$commandSerializerFile = Join-Path $root 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$reducersIndexFile = Join-Path $root 'entry/src/main/ets/core/reducers/index.ets'
$chatBackgroundFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatBackground.ets'
$chatBackgroundLightTile = Join-Path $root 'entry/src/main/resources/base/media/tg_chat_wallpaper_tile.png'
$chatBackgroundDarkTile = Join-Path $root 'entry/src/main/resources/dark/media/tg_chat_wallpaper_tile.png'
$baseColorResourceFile = Join-Path $root 'entry/src/main/resources/base/element/color.json'
$darkColorResourceFile = Join-Path $root 'entry/src/main/resources/dark/element/color.json'
$rootTabBarGeometryFile = Join-Path $root 'entry/src/main/ets/ui/utils/RootTabBarGeometry.ets'
$safeAreaUtilsFile = Join-Path $root 'entry/src/main/ets/ui/utils/SafeAreaUtils.ets'
$contactsPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/contacts/ContactsPage.ets'
$callsPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/calls/CallsPage.ets'
$settingsPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/settings/SettingsPage.ets'
$profilePageFile = Join-Path $root 'entry/src/main/ets/ui/pages/profile/TgProfilePage.ets'
$profileMembersPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/profile/TgProfileMembersPage.ets'
$profileMemberRowFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgProfileMemberRow.ets'
$chatMembersUseCaseFile = Join-Path $root 'entry/src/main/ets/domain/usecases/chatMembers.ets'
$profileRouteMapFile = Join-Path $root 'entry/src/main/resources/base/profile/route_map.json'
$storyDtoFile = Join-Path $root 'entry/src/main/ets/core/model/dto/StoryDto.ets'
$storyNormalizerFile = Join-Path $root 'entry/src/main/ets/core/events/normalizers/StoryNormalizer.ets'
$loadActiveStoriesFile = Join-Path $root 'entry/src/main/ets/domain/usecases/loadActiveStories.ets'

$rootTabBarGeometryContracts = @(
  'export const ROOT_TAB_BAR_VISIBLE_HEIGHT: number = 48;',
  'export const ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN: number = 30;',
  'export const ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT: number = 110;',
  'export function resolveRootTabBarRenderState(',
  'export function computeRootTabContentBottomInset(',
  'export const ROOT_TAB_BAR_FALLBACK_CONTENT_INSET: number = 82;'
)
foreach ($contract in $rootTabBarGeometryContracts) {
  if (-not (Select-String -Path $rootTabBarGeometryFile -SimpleMatch $contract)) {
    Write-Error "RootTabBarGeometry contract declaration missing: $contract"
    exit 1
  }
}

$safeAreaSource = Get-Content -LiteralPath $safeAreaUtilsFile -Raw
$safeAreaCompactSource = $safeAreaSource -replace '\s', ''
$safeAreaGeometryImport = "import{computeRootTabContentBottomInset,ROOT_TAB_BAR_FALLBACK_CONTENT_INSET}from'./RootTabBarGeometry';"
if (-not $safeAreaCompactSource.Contains($safeAreaGeometryImport)) {
  Write-Error 'SafeAreaUtils must import the exact shared root tab content contract.'
  exit 1
}

$safeAreaGeometryContracts = @(
  'return computeRootTabContentBottomInset(systemBottomInset, navigationBottomInset);',
  'return ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;'
)
foreach ($contract in $safeAreaGeometryContracts) {
  if (-not $safeAreaSource.Contains($contract)) {
    Write-Error "SafeAreaUtils active root tab content contract missing: $contract"
    exit 1
  }
}

$rootContentPages = @($chatListPageFile, $contactsPageFile, $callsPageFile, $settingsPageFile)
$rootTabContentConsumers = @($safeAreaUtilsFile) + $rootContentPages
$legacyRootTabSymbols = @(
  'TAB_BAR_FLAT_HEIGHT',
  'TAB_BAR_ISLAND_BOTTOM_MARGIN',
  'TAB_BAR_CONTENT_SAFE_BOTTOM'
)
foreach ($consumer in $rootTabContentConsumers) {
  foreach ($legacySymbol in $legacyRootTabSymbols) {
    if (Select-String -LiteralPath $consumer -SimpleMatch $legacySymbol) {
      Write-Error "Root tab content consumer must not reference legacy geometry symbol ${legacySymbol}: $consumer"
      exit 1
    }
  }
}

$rootContentPageImport = "import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';"
foreach ($page in $rootContentPages) {
  $pageSource = Get-Content -LiteralPath $page -Raw
  if (-not $pageSource.Contains($rootContentPageImport)) {
    Write-Error "Root content page must import the exact shared fallback: $page"
    exit 1
  }
  $fallbackMentionCount = ([regex]::Matches($pageSource, 'ROOT_TAB_BAR_FALLBACK_CONTENT_INSET')).Count
  if ($fallbackMentionCount -lt 3) {
    Write-Error "Root content page must have import plus two active fallback mentions: $page"
    exit 1
  }
}

if (Select-String -Path $mainTabsFile -Pattern '^\s*const TAB_BAR_(FLOATING_VISIBLE_HEIGHT|FLOATING_BOTTOM_MARGIN|BACKPLATE_HEIGHT)(?:\s*:\s*[^=]+)?\s*=') {
  Write-Error 'MainTabsPage must not own local root tab-bar geometry constants.'
  exit 1
}

$mainTabsGeometryContracts = @(
  'resolveRootTabBarRenderState',
  'RootTabBarRenderState',
  "from '../utils/RootTabBarGeometry';",
  'this.keyboardVisible',
  '.barOverlap(this.rootTabBarRenderState().overlap)',
  '.barHeight(this.rootTabBarRenderState().height)',
  '.barFloatingStyle(',
  'barBottomMargin: this.rootTabBarRenderState().bottomMargin',
  'barOpacity: this.rootTabBarOpacity()',
  '.barBackgroundStyle(',
  'maskHeight: this.rootTabBarRenderState().maskHeight',
  'hdsMaterial.MaterialType.ADAPTIVE',
  'hdsMaterial.MaterialLevel.ADAPTIVE',
  '.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])'
)
foreach ($contract in $mainTabsGeometryContracts) {
  if (-not (Select-String -Path $mainTabsFile -SimpleMatch $contract)) {
    Write-Error "MainTabsPage native root tab contract missing: $contract"
    exit 1
  }
}

if (-not (Select-String -Path $chatRowFile -Pattern '@ComponentV2')) {
  Write-Error 'TgChatRow must be marked with @ComponentV2.'
  exit 1
}

$chatRowSource = Get-Content -LiteralPath $chatRowFile -Raw
if ($chatRowSource -notmatch '(?s)Text\(this\.titleText\(\)\).*?\.textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\).*?\.flexShrink\(1\)') {
  Write-Error 'TgChatRow title must shrink intrinsically so title decorations stay adjacent instead of drifting to the meta edge.'
  exit 1
}

foreach ($lineMetaContract in @('TgChatMetaTop({', 'TgChatMetaBottom({')) {
  if (-not $chatRowSource.Contains($lineMetaContract)) {
    Write-Error "TgChatRow must reserve top and bottom trailing metadata independently: $lineMetaContract"
    exit 1
  }
}
if ($chatRowSource.Contains('.width(TgUiTokens.CHAT_ROW_META_FIXED_WIDTH)')) {
  Write-Error 'TgChatRow must not apply one fixed right-meta width to both title and preview lines.'
  exit 1
}

if (-not (Select-String -LiteralPath $tgUiTokensFile -SimpleMatch 'static readonly CHAT_ROW_HEIGHT: number = 72;')) {
  Write-Error 'ChatList rows must keep the current Telegram iOS 72vp density contract.'
  exit 1
}

if (-not (Select-String -LiteralPath $tgUiTokensFile -SimpleMatch 'static readonly BUBBLE_MAX_WIDTH_RATIO: number = 0.85;')) {
  Write-Error 'Compact message bubbles must retain the Telegram iOS 0.85 maximum-width fill contract.'
  exit 1
}

$chatTopBarSource = Get-Content -LiteralPath $chatTopBarFile -Raw
if (-not (Select-String -LiteralPath $tgUiTokensFile -SimpleMatch "static readonly CHAT_TOP_BAR_ACTION_FOREGROUND: Resource = `$r('app.color.text_primary');") -or
  ([regex]::Matches($chatTopBarSource, 'tintColor: TgUiTokens\.CHAT_TOP_BAR_ACTION_FOREGROUND')).Count -ne 3) {
  Write-Error 'TgChatTopBar back/search/close actions must retain their shipped iOS theme-foreground token.'
  exit 1
}

$chatScreenSource = Get-Content -LiteralPath $chatScreenFile -Raw
$topBarSubtitleContracts = @(
  "localized(`$r('app.string.online').id, 'online')",
  "localized(`$r('app.string.member_role_bot').id, 'bot')",
  "localized(`$r('app.string.last_seen_recently').id, 'last seen recently')",
  "localized(`$r('app.string.chat_preview_recording_voice').id, 'recording voice...')",
  "localized(`$r('app.string.chat_preview_choosing_location').id, 'choosing location...')"
)
foreach ($contract in $topBarSubtitleContracts) {
  if (-not $chatScreenSource.Contains($contract)) {
    Write-Error "Chat top-bar subtitle localization contract missing: $contract"
    exit 1
  }
}
if ($chatScreenSource.Contains("return 'online';") -or
  $chatScreenSource.Contains("actionLabel = 'recording") -or
  $chatScreenSource.Contains("actionLabel = 'sending") -or
  $chatScreenSource.Contains("actionLabel = 'choosing") -or
  $chatScreenSource.Contains("actionLabel = 'playing")) {
  Write-Error 'Chat top-bar user/activity subtitles must not bypass app-language resources.'
  exit 1
}

$requiredTopBarSubtitleResources = @(
  'online',
  'last_seen_recently',
  'last_seen_within_week',
  'last_seen_within_month',
  'last_seen_long_ago',
  'member_role_bot',
  'subscribers_count',
  'channel_label',
  'group_label',
  'chat_preview_choosing_location',
  'chat_preview_choosing_contact',
  'chat_preview_playing_game'
)
foreach ($stringResourceFile in @($baseStringResourceFile, $ruStringResourceFile, $zhStringResourceFile)) {
  $stringResources = Get-Content -LiteralPath $stringResourceFile -Raw | ConvertFrom-Json
  foreach ($resourceName in $requiredTopBarSubtitleResources) {
    if (-not ($stringResources.string | Where-Object { $_.name -eq $resourceName -and $_.value.Length -gt 0 })) {
      Write-Error "Chat top-bar subtitle localization '$resourceName' missing: $stringResourceFile"
      exit 1
    }
  }
}

$messageMetaSource = Get-Content -LiteralPath $messageMetaFile -Raw
$messageMetaTextSource = Get-Content -LiteralPath $messageMetaTextFile -Raw
$chatTimelineSource = Get-Content -LiteralPath $chatTimelineFile -Raw
if (-not $messageMetaTextSource.Contains('export function composeMessageMetaText(') -or
  -not $messageMetaSource.Contains('Text(this.metaText())') -or
  -not $chatTimelineSource.Contains("row.editedText = message.editDate > 0")) {
  Write-Error 'Edited messages must preserve the TDLib editDate -> localized meta text -> rendered meta path.'
  exit 1
}
foreach ($stringResourceFile in @($baseStringResourceFile, $ruStringResourceFile, $zhStringResourceFile)) {
  $stringResources = Get-Content -LiteralPath $stringResourceFile -Raw | ConvertFrom-Json
  if (-not ($stringResources.string | Where-Object { $_.name -eq 'message_edited' -and $_.value.Length -gt 0 })) {
    Write-Error "Edited-message localization missing: $stringResourceFile"
    exit 1
  }
}

$archivedChatsRowSource = Get-Content -LiteralPath $archivedChatsRowFile -Raw
if ($archivedChatsRowSource -notmatch '(?s)TgChatMeta\(\{.*?unreadCount: this\.unreadCount,.*?isMuted: true,') {
  Write-Error 'TgArchivedChatsRow must use the inactive unread capsule from the iOS group-reference contract.'
  exit 1
}

foreach ($requiredPreviewFile in @($chatItemVOFile, $chatPreviewTextTestFile)) {
  if (-not (Test-Path -LiteralPath $requiredPreviewFile)) {
    Write-Error "Chat-list preview contract file missing: $requiredPreviewFile"
    exit 1
  }
}

$chatItemVOSource = Get-Content -LiteralPath $chatItemVOFile -Raw
if (-not (Test-Path -LiteralPath $chatItemVOTestFile) -or
  -not $chatItemVOSource.Contains("return status === 'online' && !isBot;")) {
  Write-Error 'ChatItemVO must suppress the ordinary online avatar marker for bot peers.'
  exit 1
}

foreach ($requiredMediaGalleryContractFile in @($mediaGalleryPolicyFile, $mediaGalleryPolicyTestFile)) {
  if (-not (Test-Path -LiteralPath $requiredMediaGalleryContractFile)) {
    Write-Error "Remote-media gallery policy file missing: $requiredMediaGalleryContractFile"
    exit 1
  }
}
$mediaGalleryPolicySource = Get-Content -LiteralPath $mediaGalleryPolicyFile -Raw
$mediaGalleryItemSource = Get-Content -LiteralPath $mediaGalleryItemFile -Raw
$mediaGalleryPageSource = Get-Content -LiteralPath $mediaGalleryPageFile -Raw
$mediaBubbleShellSource = Get-Content -LiteralPath $mediaBubbleShellFile -Raw
$groupedPhotoBubbleSource = Get-Content -LiteralPath $groupedPhotoBubbleFile -Raw
$videoBubbleSource = Get-Content -LiteralPath $videoBubbleFile -Raw
if (-not $mediaGalleryPolicySource.Contains("return 'downloadAndOpen';") -or
  -not $videoBubbleSource.Contains('resolveVisualMediaTapMode(') -or
  -not $mediaGalleryItemSource.Contains("minithumb: string = '';") -or
  -not $mediaGalleryPageSource.Contains("resolveGalleryPreviewKind(item.thumbnailPath, item.minithumb)")) {
  Write-Error 'Remote visual media must open the gallery immediately and retain a TDLib minithumb fallback.'
  exit 1
}
if (-not $mediaBubbleShellSource.Contains(".geometryTransition(mediaGeometryTransitionId(this.messageId))`n      .transition(TransitionEffect.OPACITY)") -or
  -not $mediaGalleryPageSource.Contains(".geometryTransition(mediaGeometryTransitionId(item.sourceMessageId))`n      .transition(TransitionEffect.OPACITY)") -or
  -not $groupedPhotoBubbleSource.Contains(".geometryTransition(mediaGeometryTransitionId(this.cellMessageId(frame.index)))`n      .transition(TransitionEffect.OPACITY)")) {
  Write-Error 'Media shared-element endpoints must retain an opacity transition inside the animateTo transaction.'
  exit 1
}
if (-not $mediaGalleryPolicySource.Contains('export function resolveGalleryDoubleTapTransform(') -or
  -not $mediaGalleryPolicySource.Contains('export function resolveGalleryPhotoOffset(') -or
  -not $mediaGalleryPolicySource.Contains('export function resolveGalleryPinchTransform(') -or
  -not $mediaGalleryPageSource.Contains('GestureGroup(GestureMode.Exclusive,') -or
  -not $mediaGalleryPageSource.Contains('TapGesture({ count: 2 })') -or
  -not $mediaGalleryPageSource.Contains('TapGesture({ count: 1 })') -or
  -not $mediaGalleryPageSource.Contains('event.pinchCenterX') -or
  -not $mediaGalleryPageSource.Contains('event.pinchCenterY') -or
  -not $mediaGalleryPageSource.Contains(".tag('gallery_photo_dismiss_pan')") -or
  -not $mediaGalleryPageSource.Contains(".tag('gallery_photo_zoom_pan')") -or
  -not $mediaGalleryPageSource.Contains('.onGestureRecognizerJudgeBegin(') -or
  -not $mediaGalleryPageSource.Contains('GestureJudgeResult.REJECT')) {
  Write-Error 'Gallery photo gestures must arbitrate taps, preserve the pinch focal point, clamp zoom/pan, and judge separate dismiss/zoom recognizers at gesture begin.'
  exit 1
}
foreach ($previewContract in @(
  'export function chatPreviewKindFromBracket(',
  'export function chatPreviewKindFromServiceType(',
  "`$r('app.string.sticker')",
  "`$r('app.string.chat_preview_joined_group')",
  "`$r('app.string.chat_preview_recording_voice')"
)) {
  if (-not $chatItemVOSource.Contains($previewContract)) {
    Write-Error "ChatItemVO localized preview contract missing: $previewContract"
    exit 1
  }
}

$requiredPreviewResourceKeys = @(
  'chat_preview_album',
  'chat_preview_audio',
  'chat_preview_joined_group',
  'chat_preview_service_message',
  'chat_preview_recording_voice',
  'chat_preview_sending_file'
)
foreach ($resourceFile in @(
  (Join-Path $root 'entry/src/main/resources/base/element/string.json'),
  (Join-Path $root 'entry/src/main/resources/ru_RU/element/string.json'),
  (Join-Path $root 'entry/src/main/resources/zh_CN/element/string.json')
)) {
  $resourceJson = Get-Content -LiteralPath $resourceFile -Raw | ConvertFrom-Json
  $resourceNames = @($resourceJson.string | ForEach-Object { $_.name })
  foreach ($resourceKey in $requiredPreviewResourceKeys) {
    if ($resourceNames -notcontains $resourceKey) {
      Write-Error "Localized chat-list preview key missing from ${resourceFile}: $resourceKey"
      exit 1
    }
  }
}

if (Select-String -Path $chatMetaFile -Pattern '(^|[^A-Za-z0-9_])Badge\(') {
  Write-Error 'TgChatMeta must use the project-owned chat-list unread capsule, not the stock ArkUI Badge halo.'
  exit 1
}

if (Select-String -Path $chatMetaFile -Pattern 'UNREAD_BADGE_MAX_VISIBLE_COUNT|99\+') {
  Write-Error 'TgChatMeta unread counts must use compact K/M formatting instead of 99+ clamping.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern '\.reuseId\(')) {
  Write-Error 'ChatListPage must apply reuseId() for TgChatRow in LazyForEach.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'HdsTabs\(')) {
  Write-Error 'MainTabsPage must compose HdsTabs for the API23 shell.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'barFloatingStyle\(')) {
  Write-Error 'MainTabsPage must keep the native HDS floating tab bar (user decision, iOS 26 parity).'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'chatScreenVisible')) {
  Write-Error 'MainTabsPage must react to chatScreenVisible so the root tab bar can be hidden on chat detail screens.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'barHeight\(')) {
  Write-Error 'MainTabsPage must collapse the HDS root tab bar height while a chat detail screen is visible.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern '@kit\.UIDesignKit')) {
  Write-Error 'MainTabsPage must source HDS shell components from @kit.UIDesignKit.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern 'TgChatListNavigationBar\(')) {
  Write-Error 'ChatListPage must compose TgChatListNavigationBar.'
  exit 1
}

if (-not (Select-String -Path $chatListNavFile -Pattern 'Search\(')) {
  Write-Error 'TgChatListNavigationBar must compose a Search component.'
  exit 1
}

$rootSearchDockContracts = @(
  @{ File = $tgUiFeatureFlagsFile; Text = 'static readonly USE_HDS_ROOT_SEARCH_MINIBAR: boolean = true;' },
  @{ File = $mainTabsFile; Text = 'miniBarBuilder: () => this.buildRootSearchMiniBar()' },
  @{ File = $mainTabsFile; Text = 'this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);' },
  @{ File = $mainTabsFile; Text = 'this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE);' },
  @{ File = $rootSearchDockFile; Text = 'Search({' },
  @{ File = $rootSearchDockFile; Text = ".id(ROOT_CHAT_LIST_SEARCH_INPUT_ID)" },
  @{ File = $chatListPageFile; Text = "@Param searchQuery: string = '';" }
)
foreach ($contract in $rootSearchDockContracts) {
  if (-not (Test-Path -LiteralPath $contract.File) -or
    -not (Select-String -LiteralPath $contract.File -SimpleMatch $contract.Text)) {
    Write-Error "Native HDS root Search mini-bar contract missing: $($contract.Text)"
    exit 1
  }
}

$storyContracts = @(
  @{ File = $storyDtoFile; Text = 'export class ChatActiveStoriesDto' },
  @{ File = $storyNormalizerFile; Text = "handlers.set('updateChatActiveStories', handleChatActiveStories);" },
  @{ File = $loadActiveStoriesFile; Text = 'createLoadActiveStoriesCommand()' },
  @{ File = $chatListPageFile; Text = 'storyPreviews: this.storyPreviews' },
  @{ File = $chatListPageFile; Text = 'state.chats.orderedStoryChatIds.slice(0, 3)' },
  @{ File = $chatListNavFile; Text = 'storyStripInteractive: boolean = false' },
  @{ File = $chatListNavFile; Text = 'storyActionInteractive: boolean = false' },
  @{ File = $chatListNavFile; Text = 'CHAT_LIST_STORY_RING_UNSEEN_TOP' }
)
foreach ($contract in $storyContracts) {
  if (-not (Test-Path -LiteralPath $contract.File) -or
    -not (Select-String -LiteralPath $contract.File -SimpleMatch $contract.Text)) {
    Write-Error "Real active-story ChatList contract missing: $($contract.Text)"
    exit 1
  }
}

if (-not (Select-String -Path $chatBackgroundFile -Pattern '@ComponentV2')) {
  Write-Error 'TgChatBackground must be a ComponentV2 atom.'
  exit 1
}

if (-not (Select-String -Path $chatBackgroundFile -Pattern 'objectRepeat\(ImageRepeat\.XY\)')) {
  Write-Error 'TgChatBackground must repeat its qualified raster tile on both axes.'
  exit 1
}

$hitTestNoneCount = (Select-String -Path $chatBackgroundFile -Pattern 'HitTestMode\.None' -AllMatches |
  ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
if ($hitTestNoneCount -lt 2) {
  Write-Error 'TgChatBackground root and image must both reject timeline or chrome input.'
  exit 1
}

Add-Type -AssemblyName System.Drawing
$baseColorResources = Get-Content -LiteralPath $baseColorResourceFile -Raw | ConvertFrom-Json
$baseColorMap = @{}
foreach ($colorResource in $baseColorResources.color) {
  $baseColorMap[$colorResource.name] = $colorResource.value
}
$darkColorResources = Get-Content -LiteralPath $darkColorResourceFile -Raw | ConvertFrom-Json
$darkColorMap = @{}
foreach ($colorResource in $darkColorResources.color) {
  $darkColorMap[$colorResource.name] = $colorResource.value
}
if ($darkColorMap['chat_bubble_incoming'] -ne '#1E2E3D' -or
  $darkColorMap['chat_bubble_outgoing'] -ne '#406D97') {
  Write-Error 'Dark chat bubbles must retain the shipped iOS runtime color calibration.'
  exit 1
}
if ($baseColorMap['message_meta_outgoing'] -ne '#8E8E93' -or
  $darkColorMap['message_meta_outgoing'] -ne '#9BBDE0') {
  Write-Error 'Outgoing message meta must retain its bubble-aware light/dark semantic calibration.'
  exit 1
}
$tgUiTokensSource = Get-Content -LiteralPath $tgUiTokensFile -Raw
foreach ($token in @(
  'MSG_META_TEXT_OUTGOING',
  'MSG_META_STATUS_SENT',
  'MSG_META_STATUS_READ',
  'VOICE_WAVE_INACTIVE_OUTGOING',
  'VOICE_BUBBLE_DURATION_OUTGOING',
  'DOCUMENT_ROW_META_OUTGOING'
)) {
  $contract = "static readonly ${token}: Resource = `$r('app.color.message_meta_outgoing');"
  if (-not $tgUiTokensSource.Contains($contract)) {
    Write-Error "$token must use the dedicated outgoing message-meta semantic resource."
    exit 1
  }
}
$voiceBubbleSource = Get-Content -LiteralPath $voiceBubbleFile -Raw
$voiceControlTokenContracts = @(
  "static readonly VOICE_BUBBLE_BUTTON_BG_INCOMING: Resource = `$r('app.color.telegram_blue');",
  "static readonly VOICE_BUBBLE_BUTTON_BG_OUTGOING: Resource = `$r('app.color.text_primary');",
  "static readonly VOICE_BUBBLE_BUTTON_ICON_INCOMING: Resource = `$r('app.color.unread_text');",
  "static readonly VOICE_BUBBLE_BUTTON_ICON_OUTGOING: Resource = `$r('app.color.chat_bubble_outgoing');"
)
foreach ($contract in $voiceControlTokenContracts) {
  if (-not $tgUiTokensSource.Contains($contract)) {
    Write-Error "Voice control direction contract missing: $contract"
    exit 1
  }
}
$voiceControlSourceContracts = @(
  'private buttonBackgroundColor(): ResourceColor',
  'private buttonForegroundColor(): ResourceColor',
  '.color(this.buttonForegroundColor())',
  'tintColor: this.buttonForegroundColor()',
  '.backgroundColor(this.buttonBackgroundColor())'
)
foreach ($contract in $voiceControlSourceContracts) {
  if (-not $voiceBubbleSource.Contains($contract)) {
    Write-Error "Voice control iOS palette path missing: $contract"
    exit 1
  }
}
$voiceGeometryTokenContracts = @(
  'static readonly VOICE_BUBBLE_PADDING_V: number = 0;',
  'static readonly VOICE_BUBBLE_WAVE_MAX_HEIGHT: number = 18;',
  'static readonly VOICE_BUBBLE_WAVE_AREA_HEIGHT: number = 18;',
  'static readonly VOICE_BUBBLE_WAVE_DURATION_GAP: number = 4;',
  'static readonly VOICE_BUBBLE_STATUS_OVERLAP: number = 5;',
  'static readonly VOICE_BUBBLE_STATUS_BOTTOM_INSET: number = 0;'
)
foreach ($contract in $voiceGeometryTokenContracts) {
  if (-not $tgUiTokensSource.Contains($contract)) {
    Write-Error "Voice waveform geometry contract missing: $contract"
    exit 1
  }
}
$dateSeparatorTokenContracts = @(
  'static readonly DATE_SEPARATOR_PADDING_H: number = 6;',
  'static readonly DATE_SEPARATOR_PADDING_V: number = 3;',
  'static readonly DATE_SEPARATOR_RADIUS: number = 11;',
  'static readonly DATE_SEPARATOR_MIN_HEIGHT: number = 22;',
  'static readonly SERVICE_SEPARATOR_PADDING_V: number = 4;',
  'static readonly SERVICE_SEPARATOR_RADIUS: number = 12;',
  'static readonly SERVICE_SEPARATOR_MIN_HEIGHT: number = 34;'
)
foreach ($contract in $dateSeparatorTokenContracts) {
  if (-not $tgUiTokensSource.Contains($contract)) {
    Write-Error "Date/service separator geometry contract missing: $contract"
    exit 1
  }
}
$unreadMarkerTokenContracts = @(
  'static readonly UNREAD_MARKER_FONT_SIZE: number = 13;',
  'static readonly UNREAD_MARKER_FONT_WEIGHT = FontWeight.Regular;',
  'static readonly UNREAD_MARKER_HEIGHT: number = 25;',
  'static readonly UNREAD_MARKER_RADIUS: number = 0;',
  'static readonly UNREAD_MARKER_SIDE_INSET: number = 0;',
  'static readonly UNREAD_MARKER_MAX_WIDTH_RATIO: number = 1.0;',
  'static readonly UNREAD_MARKER_MARGIN_TOP: number = 6;',
  'static readonly UNREAD_MARKER_MARGIN_BOTTOM: number = 5;'
)
foreach ($contract in $unreadMarkerTokenContracts) {
  if (-not $tgUiTokensSource.Contains($contract)) {
    Write-Error "Unread-marker iOS geometry contract missing: $contract"
    exit 1
  }
}
$dateSeparatorSource = Get-Content -LiteralPath $dateSeparatorFile -Raw
foreach ($contract in @(
  '@Param isService: boolean = false;',
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_PADDING_V : TgUiTokens.DATE_SEPARATOR_PADDING_V;',
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_MIN_HEIGHT : TgUiTokens.DATE_SEPARATOR_MIN_HEIGHT;',
  'return this.isService ? TgUiTokens.SERVICE_SEPARATOR_RADIUS : TgUiTokens.DATE_SEPARATOR_RADIUS;'
)) {
  if (-not $dateSeparatorSource.Contains($contract)) {
    Write-Error "Date/service separator variant contract missing: $contract"
    exit 1
  }
}
if (-not (Get-Content -LiteralPath $chatScreenFile -Raw).Contains('isService: true')) {
  Write-Error 'Live service-event entries must opt into the independent service capsule geometry.'
  exit 1
}
$chatScreenSource = Get-Content -LiteralPath $chatScreenFile -Raw
foreach ($contract in @(
  '.height(TgUiTokens.UNREAD_MARKER_HEIGHT)',
  '.justifyContent(FlexAlign.Center)',
  '.alignItems(VerticalAlign.Center)'
)) {
  if (-not $dateSeparatorSource.Contains($contract)) {
    Write-Error "Unread-marker atom contract missing: $contract"
    exit 1
  }
}
foreach ($contract in @(
  'top: TgUiTokens.UNREAD_MARKER_MARGIN_TOP,',
  'bottom: TgUiTokens.UNREAD_MARKER_MARGIN_BOTTOM'
)) {
  if (-not $chatScreenSource.Contains($contract)) {
    Write-Error "Unread-marker page spacing contract missing: $contract"
    exit 1
  }
}
$chatTimelineTestSource = Get-Content -LiteralPath $chatTimelineTestFile -Raw
foreach ($contract in @(
  'export function composeChatDateSeparatorLabel(',
  'export function formatChatDateSeparatorLabel(',
  "localizedString(`$r('app.string.chat_date_header').id, '{month} {day}')",
  'dateEntry.dateText = formatChatDateSeparatorLabel(message.timestamp);'
)) {
  if (-not $chatTimelineSource.Contains($contract)) {
    Write-Error "Chat date-label iOS contract missing: $contract"
    exit 1
  }
}
if ($chatTimelineSource.Contains('dayDiff > 1 && dayDiff < 7') -or
  -not $chatTimelineTestSource.Contains("expect(label).assertEqual('July 14');") -or
  -not $chatTimelineTestSource.Contains("expect(label).assertEqual('July 14, 2025');") -or
  -not $chatTimelineTestSource.Contains("expect(label).assertEqual('14 июля');")) {
  Write-Error 'Chat date labels must use localized month/day (and cross-year year), not recent-weekday abbreviations.'
  exit 1
}
foreach ($contract in @(
  'const hasStickyUnreadBoundary = stickyLastReadId.length > 0;',
  'const lastReadInbox = hasStickyUnreadBoundary ? stickyLastReadId : chat.lastReadInboxMessageId;',
  "it('should preserve a zero sticky unread boundary after live read fields reset'",
  "it('should not insert an unread marker without a sticky or live unread boundary'"
)) {
  $source = if ($contract.StartsWith("it('")) { $chatTimelineTestSource } else { $chatTimelineSource }
  if (-not $source.Contains($contract)) {
    Write-Error "Unread sticky-boundary contract missing: $contract"
    exit 1
  }
}
$pendingChatUnreadSnapshotSource = Get-Content -LiteralPath $pendingChatUnreadSnapshotFile -Raw
$chatListSource = Get-Content -LiteralPath $chatListPageFile -Raw
$archivedChatListSource = Get-Content -LiteralPath $archivedChatListPageFile -Raw
foreach ($contract in @(
  'static set(chatId: number, lastReadInboxMessageId: string, unreadCount: number): void {',
  'static consume(chatId: number): ChatUnreadEntrySnapshot | undefined {'
)) {
  if (-not $pendingChatUnreadSnapshotSource.Contains($contract)) {
    Write-Error "Unread entry-snapshot contract missing: $contract"
    exit 1
  }
}
foreach ($source in @($chatListSource, $archivedChatListSource)) {
  if (-not $source.Contains('PendingChatUnreadSnapshot.set(')) {
    Write-Error 'Chat-list unread snapshot must be captured before navigation.'
    exit 1
  }
}
foreach ($contract in @(
  'PendingChatUnreadSnapshot.consume(this.activeChatId);',
  'private hasRestoredUnreadBoundary: boolean = false;',
  'const targetIndex = this.unreadRestoreIndex;',
  'this.listInitialIndex = this.unreadRestoreIndex;'
)) {
  if (-not $chatScreenSource.Contains($contract)) {
    Write-Error "Unread marker restore contract missing: $contract"
    exit 1
  }
}
if ($chatTimelineSource.Contains('UNREAD_TRACE')) {
  Write-Error 'Temporary unread diagnostics must not ship.'
  exit 1
}
foreach ($stringResourceFile in @($baseStringResourceFile, $ruStringResourceFile, $zhStringResourceFile)) {
  $dateResourceSource = Get-Content -LiteralPath $stringResourceFile -Raw
  foreach ($resourceName in @('chat_date_header', 'chat_date_header_year', 'chat_month_jan', 'chat_month_jul', 'chat_month_dec')) {
    if (-not $dateResourceSource.Contains('"name": "' + $resourceName + '"')) {
      Write-Error "Chat date-label localization missing $resourceName in $stringResourceFile"
      exit 1
    }
  }
}
$voiceLaneContracts = @(
  'Column({ space: TgUiTokens.VOICE_BUBBLE_WAVE_DURATION_GAP })',
  '.height(TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT)',
  '.textAlign(TextAlign.Start)'
)
foreach ($contract in $voiceLaneContracts) {
  if (-not $voiceBubbleSource.Contains($contract)) {
    Write-Error "Voice waveform/duration lane contract missing: $contract"
    exit 1
  }
}
$messageRouterSource = Get-Content -LiteralPath $messageRouterFile -Raw
$voiceStatusCompactionContracts = @(
  'top: -TgUiTokens.VOICE_BUBBLE_STATUS_OVERLAP,',
  'bottom: TgUiTokens.VOICE_BUBBLE_STATUS_BOTTOM_INSET'
)
foreach ($contract in $voiceStatusCompactionContracts) {
  if (-not $messageRouterSource.Contains($contract)) {
    Write-Error "Voice status compaction contract missing: $contract"
    exit 1
  }
}
$waveformContextContract = 'this.getUIContext().getHostContext() as common.UIAbilityContext'
$waveformCanvasContract = 'getColorSync(TgUiTokens.VOICE_WAVE_INACTIVE_OUTGOING.id)'
if (-not $voiceBubbleSource.Contains($waveformContextContract) -or
  -not $voiceBubbleSource.Contains($waveformCanvasContract)) {
  Write-Error 'Outgoing inactive voice waveform must resolve its qualified secondary color for Canvas.'
  exit 1
}
$stickerMetaContract = "static readonly MSG_STICKER_META_OVERLAY_BG: string = 'rgba(0,0,0,0.2)';"
if (-not $tgUiTokensSource.Contains($stickerMetaContract)) {
  Write-Error 'Standalone sticker meta must keep the iOS FreeOutgoing 20% service-date fill.'
  exit 1
}
if (-not $messageRouterSource.Contains('this.buildOverlayMetaPill(true)') -or
  -not $messageRouterSource.Contains('.backgroundColor(isStandaloneSticker ?')) {
  Write-Error 'Sticker status must route through the dedicated free-date overlay semantic.'
  exit 1
}
$sharedRadiusCount = ([regex]::Matches($messageRouterSource, [regex]::Escape('.borderRadius(this.bubbleRadius())'))).Count
if ($sharedRadiusCount -lt 4 -or $messageRouterSource.Contains('.borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)')) {
  Write-Error 'Contact, location, poll and non-visual media must share the timeline grouped-corner resolver.'
  exit 1
}
$bubbleTailSource = Get-Content -LiteralPath $bubbleTailFile -Raw
foreach ($contract in @(
  'const w = this.getUIContext().vp2px(TgUiTokens.BUBBLE_TAIL_WIDTH);',
  'const h = this.getUIContext().vp2px(TgUiTokens.BUBBLE_TAIL_HEIGHT);'
)) {
  if (-not $bubbleTailSource.Contains($contract)) {
    Write-Error "Bubble tail must use the instance-bound UIContext conversion: $contract"
    exit 1
  }
}
$messageTimeContractDemoSource = Get-Content -LiteralPath $messageTimeContractDemoFile -Raw
foreach ($contract in @(
  "groupingFlags: 'top'",
  "groupingFlags: 'middle'",
  "groupingFlags: 'bottom'"
)) {
  if (-not $messageTimeContractDemoSource.Contains($contract)) {
    Write-Error "Message demo grouped-corner state missing: $contract"
    exit 1
  }
}

foreach ($tile in @($chatBackgroundLightTile, $chatBackgroundDarkTile)) {
  if (-not (Test-Path -LiteralPath $tile)) {
    Write-Error "Required qualified chat wallpaper tile not found: $tile"
    exit 1
  }
  $signature = [System.IO.File]::ReadAllBytes($tile)[0..7]
  if ([System.BitConverter]::ToString($signature) -ne '89-50-4E-47-0D-0A-1A-0A') {
    Write-Error "Chat wallpaper resource must be a PNG raster: $tile"
    exit 1
  }

  $bitmap = $null
  try {
    $bitmap = [System.Drawing.Bitmap]::new($tile)
    if ($bitmap.Width -ne 192 -or $bitmap.Height -ne 192) {
      throw "Chat wallpaper resource must be 192x192: $tile"
    }

    $hasFullyTransparentPixel = $false
    $hasPartialAlphaPixel = $false
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
      for ($x = 0; $x -lt $bitmap.Width; $x++) {
        $alpha = $bitmap.GetPixel($x, $y).A
        if ($alpha -eq 0) {
          $hasFullyTransparentPixel = $true
        } elseif ($alpha -ge 1 -and $alpha -le 254) {
          $hasPartialAlphaPixel = $true
        }
      }
    }

    if (-not $hasFullyTransparentPixel) {
      throw "Chat wallpaper resource must contain transparent pixels: $tile"
    }
    if (-not $hasPartialAlphaPixel) {
      throw "Chat wallpaper resource must contain partially transparent pixels: $tile"
    }
  } finally {
    if ($null -ne $bitmap) {
      $bitmap.Dispose()
    }
  }
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgChatTopBar\(')) {
  Write-Error 'TgChatScreenPage must compose TgChatTopBar.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgComposerInput\(')) {
  Write-Error 'TgChatScreenPage must compose TgComposerInput.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgMessageRouter\(')) {
  Write-Error 'TgChatScreenPage must compose TgMessageRouter.'
  exit 1
}

foreach ($requiredProfileMembersFile in @(
  $profilePageFile,
  $profileMembersPageFile,
  $profileMemberRowFile,
  $chatMembersUseCaseFile,
  $profileRouteMapFile
)) {
  if (-not (Test-Path -LiteralPath $requiredProfileMembersFile)) {
    Write-Error "Profile members contract file missing: $requiredProfileMembersFile"
    exit 1
  }
}

$profileSource = Get-Content -LiteralPath $profilePageFile -Raw
$profileMembersSource = Get-Content -LiteralPath $profileMembersPageFile -Raw
$profileMemberRowSource = Get-Content -LiteralPath $profileMemberRowFile -Raw
$chatMembersUseCaseSource = Get-Content -LiteralPath $chatMembersUseCaseFile -Raw
$profileRouteMapSource = Get-Content -LiteralPath $profileRouteMapFile -Raw

if (-not $profileSource.Contains("pushPathByName('TgProfileMembersPage'")) {
  Write-Error 'TgProfilePage must navigate its Members disclosure to the live members destination.'
  exit 1
}
if (-not $profileMembersSource.Contains('TgChatTopBar({') -or
  -not $profileMembersSource.Contains('LazyForEach(this.dataSource')) {
  Write-Error 'TgProfileMembersPage must keep native/material top chrome and lazy custom Telegram rows.'
  exit 1
}
if (-not $profileMemberRowSource.Contains('TgAvatar({') -or
  -not $profileMemberRowSource.Contains('PROFILE_MEMBER_ROLE')) {
  Write-Error 'TgProfileMemberRow must compose TgAvatar and tokenized role capsules.'
  exit 1
}
if (-not $chatMembersUseCaseSource.Contains('createGetSupergroupMembersCommand') -or
  -not $chatMembersUseCaseSource.Contains('createSearchChatMembersCommand')) {
  Write-Error 'ChatMembersUseCase must preserve pageable initial load and query search TDLib paths.'
  exit 1
}
if (-not $profileRouteMapSource.Contains('"name": "TgProfileMembersPage"')) {
  Write-Error 'Profile route map must register TgProfileMembersPage.'
  exit 1
}

$chatScreenSource = Get-Content -LiteralPath $chatScreenFile -Raw
$chatBackgroundRootPattern = 'Stack\(\{ alignContent: Alignment\.TopStart \}\) \{\s*TgChatBackground\(\)'
if ($chatScreenSource -notmatch $chatBackgroundRootPattern) {
  Write-Error 'TgChatScreenPage must keep TgChatBackground as the first root Stack child.'
  exit 1
}

foreach ($replyHydrationFile in @(
  $replyHydrationCoordinatorFile,
  $loadRepliedMessageFile,
  $commandSerializerFile,
  $reducersIndexFile
)) {
  if (-not (Test-Path -LiteralPath $replyHydrationFile)) {
    Write-Error "Reply hydration contract file missing: $replyHydrationFile"
    exit 1
  }
}
$replyHydrationCoordinatorSource = Get-Content -LiteralPath $replyHydrationCoordinatorFile -Raw
$loadRepliedMessageSource = Get-Content -LiteralPath $loadRepliedMessageFile -Raw
$commandSerializerSource = Get-Content -LiteralPath $commandSerializerFile -Raw
$reducersIndexSource = Get-Content -LiteralPath $reducersIndexFile -Raw
if (-not $chatScreenSource.Contains('scheduleMissingReplyHydration(state)') -or
  -not $replyHydrationCoordinatorSource.Contains('MAX_REPLY_HYDRATION_PER_SESSION') -or
  -not $loadRepliedMessageSource.Contains('createGetRepliedMessageCommand(chatId, replyingMessageId)') -or
  -not $commandSerializerSource.Contains("result.method = 'getRepliedMessage'") -or
  -not $reducersIndexSource.Contains("action.type === 'replyMessageHydrated'")) {
  Write-Error 'Chat reply rows must keep bounded getRepliedMessage hydration wired into the live timeline.'
  exit 1
}

Write-Host 'tg_ui shell smoke checks passed.'
