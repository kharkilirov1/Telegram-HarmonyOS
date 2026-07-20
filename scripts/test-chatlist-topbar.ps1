Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$bar = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets') -Raw
$filters = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatListFilterBar.ets') -Raw
$row = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets') -Raw
$archiveRow = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgArchivedChatsRow.ets') -Raw
$page = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets') -Raw
$tabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw
$darkColors = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/resources/dark/element/color.json') -Raw
$spec = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgChatListNavigationBar.md') -Raw

$checks = @(
  @{ Name = 'independent API26 action material'; Source = $bar; Text = '.systemMaterial(new uiMaterial.ImmersiveMaterial({' },
  @{ Name = 'API23 adaptive blur fallback'; Source = $bar; Text = '.backgroundBlurStyle(this.actionBlurStyle(), TgGlassPolicy.glassOptions())' },
  @{ Name = 'no legacy full width chrome plate'; Source = $bar; Reject = 'TgTopChromeBackground' },
  @{ Name = 'centered Search placeholder activates native input'; Source = $bar; Text = '.hitTestBehavior(HitTestMode.Block)' },
  @{ Name = 'Search focus state removes activation overlay'; Source = $bar; Text = '@Local private searchFocused: boolean = false' },
  @{ Name = 'native Search reports focus state'; Source = $bar; Text = '.onFocus(() => {' },
  @{ Name = 'ChatList observes the official keyboard avoid area'; Source = $page; Text = 'data.type === window.AvoidAreaType.TYPE_KEYBOARD' },
  @{ Name = 'ChatList forwards keyboard visibility to root tabs'; Source = $page; Text = 'this.onKeyboardVisibilityChange(data.area.bottomRect.height > 0)' },
  @{ Name = 'root tabs track the keyboard avoid area'; Source = $tabs; Text = '@Local private keyboardVisible: boolean = false' },
  @{ Name = 'root HDS geometry receives keyboard visibility'; Source = $tabs; Text = 'this.keyboardVisible' },
  @{ Name = 'Search exposes a stable focus id'; Source = $bar; Text = "TG_CHAT_LIST_SEARCH_INPUT_ID: string = 'tg_chat_list_search_input'" },
  @{ Name = 'Search explicitly requests focus inside overlay chrome'; Source = $bar; Text = 'getFocusController().requestFocus(TG_CHAT_LIST_SEARCH_INPUT_ID)' },
  @{ Name = 'Search keeps touch focus enabled'; Source = $bar; Text = '.focusOnTouch(true)' },
  @{ Name = 'collapsed invisible Search stops intercepting the filter rail'; Source = $bar; Text = 'this.searchHitTestMode()' },
  @{ Name = 'search collapse parameter'; Source = $bar; Text = '@Param searchCollapseProgress: number = 0' },
  @{ Name = 'filter remains attached below collapsed Search'; Source = $bar; Text = 'CHAT_LIST_NAV_SEARCH_AREA_HEIGHT * (1 - this.collapseProgress())' },
  @{ Name = 'three real local filter modes'; Source = $filters; Text = 'export enum TgChatListFilter' },
  @{ Name = 'filter API26 native material'; Source = $filters; Text = '.systemMaterial(new uiMaterial.ImmersiveMaterial({' },
  @{ Name = 'unread filter behavior'; Source = $page; Text = 'return item.unreadCount > 0;' },
  @{ Name = 'personal filter behavior'; Source = $page; Text = 'return !item.isGroup;' },
  @{ Name = 'scroll delta drives collapse'; Source = $page; Text = 'this.headerCollapseOffset + frameOffset' },
  @{ Name = 'return to list start expands Search'; Source = $page; Text = '.onReachStart(() => {' },
  @{ Name = 'expanded header includes filter rail'; Source = $tokens; Text = 'TgUiTokens.CHAT_LIST_NAV_FILTER_AREA_HEIGHT' },
  @{ Name = 'action islands reuse in-chat control size'; Source = $tokens; Text = 'CHAT_LIST_NAV_ACTION_HEIGHT: number = TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE' },
  @{ Name = 'action islands reuse in-chat response size'; Source = $tokens; Text = 'CHAT_LIST_NAV_ACTION_RESPONSE_SIZE: number = TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE' },
  @{ Name = 'compact centered Search'; Source = $tokens; Text = 'CHAT_LIST_NAV_SEARCH_HEIGHT: number = 40' },
  @{ Name = 'compact filter rail'; Source = $tokens; Text = 'CHAT_LIST_NAV_FILTER_HEIGHT: number = 32' },
  @{ Name = 'primary foreground for glass actions'; Source = $bar; Text = 'tintColor: TgUiTokens.COLOR_TEXT_TITLE' },
  @{ Name = 'chat-list scoped navigation surface'; Source = $bar; Text = '.backgroundColor(TgUiTokens.CHAT_LIST_PINNED_SURFACE_BG)' },
  @{ Name = 'navigation surface follows Search collapse'; Source = $bar; Text = 'CHAT_LIST_NAV_SEARCH_AREA_HEIGHT * this.collapseProgress()' },
  @{ Name = 'chat-list scoped Search surface'; Source = $bar; Text = '.backgroundColor(TgUiTokens.CHAT_LIST_SEARCH_SURFACE_BG)' },
  @{ Name = 'runtime rows receive chat-list surface'; Source = $page; Text = 'surfaceColor: TgUiTokens.CHAT_LIST_SURFACE_BG' },
  @{ Name = 'runtime pinned rows receive chat-list surface'; Source = $page; Text = 'pinnedSurfaceColor: TgUiTokens.CHAT_LIST_PINNED_SURFACE_BG' },
  @{ Name = 'row atom supports parent-owned surface'; Source = $row; Text = '@Param pinnedSurfaceColor: ResourceColor' },
  @{ Name = 'archive atom supports parent-owned surface'; Source = $archiveRow; Text = '@Param surfaceColor: ResourceColor' },
  @{ Name = 'dark ChatList navy palette'; Source = $darkColors; Text = '"value": "#18212D"' },
  @{ Name = 'pinned group boundary is a separator, not a gap'; Source = $page; Reject = '.height(TgUiTokens.SPACE_8)' },
  @{ Name = 'iOS collapse distance preserved'; Source = $tokens; Text = 'CHAT_LIST_NAV_SEARCH_AREA_HEIGHT: number = 54' },
  @{ Name = 'iOS source records glass containers'; Source = $spec; Text = 'GlassContextExtractableContainer' },
  @{ Name = 'story data is never fabricated'; Source = $spec; Text = 'no fake peers are shown' }
)

foreach ($check in $checks) {
  if ($check.ContainsKey('Reject')) {
    if ($check.Source.Contains($check.Reject)) {
      throw "FAIL: $($check.Name)"
    }
  } elseif (-not $check.Source.Contains($check.Text)) {
    throw "FAIL: $($check.Name)"
  }
}

Write-Output 'PASS: chat-list top-bar geometry, collapse, material and filter contracts are present'
