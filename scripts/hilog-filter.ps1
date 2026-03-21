param(
  [ValidateSet('auth', 'reply', 'media', 'runtime', 'custom')]
  [string]$Preset = 'custom',

  [string[]]$Tags = @(),

  [ValidateSet('debug', 'info', 'warn', 'error')]
  [string]$Level = 'info',

  [switch]$Reset,
  [switch]$ShowOnly,

  [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PresetTags {
  param([string]$Name)

  switch ($Name) {
    'auth' {
      return @(
        'LoginController',
        'AuthSideEffect',
        'TdGateway',
        'TdGatewayAdapter',
        'LoginRouter',
        'LoginRouterPage',
        'PhoneInputPage'
      )
    }
    'reply' {
      return @(
        'MessageDto',
        'ChatTimelineVO',
        'TgMessageRouter',
        'TgReplySnippet',
        'TgChatScreenPage'
      )
    }
    'media' {
      return @(
        'DownloadMessageMediaUseCase',
        'VoicePlaybackController',
        'TgAudioBubble',
        'TgVideoBubble',
        'TgAnimationBubble',
        'TgInlineVideoView',
        'TgInstantVideoBubble',
        'TgPhotoBubble',
        'TgMediaGalleryPage'
      )
    }
    'runtime' {
      return @(
        'AppCoreRuntime',
        'AppStore',
        'OpenChatUseCase',
        'LoadChatHistoryUseCase',
        'LoadChatsUseCase',
        'ChatListPage',
        'TgChatScreenPage'
      )
    }
    default {
      return @()
    }
  }
}

$allTags = @()
if ($Preset -ne 'custom') {
  $allTags += Get-PresetTags -Name $Preset
}
if ($Tags.Count -gt 0) {
  $allTags += $Tags
}

$allTags = $allTags |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
  Select-Object -Unique

if ($allTags.Count -eq 0) {
  throw 'No log tags specified. Use -Preset auth|reply|media|runtime or pass -Tags explicitly.'
}

$pattern = ($allTags -join '|')
$baseCommand = "hdc shell hilog | findstr ""$pattern"""

if ($ShowOnly) {
  if ($Reset) {
    Write-Host 'hdc shell hilog -r'
  }

  if ($OutputFile) {
    Write-Host "$baseCommand | Tee-Object -FilePath ""$OutputFile"""
  } else {
    Write-Host $baseCommand
  }
  exit 0
}

$hdc = Get-Command 'hdc' -ErrorAction SilentlyContinue
if (-not $hdc) {
  throw 'hdc command was not found in PATH.'
}

if ($Reset) {
  & $hdc.Source shell hilog -r
}

$levelArg = switch ($Level) {
  'debug' { 'D' }
  'info' { 'I' }
  'warn' { 'W' }
  'error' { 'E' }
}

$cmd = "hdc shell hilog -x -v color -L $levelArg | findstr ""$pattern"""

if ($OutputFile) {
  Invoke-Expression "$cmd | Tee-Object -FilePath ""$OutputFile"""
} else {
  Invoke-Expression $cmd
}
