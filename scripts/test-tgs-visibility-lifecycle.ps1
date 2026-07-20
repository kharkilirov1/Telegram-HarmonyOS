$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\ui\tg_ui\atoms\TgTgsPlayer.ets'
$source = Get-Content -LiteralPath $sourcePath -Raw
$tokensPath = Join-Path $PSScriptRoot '..\entry\src\main\ets\ui\tg_ui\tokens\TgUiTokens.ets'
$tokens = Get-Content -LiteralPath $tokensPath -Raw

if ($source -notmatch '(?s)aboutToAppear\(\): void\s*\{.*?lottie\.bindContext2dToCoordinator\(this\.ctx\)') {
  throw 'TgTgsPlayer must bind its CanvasRenderingContext2D to the Lottie visibility coordinator before Canvas creation.'
}

if ($source -notmatch '(?s)aboutToDisappear\(\): void\s*\{.*?this\.destroyAnim\(\).*?lottie\.unbindContext2dFromCoordinator\(this\.ctx\)') {
  throw 'TgTgsPlayer must destroy its animation and unbind the CanvasRenderingContext2D when leaving the UI tree.'
}

if ($tokens -notmatch 'static readonly TGS_PLAYBACK_FRAME_RATE: number = 30;' -or
  $source -notmatch 'frameRate:\s*TgUiTokens\.TGS_PLAYBACK_FRAME_RATE') {
  throw 'TgTgsPlayer must cap visible Lottie playback at the package-recommended 30 fps.'
}

Write-Host 'TgTgsPlayer visibility lifecycle contract passed.'
