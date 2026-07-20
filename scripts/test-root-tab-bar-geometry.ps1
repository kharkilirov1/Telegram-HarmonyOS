Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'entry/src/main/ets/ui/utils/RootTabBarGeometry.ets'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw 'node is required for RootTabBarGeometry host tests.'
}
if (-not (Test-Path -LiteralPath $source)) {
  throw "RootTabBarGeometry source not found: $source"
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempDir = Join-Path $tempRoot ("telegram-root-tab-geometry-{0}" -f [System.Guid]::NewGuid().ToString('N'))
$resolvedTempDir = [System.IO.Path]::GetFullPath($tempDir)
if (-not $resolvedTempDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $resolvedTempDir -eq $tempRoot) {
  throw "Unsafe temporary test directory: $resolvedTempDir"
}

New-Item -ItemType Directory -Path $resolvedTempDir | Out-Null
try {
  $modulePath = Join-Path $resolvedTempDir 'RootTabBarGeometry.ts'
  $testPath = Join-Path $resolvedTempDir 'RootTabBarGeometry.test.mjs'
  Copy-Item -LiteralPath $source -Destination $modulePath

  @'
import assert from 'node:assert/strict';
import {
  computeRootTabContentBottomInset,
  resolveRootSearchDockGeometry,
  resolveRootTabBarRenderState,
  ROOT_TAB_BAR_FALLBACK_CONTENT_INSET
} from './RootTabBarGeometry.ts';

assert.deepEqual(resolveRootTabBarRenderState(2, false), {
  overlap: true,
  height: 48,
  bottomMargin: 30,
  opacity: 1,
  maskHeight: 110
});
assert.deepEqual(resolveRootTabBarRenderState(2, true), {
  overlap: false,
  height: 0,
  bottomMargin: 0,
  opacity: 0,
  maskHeight: 0
});
assert.deepEqual(resolveRootTabBarRenderState(2, false, true), {
  overlap: false,
  height: 0,
  bottomMargin: 0,
  opacity: 0,
  maskHeight: 0
});
assert.deepEqual(resolveRootTabBarRenderState(2, false, true, true), {
  overlap: true,
  height: 48,
  bottomMargin: 30,
  opacity: 1,
  maskHeight: 110
});
assert.equal(resolveRootTabBarRenderState(1, true).overlap, true);
assert.equal(resolveRootTabBarRenderState(1, true).height, 48);
assert.equal(resolveRootTabBarRenderState(1, false, true).height, 0);
assert.equal(computeRootTabContentBottomInset(0, 0), 64);
assert.equal(computeRootTabContentBottomInset(20, 24), 78);
assert.equal(computeRootTabContentBottomInset(40, 20), 94);
assert.equal(computeRootTabContentBottomInset(-10, -20), 64);
assert.equal(ROOT_TAB_BAR_FALLBACK_CONTENT_INSET, 82);
assert.deepEqual(resolveRootSearchDockGeometry(436), {
  groupWidth: 436,
  tabBarWidth: 332,
  activeTabBarWidth: 48,
  miniBarExpandedWidth: 396,
  miniBarIdleWidth: 48,
  gap: 16,
  sideMargin: 20
});
assert.deepEqual(resolveRootSearchDockGeometry(600), {
  groupWidth: 500,
  tabBarWidth: 396,
  activeTabBarWidth: 48,
  miniBarExpandedWidth: 460,
  miniBarIdleWidth: 48,
  gap: 16,
  sideMargin: 20
});
assert.equal(resolveRootSearchDockGeometry(Number.NaN).groupWidth, 436);
'@ | Set-Content -LiteralPath $testPath -Encoding utf8

  & $node.Source --experimental-strip-types $testPath
  if ($LASTEXITCODE -ne 0) {
    throw "RootTabBarGeometry host tests failed with exit code $LASTEXITCODE."
  }
  Write-Host 'RootTabBarGeometry host tests passed.'
} finally {
  if (Test-Path -LiteralPath $resolvedTempDir) {
    $cleanupPath = [System.IO.Path]::GetFullPath($resolvedTempDir)
    if ($cleanupPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
      $cleanupPath -ne $tempRoot) {
      Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    }
  }
}
