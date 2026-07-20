param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
  param([string]$Path, [string]$Pattern, [string]$Message)
  $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
  if ($content -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-NotContains {
  param([string]$Path, [string]$Pattern, [string]$Message)
  $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
  if ($content -match $Pattern) {
    throw $Message
  }
}

$composePath = Join-Path $root 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets'
$compose = Get-Content -LiteralPath $composePath -Raw
$groupIndex = $compose.IndexOf("app.string.new_group")
$contactIndex = $compose.IndexOf("app.string.new_contact")
$channelIndex = $compose.IndexOf("app.string.new_channel")
if ($groupIndex -lt 0 -or $contactIndex -le $groupIndex -or $channelIndex -le $contactIndex) {
  throw 'Compose action order must be New Group -> New Contact -> New Channel'
}
if ($compose -match 'New Secret Chat|new_secret_chat|TgNewSecret') {
  throw 'Current iOS Compose must not expose a Secret Chat action row'
}

Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets' `
  "openCreationRoute\('TgNewGroupMembersPage'\)" 'New Group route is missing'
Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets' `
  "openCreationRoute\('TgNewContactPage'\)" 'New Contact route is missing'
Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets' `
  "openCreationRoute\('TgNewChannelPage'\)" 'New Channel route is missing'
Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgComposePage.ets' `
  'Creation actions remain reachable even when the account has no contacts' `
  'No-contact action reachability contract is missing'

$routeMapPath = Join-Path $root 'entry/src/main/resources/base/profile/route_map.json'
$routeMap = Get-Content -LiteralPath $routeMapPath -Raw | ConvertFrom-Json
$routeNames = @($routeMap.routerMap | ForEach-Object { $_.name })
foreach ($routeName in @('TgNewContactPage', 'TgNewGroupMembersPage', 'TgNewGroupInfoPage', 'TgNewChannelPage')) {
  if ($routeNames -notcontains $routeName) {
    throw "Missing route_map entry: $routeName"
  }
}

Assert-Contains 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets' `
  "result.method = 'importContacts'" 'importContacts serializer is missing'
Assert-Contains 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets' `
  "result.method = 'createNewBasicGroupChat'" 'basic-group serializer is missing'
Assert-Contains 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets' `
  "result.method = 'createNewSupergroupChat'" 'channel serializer is missing'
Assert-Contains 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets' `
  '"note":null' 'Imported contact must serialize note:null'
Assert-Contains 'entry/src/main/ets/domain/usecases/createBasicGroupChat.ets' `
  'chat.type === ChatType.GROUP' 'Created basic group type guard is missing'
Assert-Contains 'entry/src/main/ets/domain/usecases/createChannelChat.ets' `
  'chat.type !== ChatType.CHANNEL' 'Created channel type guard is missing'
Assert-Contains 'entry/src/main/ets/domain/usecases/createBasicGroupChat.ets' `
  'committedChat' 'Committed group identity fallback is missing'
Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgNewGroupMembersPage.ets' `
  'MAX_BASIC_GROUP_MEMBER_COUNT' 'Group selection must enforce the TDLib member limit before submit'
Assert-Contains 'entry/src/main/ets/ui/pages/compose/TgNewContactPage.ets' `
  'new ComposeCreationResult\(0, chatTitle, 0, true\)' `
  'Unregistered contact import must dismiss as an explicit success result'
foreach ($pagePath in @(
  'entry/src/main/ets/ui/pages/compose/TgComposePage.ets',
  'entry/src/main/ets/ui/pages/compose/TgNewContactPage.ets',
  'entry/src/main/ets/ui/pages/compose/TgNewGroupMembersPage.ets',
  'entry/src/main/ets/ui/pages/compose/TgNewGroupInfoPage.ets',
  'entry/src/main/ets/ui/pages/compose/TgNewChannelPage.ets'
)) {
  Assert-Contains $pagePath 'pendingCreationResult' `
    "$pagePath must retain committed results and retry only navigation"
}
Assert-NotContains 'entry/src/main/ets/ui/pages/compose/TgNewChannelPage.ets' `
  'if \(!this\.showIntro\)' 'Back from the channel form must return to Compose, not replay the intro'

foreach ($resourcePath in @(
  'entry/src/main/resources/base/element/string.json',
  'entry/src/main/resources/ru_RU/element/string.json',
  'entry/src/main/resources/zh_CN/element/string.json'
)) {
  $resource = Get-Content -LiteralPath (Join-Path $root $resourcePath) -Raw | ConvertFrom-Json
  $names = @($resource.string | ForEach-Object { $_.name })
  foreach ($name in @(
    'new_contact',
    'channel_intro_title',
    'channel_intro_text',
    'channel_intro_create',
    'group_member_limit_reached',
    'group_members_not_added'
  )) {
    if ($names -notcontains $name) {
      throw "$resourcePath is missing $name"
    }
  }
}

Write-Output 'Compose creation contracts: PASS'
