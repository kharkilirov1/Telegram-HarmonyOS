Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$chatList = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$navBar = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets'
$dock = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgRootSearchDock.ets'
$geometry = Join-Path $root 'entry/src/main/ets/ui/utils/RootTabBarGeometry.ets'
$flags = Join-Path $root 'entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets'
$spec = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgRootSearchDock.md'

foreach ($path in @($mainTabs, $chatList, $navBar, $dock, $geometry, $flags, $spec)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Root Search dock contract file is missing: $path"
  }
}

$checks = @(
  @{ Path = $flags; Text = 'USE_HDS_ROOT_SEARCH_MINIBAR: boolean = true'; Label = 'accepted feature-flag path' },
  @{ Path = $geometry; Text = 'export function resolveRootSearchDockGeometry'; Label = 'responsive root-bar geometry' },
  @{ Path = $geometry; Text = 'activeTabBarWidth'; Label = 'active Search releases the overlapped TabBar hit box' },
  @{ Path = $geometry; Text = 'keepVisibleForKeyboard'; Label = 'active Search keyboard keep-alive' },
  @{ Path = $dock; Text = "ROOT_CHAT_LIST_SEARCH_INPUT_ID: string = 'tg_root_chat_list_search_input'"; Label = 'stable Search focus id' },
  @{ Path = $dock; Text = 'Search({'; Label = 'native ArkUI Search input' },
  @{ Path = $dock; Text = '.enableKeyboardOnFocus(true)'; Label = 'native Search focus allows the system IME' },
  @{ Path = $dock; Text = '.cancelButton({ style: CancelButtonStyle.INPUT })'; Label = 'native Search owns the clear action' },
  @{ Path = $dock; Text = 'private ensureKeyboardResize(): void'; Label = 'repeatable window resize policy' },
  @{ Path = $dock; Text = 'this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);'; Label = 'root Search restores keyboard resize' },
  @{ Path = $dock; Text = '.onTouch((event: TouchEvent) => {'; Label = 'resize policy is applied before native focus' },
  @{ Path = $dock; Text = 'if (!this.active) {'; Label = 'the first native Search focus activates HDS expansion' },
  @{ Path = $dock; Text = 'this.onActivate();'; Label = 'the mounted Search owns activation' },
  @{ Path = $dock; Text = "@Monitor('focusRequestRevision')"; Label = 'post-HDS focus request monitor' },
  @{ Path = $dock; Text = 'requestFocus(ROOT_CHAT_LIST_SEARCH_INPUT_ID)'; Label = 'native Search focus is reasserted after HDS layout' },
  @{ Path = $dock; Text = '@Param closing: boolean = false'; Label = 'explicit closing state' },
  @{ Path = $dock; Text = '.hitTestBehavior(this.closing ? HitTestMode.None : HitTestMode.Default)'; Label = 'closing interaction lock' },
  @{ Path = $dock; Text = '.accessibilityGroup(true)'; Label = 'atomic Close accessibility action' },
  @{ Path = $dock; Text = '.accessibilityRole(AccessibilityRoleType.BUTTON)'; Label = 'button role for custom Close action' },
  @{ Path = $dock; Text = ".accessibilityLevel(this.closing ? 'no-hide-descendants' : 'auto')"; Label = 'closing Search subtree is hidden from accessibility' },
  @{ Path = $dock; Text = '.accessibilityText(this.closeText)'; Label = 'localized active Close accessibility label' },
  @{ Path = $mainTabs; Text = 'miniBarBuilder: () => this.buildRootSearchMiniBar()'; Label = 'native HDS mini bar integration' },
  @{ Path = $mainTabs; Text = 'miniBarStyle: this.rootSearchMiniBarStyle()'; Label = 'deterministic API23 mini bar style' },
  @{ Path = $mainTabs; Text = 'chatListSearchFocusPending'; Label = 'one-shot post-transition focus' },
  @{ Path = $mainTabs; Text = 'chatListSearchFocusRevision'; Label = 'reactive focus request revision' },
  @{ Path = $mainTabs; Text = 'private transferRootSearchToHeader(): void'; Label = 'header/bottom Search focus hand-off' },
  @{ Path = $mainTabs; Text = 'private deferRootSearchFocusClear(): void'; Label = 'close focus clear waits until pointer dispatch completes' },
  @{ Path = $mainTabs; Text = 'this.deferRootSearchFocusClear();'; Label = 'animated close prevents resize tap-through' },
  @{ Path = $mainTabs; Text = "closeText: localized(`$r('app.string.accessibility_close_search').id, 'Close search')"; Label = 'Close action has a specific localized narration' },
  @{ Path = $mainTabs; Text = 'focusRequestRevision: this.chatListSearchFocusRevision'; Label = 'HDS completion requests focus on the mounted Search' },
  @{ Path = $chatList; Text = '@Event onHeaderSearchWillFocus'; Label = 'header focus hand-off event' },
  @{ Path = $navBar; Text = '@Event onSearchWillFocus'; Label = 'upper Search focus signal' },
  @{ Path = $mainTabs; Text = 'applyMiniBarStyle(HdsBarStyle.EXPAND)'; Label = 'native HDS expand transaction' },
  @{ Path = $mainTabs; Text = 'applyMiniBarStyle(HdsBarStyle.COLLAPSE)'; Label = 'native HDS reverse transaction' },
  @{ Path = $mainTabs; Text = 'barWidth: this.rootSearchDockBarWidthRange()'; Label = 'tab island width reservation' },
  @{ Path = $mainTabs; Text = 'barOpacity: this.rootTabBarOpacity()'; Label = 'expanded Search hides compressed tab content' },
  @{ Path = $mainTabs; Text = 'geometry.activeTabBarWidth'; Label = 'expanded dock uses the iOS 48vp collapsed tab lens' },
  @{ Path = $mainTabs; Text = 'private chatsTabAccessibilityText(): string'; Label = 'custom Chats tab accessible label helper' },
  @{ Path = $mainTabs; Text = '.accessibilityText(this.chatsTabAccessibilityText())'; Label = 'accessible label for the custom Chats tab builder' },
  @{ Path = $chatList; Text = '@Param searchQuery: string'; Label = 'parent-owned root Search query' },
  @{ Path = $chatList; Text = '@Monitor(''searchQuery'')'; Label = 'live list rebuild for root Search' },
  @{ Path = $chatList; Text = 'TgChatListNavigationBar({'; Label = 'upper collapsible Search remains composed' },
  @{ Path = $navBar; Text = 'private buildSearchRow()'; Label = 'upper collapsible Search remains available' },
  @{ Path = $spec; Text = 'TabBarComponent.swift'; Label = 'Telegram iOS source provenance' },
  @{ Path = $spec; Text = 'HdsTabs'; Label = 'HarmonyOS native implementation provenance' }
)

foreach ($check in $checks) {
  if (-not (Select-String -LiteralPath $check.Path -SimpleMatch $check.Text -Quiet)) {
    throw "Missing $($check.Label): $($check.Text)"
  }
}

$dockSource = Get-Content -LiteralPath $dock -Raw
if ($dockSource.Contains('getFocusController().clearFocus()')) {
  throw 'The Close pointer callback must not synchronously resize the app and tap through to a chat row.'
}
if ([regex]::Matches($dockSource, 'Search\(\{').Count -ne 1 -or
  $dockSource -notmatch '(?s)build\(\)\s*\{\s*Row\(\)\s*\{\s*Search\(\{.*?if\s*\(this\.active\)\s*\{\s*this\.buildCloseAction\(\)') {
  throw 'One native Search must remain mounted in idle and active states before the conditional Close action.'
}
if ($dockSource -notmatch '(?s)Search\(\{.*?\.enableKeyboardOnFocus\(true\).*?\.onTouch\(\(event:\s*TouchEvent\).*?TouchType\.Down.*?this\.ensureKeyboardResize\(\);.*?\.onFocus\(\(\)\s*=>\s*\{.*?if\s*\(!this\.active\).*?this\.onActivate\(\);') {
  throw 'The native Search must restore RESIZE on touch-down and activate HDS from the same focus session.'
}
if ($dockSource.Contains("from '@kit.IMEKit'") -or $dockSource.Contains('showTextInput(')) {
  throw 'Root Search must use the native Search focus path instead of opening a detached IME programmatically.'
}
if ([regex]::Matches($dockSource, '\.accessibilityRole\(AccessibilityRoleType\.BUTTON\)').Count -ne 1) {
  throw 'Only the custom Close search action should need an explicit Button role.'
}

$mainTabsSource = Get-Content -LiteralPath $mainTabs -Raw
$finishExpand = [regex]::Match($mainTabsSource,
  '(?s)private\s+finishRootSearchExpand\(\):\s*void\s*\{.*?(?=\r?\n\s*private\s+)')
if (-not $finishExpand.Success -or
  -not $finishExpand.Value.Contains('this.chatListSearchFocusPending = false;') -or
  -not $finishExpand.Value.Contains('this.chatListSearchFocusRevision += 1;') -or
  $finishExpand.Value.Contains('clearRootSearchFocus()')) {
  throw 'HDS expansion must reassert focus on the mounted native Search without clearing it.'
}
$chatsBuilder = [regex]::Match(
  $mainTabsSource,
  '(?s)@Builder\s+buildChatsTabBar\(\)\s*\{.*?(?=\r?\n\s*@Builder)'
)
if (-not $chatsBuilder.Success) {
  throw 'Unable to isolate buildChatsTabBar accessibility contract.'
}
if ($chatsBuilder.Value.Contains(".accessibilityLevel('yes')") -or
  $chatsBuilder.Value.Contains('.accessibilitySelected(')) {
  throw 'The inner Chats builder must label content without becoming a second HDS tab focus stop.'
}

if (Select-String -LiteralPath $chatList -SimpleMatch 'showSearchRow: false' -Quiet) {
  throw 'Bottom Search is additive on current iOS; it must not delete the upper collapsible Search.'
}

Write-Output 'Root HDS Search mini-bar contract: PASS'
