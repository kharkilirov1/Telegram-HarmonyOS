Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$composePagePath = Join-Path $root 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets'
$composeModelPath = Join-Path $root 'entry/src/main/ets/ui/pages/compose/ComposeContactModel.ets'

if (-not (Test-Path -LiteralPath $composePagePath)) {
  throw 'Missing dedicated Compose surface: TgComposePage.ets'
}
if (-not (Test-Path -LiteralPath $composeModelPath)) {
  throw 'Missing Compose contacts model: ComposeContactModel.ets'
}

$composePage = Get-Content -LiteralPath $composePagePath -Raw
$composeModel = Get-Content -LiteralPath $composeModelPath -Raw
$chatList = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets') -Raw
$mainTabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$routeMap = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/resources/base/profile/route_map.json') -Raw

$contracts = @(
  @{ Name = 'native Compose search'; Source = $composePage; Text = 'Search({ value: this.searchQuery' },
  @{ Name = 'Telegram contact atom'; Source = $composePage; Text = 'TgContactRow({' },
  @{ Name = 'contacts-backed content'; Source = $composePage; Text = 'buildComposeContacts(' },
  @{ Name = 'private chat command path'; Source = $composePage; Text = 'createPrivateChatUseCase(' },
  @{ Name = 'selection/action in-flight guard'; Source = $composePage; Text = 'if (this.isOpeningContact || this.isOpeningAction)' },
  @{ Name = 'typed cancellation result'; Source = $composePage; Text = "this.pageStack.pop(new ComposeResult(0, ''))" },
  @{ Name = 'typed selected-chat result'; Source = $composePage; Text = 'this.pageStack.pop(new ComposeResult(chat.id, contact.name))' },
  @{ Name = 'contact-only source filter'; Source = $composeModel; Text = 'if (!user.isContact || user.id === state.auth.userId || isDeletedComposeContact(user))' },
  @{ Name = 'name and username search'; Source = $composeModel; Text = "user.username.toLowerCase()" },
  @{ Name = 'phone search'; Source = $composeModel; Text = "user.phoneNumber.toLowerCase()" },
  @{ Name = 'Compose route registration'; Source = $routeMap; Text = '"name": "TgComposePage"' },
  @{ Name = 'outer destination registration'; Source = $mainTabs; Text = "name === 'TgComposePage'" },
  @{ Name = 'ChatList launches dedicated Compose route'; Source = $chatList; Text = "'TgComposePage'" }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing Compose-surface contract: $($contract.Name)"
  }
}

if ($composePage.Contains('TgChatRow({')) {
  throw 'Compose surface must render contacts, not chat-list rows'
}

Write-Output 'PASS: contacts-backed Compose surface and private-chat navigation contracts are present'
