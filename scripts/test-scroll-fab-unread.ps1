Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$page = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets') -Raw
$atom = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgScrollToBottomButton.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw

$contracts = @(
  @{ Name = 'live atom integration'; Source = $page; Text = 'TgScrollToBottomButton({' },
  @{ Name = 'retained unread state'; Source = $page; Text = '@Local private scrollToBottomUnreadCount: number = 0' },
  @{ Name = 'entry unread capture'; Source = $page; Text = 'entryChat ? Math.max(0, entryChat.unreadCount) : 0' },
  @{ Name = 'runtime unread raise'; Source = $page; Text = 'chat.unreadCount > this.scrollToBottomUnreadCount' },
  @{ Name = 'bottom clears unread'; Source = $page; Text = 'if (!this.showScrollToBottom)' },
  @{ Name = 'button press clears unread'; Source = $page; Text = 'private handleScrollToBottomPress(): void {' },
  @{ Name = 'iOS 40vp control'; Source = $tokens; Text = 'SCROLL_FAB_SIZE: number = 40' },
  @{ Name = 'iOS 20vp badge'; Source = $tokens; Text = 'SCROLL_FAB_BADGE_HEIGHT: number = 20' },
  @{ Name = 'iOS badge offset'; Source = $tokens; Text = 'SCROLL_FAB_BADGE_TOP_OFFSET: number = -7' },
  @{ Name = 'zero hides badge'; Source = $atom; Text = 'if (this.safeUnreadCount() > 0)' },
  @{ Name = 'compact count'; Source = $atom; Text = 'UNREAD_BADGE_COMPACT_THOUSAND' },
  @{ Name = 'non-intercepting badge'; Source = $atom; Text = '.hitTestBehavior(HitTestMode.None)' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing scroll-FAB unread contract: $($contract.Name)"
  }
}

Write-Output 'PASS: scroll-to-bottom unread badge contracts are present'
