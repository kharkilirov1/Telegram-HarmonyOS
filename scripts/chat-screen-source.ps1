# Test-only content reader. Raw application sources are never modified.
function Get-ChatContractContent {
  param([Parameter(Position=0, Mandatory=$true)][Alias('LiteralPath')][string]$Path,
    [switch]$Raw, [string]$Encoding)
  if ((Split-Path -Leaf $Path) -ne 'TgChatScreenPage.ets') {
    if ($PSBoundParameters.ContainsKey('Encoding')) {
      return Get-Content -LiteralPath $Path -Raw:$Raw -Encoding $Encoding
    }
    return Get-Content -LiteralPath $Path -Raw:$Raw
  }
  $result = & node (Join-Path $PSScriptRoot 'chat-screen-source.cjs') --contract $Path
  if ($LASTEXITCODE -ne 0) { throw "Actual chat owner source reader failed: $Path" }
  if ($Raw) { return $result -join "`n" }
  return $result
}
function Select-ChatContractString {
  param([Parameter(Mandatory=$true)][Alias('LiteralPath')][string]$Path,
    [Parameter(Mandatory=$true)][string]$Pattern, [switch]$SimpleMatch, [switch]$Quiet,
    [switch]$CaseSensitive, [switch]$AllMatches)
  if ((Split-Path -Leaf $Path) -ne 'TgChatScreenPage.ets') {
    return Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch:$SimpleMatch -Quiet:$Quiet -CaseSensitive:$CaseSensitive -AllMatches:$AllMatches
  }
  $text = Get-ChatContractContent -LiteralPath $Path -Raw
  return Select-String -InputObject $text -Pattern $Pattern -SimpleMatch:$SimpleMatch -Quiet:$Quiet -CaseSensitive:$CaseSensitive -AllMatches:$AllMatches
}
