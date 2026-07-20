$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..'
$playerPath = Join-Path $root 'entry\src\main\ets\ui\tg_ui\atoms\TgTgsPlayer.ets'
$typesPath = Join-Path $root 'entry\src\main\ets\types\libtg_rlottie.d.ts'
$cmakePath = Join-Path $root 'entry\src\main\cpp\CMakeLists.txt'
$nativePath = Join-Path $root 'entry\src\main\cpp\tg_rlottie_napi.cpp'

foreach ($path in @($playerPath, $typesPath, $cmakePath, $nativePath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Native TGS contract file is missing: $path"
  }
}

$player = Get-Content -LiteralPath $playerPath -Raw
$types = Get-Content -LiteralPath $typesPath -Raw
$cmake = Get-Content -LiteralPath $cmakePath -Raw
$native = Get-Content -LiteralPath $nativePath -Raw

if ($types -notmatch "declare module 'libtg_rlottie\.so'" -or
    $types -notmatch 'createAnimation' -or
    $types -notmatch 'renderFrame' -or
    $types -notmatch 'destroyAnimation') {
  throw 'libtg_rlottie.so must expose typed create/render/destroy operations.'
}

if ($cmake -notmatch 'add_library\(tg_rlottie SHARED' -or
    $cmake -notmatch 'RLOTTIE_ROOT.*/src/lottie/lottieanimation\.cpp' -or
    $cmake -notmatch 'target_link_libraries\(tg_rlottie') {
  throw 'CMake must build the vendored Telegram rlottie sources as a separate shared NAPI module.'
}

if ($native -notmatch '\.nm_modname\s*=\s*"tg_rlottie"' -or
    $native -notmatch 'napi_uint8_clamped_array' -or
    $native -notmatch 'renderSync' -or
    $native -notmatch 'DestroyAnimation') {
  throw 'Native module must register tg_rlottie, render into a reusable clamped buffer, and own explicit destruction.'
}

if ($player -notmatch "import tgRlottie.*from 'libtg_rlottie\.so'" -or
    $player -notmatch "import \{ displaySync \} from '@kit\.ArkGraphics2D'" -or
    $player -notmatch 'displaySync\.create\(\)' -or
    $player -notmatch 'tgRlottie\.renderFrame' -or
    $player -notmatch 'ctx\.putImageData' -or
    $player -notmatch 'onVisibleAreaChange' -or
    $player -notmatch 'lottie\.loadAnimation') {
  throw 'TgTgsPlayer must support opt-in native DisplaySync rendering while retaining the current Lottie fallback.'
}

if ($player -notmatch 'TGS_NATIVE_RLOTTIE_ENABLED' -or
    $player -notmatch '!TgUiTokens\.TGS_NATIVE_RLOTTIE_ENABLED') {
  throw 'The native renderer must remain behind the measured experiment gate until it beats the fallback.'
}

if ($player -notmatch '(?s)aboutToDisappear\(\): void\s*\{.*?stopNativePlayback\(\).*?destroyAnim\(\).*?unbindContext2dFromCoordinator') {
  throw 'Native and fallback render loops must both stop before the component leaves the UI tree.'
}

Write-Host 'TgTgsPlayer native renderer contract passed.'
