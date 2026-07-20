$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets'
$composerPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets'
$controllerPath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatComposerController.ets'
$chatPagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$chatStatePath = Join-Path $root 'entry/src/main/ets/core/model/AppState.ets'
$chatDtoPath = Join-Path $root 'entry/src/main/ets/core/model/dto/ChatDto.ets'
$normalizerPath = Join-Path $root 'entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets'
$testPath = Join-Path $root 'entry/src/ohosTest/ets/test/TgCustomEmojiDraftPolicy.test.ets'

foreach ($path in @($policyPath, $composerPath, $controllerPath, $chatPagePath,
    $chatStatePath, $chatDtoPath, $normalizerPath, $testPath)) {
  if (-not (Test-Path $path)) {
    throw "Missing rich custom-emoji slice file: $path"
  }
}

$policy = Get-Content $policyPath -Raw
$composer = Get-Content $composerPath -Raw
$controller = Get-Content $controllerPath -Raw
$chatPage = Get-Content $chatPagePath -Raw
$chatState = Get-Content $chatStatePath -Raw
$chatDto = Get-Content $chatDtoPath -Raw
$normalizer = Get-Content $normalizerPath -Raw
$tests = Get-Content $testPath -Raw

foreach ($required in @(
    'reconcileCustomEmojiEntities',
    'replaceDraftSelection',
    'normalizeCustomEmojiEntitiesForSubstring',
    'customEmojiEntitiesEqual')) {
  if ($policy -notmatch [regex]::Escape($required)) {
    throw "Custom-emoji draft policy is missing $required"
  }
}

if ($composer -notmatch 'onTextSelectionChange' -or
    $composer -notmatch 'requestedCaretPosition' -or
    $composer -notmatch 'caretRequestRevision') {
  throw 'Composer must report selection changes and accept a programmatic caret request'
}

if ($controller -notmatch 'replaceDraftSelection' -or
    $controller -notmatch 'getDraftSelectionStart' -or
    $controller -notmatch 'setDraftSelection') {
  throw 'Composer controller must insert Unicode/custom emoji at the active selection'
}

if ($chatPage -notmatch 'reconcileCustomEmojiEntities' -or
    $chatPage -notmatch 'draftCustomEmojiEntities' -or
    $chatPage -notmatch 'customEmojiEntitiesEqual') {
  throw 'Chat page must reconcile manual edits and restore/compare draft entities'
}

if ($chatState -notmatch 'draftCustomEmojiEntities' -or
    $chatDto -notmatch 'extractCustomEmojiTextEntities' -or
    $normalizer -notmatch 'extractCustomEmojiTextEntities') {
  throw 'TDLib draft custom-emoji entities must survive normalizer -> DTO -> app state'
}

foreach ($requiredCase in @(
    'shifts an untouched entity after insertion',
    'drops an entity intersected by deletion',
    'uses UTF-16 offsets for surrogate pairs',
    'inserts custom emoji at the active selection')) {
  if ($tests -notmatch [regex]::Escape($requiredCase)) {
    throw "Focused policy tests are missing: $requiredCase"
  }
}

Write-Host 'Rich custom-emoji editing contract: PASS' -ForegroundColor Green
