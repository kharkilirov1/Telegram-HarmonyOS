Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$commandPath = Join-Path $root 'entry/src/main/ets/core/model/AppCommand.ets'
$serializerPath = Join-Path $root 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$useCasePath = Join-Path $root 'entry/src/main/ets/domain/usecases/searchComposeUsers.ets'
$modelPath = Join-Path $root 'entry/src/main/ets/ui/pages/compose/ComposeContactModel.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets'

foreach ($path in @($commandPath, $serializerPath, $useCasePath, $modelPath, $pagePath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing Compose remote-search contract file: $path"
  }
}

$command = Get-Content -LiteralPath $commandPath -Raw
$serializer = Get-Content -LiteralPath $serializerPath -Raw
$useCase = Get-Content -LiteralPath $useCasePath -Raw
$model = Get-Content -LiteralPath $modelPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw

$contracts = @(
  @{ Name = 'typed searchContacts command'; Source = $command; Text = 'class SearchContactsCommand' },
  @{ Name = 'typed searchChatsOnServer command'; Source = $command; Text = 'class SearchChatsOnServerCommand' },
  @{ Name = 'typed searchPublicChats command'; Source = $command; Text = 'class SearchPublicChatsCommand' },
  @{ Name = 'searchContacts serializer'; Source = $serializer; Text = "result.method = 'searchContacts'" },
  @{ Name = 'searchChatsOnServer serializer'; Source = $serializer; Text = "result.method = 'searchChatsOnServer'" },
  @{ Name = 'searchPublicChats serializer'; Source = $serializer; Text = "result.method = 'searchPublicChats'" },
  @{ Name = 'typed Compose search use case'; Source = $useCase; Text = 'class SearchComposeUsersUseCase' },
  @{ Name = 'strict Users response parsing'; Source = $useCase; Text = "response.getType() !== 'users'" },
  @{ Name = 'strict Chats response parsing'; Source = $useCase; Text = "response.getType() !== 'chats'" },
  @{ Name = 'private-chat-only global hydration'; Source = $useCase; Text = 'ChatType.PRIVATE' },
  @{ Name = 'pure ordered Compose dedupe'; Source = $model; Text = 'mergeComposeSearchContacts' },
  @{ Name = 'remote search generation'; Source = $page; Text = 'remoteSearchGeneration' },
  @{ Name = 'remote search lifecycle guard'; Source = $page; Text = 'pageLifecycleToken' },
  @{ Name = 'timer cleanup'; Source = $page; Text = 'clearTimeout(' },
  @{ Name = 'Contacts search header'; Source = $page; Text = 'search_contacts_section' },
  @{ Name = 'Global search header'; Source = $page; Text = 'search_global_section' },
  @{ Name = 'exact private-chat selection retained'; Source = $page; Text = 'useCase.execute(contact.userId, false)' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing Compose remote-search contract: $($contract.Name)"
  }
}

Write-Host 'Compose remote-search contracts: PASS'
