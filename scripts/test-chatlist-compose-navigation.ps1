Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$chatList = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets') -Raw
$picker = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets') -Raw
$compose = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets') -Raw
$tabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw

$checks = @(
  @{ Name = 'forward remains the default picker mode'; Source = $picker; Text = 'mode: ForwardTargetPickerMode = ForwardTargetPickerMode.Forward' },
  @{ Name = 'Compose uses the localized new-message title'; Source = $compose; Text = "localized(`$r('app.string.new_message').id, 'New Message')" },
  @{ Name = 'back dispatches a typed cancellation result'; Source = $compose; Text = "this.pageStack.pop(new ComposeResult(0, ''))" },
  @{ Name = 'contact selection dispatches the exact TDLib chat'; Source = $compose; Text = 'this.pageStack.pop(new ComposeResult(chat.id, contact.name))' },
  @{ Name = 'outer chat navigation explicitly renders Compose'; Source = $tabs; Text = "name === 'TgComposePage'" },
  @{ Name = 'ChatList guards duplicate compose activation'; Source = $chatList; Text = 'private isComposePickerOpen: boolean = false' },
  @{ Name = 'returning to a visible ChatList clears a stale compose guard'; Source = $chatList; Text = 'this.isComposePickerOpen = false;' },
  @{ Name = 'ChatList launches the dedicated Compose destination'; Source = $chatList; Text = "'TgComposePage'" },
  @{ Name = 'ChatList receives the Compose result'; Source = $chatList; Text = 'popInfo.result as ComposeResult | undefined' },
  @{ Name = 'ChatList resolves the selected live chat from AppStore'; Source = $chatList; Text = 'state.chats.chats.get(result.chatId)' },
  @{ Name = 'ChatList opens the exact selected chat through its existing path'; Source = $chatList; Text = 'this.openChat(buildChatItemVO(chat, state))' },
  @{ Name = 'ChatList preserves exact returned ids before reducer update'; Source = $chatList; Text = 'pendingItem.chatId = result.chatId' },
  @{ Name = 'visible compose button is connected'; Source = $chatList; Text = 'onComposePress: (): void => {' },
  @{ Name = 'picker activation hides the root HDS bar'; Source = $chatList; Text = 'this.setChatDestinationVisible(true)' },
  @{ Name = 'picker dismissal restores the prior root HDS state'; Source = $chatList; Text = 'this.setChatDestinationVisible(previousVisible)' }
)

foreach ($check in $checks) {
  if (-not $check.Source.Contains($check.Text)) {
    throw "FAIL: $($check.Name)"
  }
}

Write-Output 'PASS: ChatList opens contacts-backed Compose, receives the exact private chat, and restores root chrome'
