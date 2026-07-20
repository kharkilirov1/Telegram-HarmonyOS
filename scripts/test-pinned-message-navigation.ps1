$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$useCasePath = Join-Path $root 'entry\src\main\ets\domain\usecases\loadPinnedMessage.ets'
$pagePath = Join-Path $root 'entry\src\main\ets\ui\pages\chat\TgChatScreenPage.ets'
$panelPath = Join-Path $root 'entry\src\main\ets\ui\tg_ui\atoms\TgPinnedMessagePanel.ets'
$listPath = Join-Path $root 'entry\src\main\ets\ui\tg_ui\atoms\TgPinnedMessageList.ets'
$testPath = Join-Path $root 'entry\src\ohosTest\ets\test\LoadPinnedMessage.test.ets'

$useCase = Get-Content -LiteralPath $useCasePath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$panel = Get-Content -LiteralPath $panelPath -Raw
$list = Get-Content -LiteralPath $listPath -Raw
$tests = Get-Content -LiteralPath $testPath -Raw

function Assert-Contains([string] $Text, [string] $Needle, [string] $Label) {
  if (-not $Text.Contains($Needle)) {
    throw "Missing contract: $Label ($Needle)"
  }
}

Assert-Contains $useCase 'class PinnedMessagesPage' 'typed pinned page result'
Assert-Contains $useCase "command.payload.filterType = 'Pinned'" 'exact TDLib pinned filter'
Assert-Contains $useCase "response.getInt64String('next_from_message_id')" 'int64 pagination cursor preservation'
Assert-Contains $page 'pinnedMessageTotalCount' 'page-owned exact count'
Assert-Contains $page 'pinnedMessageIndex' 'page-owned stripe index'
Assert-Contains $page 'pinnedMessagesListVisible' 'page-owned list visibility'
Assert-Contains $page 'loadMorePinnedMessages' 'paged list loading'
Assert-Contains $page 'page.nextFromMessageId === cursor' 'repeated-cursor termination guard'
Assert-Contains $page 'TgPinnedMessageList({' 'production pinned list overlay'
Assert-Contains $panel 'showTrailingAction: boolean = true' 'reusable row trailing action policy'
Assert-Contains $list 'showTrailingAction: false' 'list rows hide close/list affordance'
Assert-Contains $list '.onReachEnd(() =>' 'list pagination trigger'
Assert-Contains $tests "filterType).assertEqual('Pinned')" 'focused exact-filter test'
Assert-Contains $tests "nextFromMessageId).assertEqual('9223372036854774900')" 'focused cursor test'

if ($page -match 'TgPinnedMessagePanel\(\{(?s).*?index:\s*0,\s*\r?\n\s*totalCount:\s*1,') {
  throw 'Production panel still contains the old fake 0/1 multi-pin state.'
}

Write-Output 'Pinned-message navigation policy: PASS'
