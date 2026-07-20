param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-ProjectFile([string]$RelativePath) {
  $path = Join-Path $Root $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing file: $RelativePath"
  }
  return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains([string]$Content, [string]$Pattern, [string]$Message) {
  if ($Content -notmatch $Pattern) {
    throw $Message
  }
}

$command = Read-ProjectFile 'entry/src/main/ets/core/model/AppCommand.ets'
$serializer = Read-ProjectFile 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$state = Read-ProjectFile 'entry/src/main/ets/core/model/AppState.ets'
$normalizer = Read-ProjectFile 'entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets'
$reducer = Read-ProjectFile 'entry/src/main/ets/core/reducers/chatsReducer.ets'
$mainPage = Read-ProjectFile 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$archivePage = Read-ProjectFile 'entry/src/main/ets/ui/pages/chatlist/TgArchivedChatsPage.ets'
$archiveRow = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/atoms/TgArchivedChatsRow.ets'
$passport = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/spec/TgArchivedChatsRow.md'

Assert-Contains $command "chatList:\s*'main'\s*\|\s*'archive'" `
  'LoadChatsCommand does not carry an explicit main/archive chat-list selector'
Assert-Contains $serializer 'chatListArchive' `
  'CommandSerializer does not serialize TDLib chatListArchive'
Assert-Contains $serializer 'addChatToList' `
  'Archive UI cannot move chats back to TDLib chatListMain'
Assert-Contains $state 'archivedChatIds' `
  'ChatsState has no independent archived chat ordering'
Assert-Contains $state 'archiveOrder' `
  'Chat state does not preserve the TDLib archive position'
Assert-Contains $normalizer 'chatListArchive' `
  'ChatNormalizer drops chatListArchive positions'
Assert-Contains $reducer 'rebuildArchivedChatIds' `
  'Chats reducer does not rebuild a separate archive list'
Assert-Contains $mainPage 'TgArchivedChatsRow' `
  'Main chat list does not render the iOS-style archive group row'
Assert-Contains $mainPage "pushPathByName\('TgArchivedChatsPage'" `
  'Archive group row is not wired to a real archive destination'
Assert-Contains $archivePage 'state\.chats\.archivedChatIds' `
  'Archive destination is not driven by the real archive state'
Assert-Contains $archivePage 'buildArchiveSwipeActions' `
  'Archive destination has no iOS-style pin/unarchive swipe actions'
Assert-Contains $archiveRow 'export struct TgArchivedChatsRow' `
  'Archive row atom is missing'
Assert-Contains $archiveRow '\.alignItems\(HorizontalAlign\.Start\)' `
  'Archive row title/preview column is not pinned to the normal chat text axis'
Assert-Contains $passport 'Telegram-iOS-current.*ChatListNodeEntries\.swift' `
  'Archive row passport does not cite the iOS hierarchy reference'

Write-Host 'PASS: archived chat-list contract is wired end-to-end'
