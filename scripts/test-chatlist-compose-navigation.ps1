. (Join-Path $PSScriptRoot "chat-screen-source.ps1")
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$chatList = Get-ChatContractContent -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets') -Raw
$picker = Get-ChatContractContent -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets') -Raw
$compose = Get-ChatContractContent -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets') -Raw
$tabs = Get-ChatContractContent -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$composeFlow = [regex]::Match($chatList, '(?ms)^  private openComposePicker\(\): void \{.*?^  \}').Value
$chatRouteFlow = [regex]::Match($chatList, '(?ms)^  private openChatRoute\(params: ChatScreenRouteParams\): void \{.*?^  \}').Value
if ($composeFlow.Length -eq 0 -or $chatRouteFlow.Length -eq 0) {
  throw 'FAIL: complete Compose and canonical chat-route methods must be present'
}

$checks = @(
  @{ Name = 'forward remains the default picker mode'; Source = $picker; Text = 'mode: ForwardTargetPickerMode = ForwardTargetPickerMode.Forward' },
  @{ Name = 'Compose uses the localized new-message title'; Source = $compose; Text = "localized(`$r('app.string.new_message').id, 'New Message')" },
  @{ Name = 'back dispatches a typed cancellation result'; Source = $compose; Text = "this.pageStack.pop(new ComposeResult(0, ''))" },
  @{ Name = 'contact selection dispatches the exact TDLib chat'; Source = $compose; Text = 'this.pageStack.pop(new ComposeResult(chat.id, contact.name))' },
  @{ Name = 'outer chat navigation explicitly renders Compose'; Source = $tabs; Text = "name === 'TgComposePage'" },
  @{ Name = 'ChatList guards duplicate compose activation'; Source = $chatList; Text = 'private isComposePickerOpen: boolean = false' },
  @{ Name = 'returning to a visible ChatList clears a stale compose guard'; Source = $chatList; Text = 'this.isComposePickerOpen = false;' },
  @{ Name = 'ChatList launches the dedicated Compose destination'; Source = $composeFlow; Text = "'TgComposePage'" },
  @{ Name = 'ChatList receives the Compose result'; Source = $composeFlow; Text = 'popInfo.result as ComposeResult | undefined' },
  @{ Name = 'ChatList resolves the selected live chat from captured AppStore'; Source = $composeFlow; Text = 'const state: AppState = store.getState();' },
  @{ Name = 'ChatList looks up the exact selected chat'; Source = $composeFlow; Text = 'state.chats.chats.get(result.chatId)' },
  @{ Name = 'ChatList opens the exact selected chat through its canonical route path'; Source = $composeFlow; Text = 'this.openChatRoute(params);' },
  @{ Name = 'ChatList preserves exact returned ids and missing-cache title with explicit owner'; Source = $composeFlow; Text = 'new ChatScreenRouteParams(result.chatId, chat ? chat.title : result.chatTitle, store, gateway)' },
  @{ Name = 'canonical route pushes the same params object'; Source = $chatRouteFlow; Text = "navStack.pushPathByName('TgChatScreenPage', params);" },
  @{ Name = 'Compose result rejects stale or duplicate callbacks'; Source = $composeFlow; Text = 'if (resultConsumed || !current()) return;' },
  @{ Name = 'visible compose button is connected'; Source = $chatList; Text = 'onComposePress: (): void => {' },
  @{ Name = 'picker activation hides the root HDS bar'; Source = $composeFlow; Text = 'this.setChatDestinationVisible(true)' },
  @{ Name = 'picker dismissal restores the prior root HDS state'; Source = $composeFlow; Text = 'this.setChatDestinationVisible(previousVisible)' }
)

foreach ($check in $checks) {
  if (-not $check.Source.Contains($check.Text)) {
    throw "FAIL: $($check.Name)"
  }
}

$pushIndex = $composeFlow.IndexOf('this.chatDetailStack.pushPathByName(')
foreach ($capture in @('const store = this.accountStore;', 'const gateway = this.chatGateway;')) {
  $captureIndex = $composeFlow.IndexOf($capture)
  if ($captureIndex -lt 0 -or $pushIndex -lt 0 -or $captureIndex -ge $pushIndex) {
    throw "FAIL: Compose must capture its source owner before the picker boundary: $capture"
  }
}
if ($composeFlow.Contains('getTdGatewayAdapter(') -or $composeFlow.Contains('getStore().getState()')) {
  throw 'FAIL: Compose callbacks must not reacquire global account state or gateway'
}

Write-Output 'PASS: ChatList opens contacts-backed Compose, receives the exact private chat, and restores root chrome'
