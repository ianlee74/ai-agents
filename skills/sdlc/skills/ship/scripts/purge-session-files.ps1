<#
.SYNOPSIS
  Delete a session's temporary files before cleanup/archive: ai-work/, the session's temp
  folder, and (with -DiscardChanges) its uncommitted changes, so archiving leaves nothing
  on disk but the conversation.

.DESCRIPTION
  1. ai-work/ in the session's checkout. Deleted in full when the checkout is an app-made
     worktree (under .claude\worktrees\). In the main checkout it is shared with other
     sessions, so only entries untouched for -MainOlderThanDays days are deleted, and only
     with -IncludeMainCheckout.
  2. The session's temp folder: the parent of -Scratchpad (%TEMP%\claude\<project>\<session>),
     refused unless it lies under %TEMP%\claude.
  3. Reports uncommitted changes and unpushed commits. The desktop app deletes an archived
     session's worktree only when it is clean, so a dirty one stays on disk. -DiscardChanges
     (only after the user agreed to lose them) runs git reset --hard and git clean -fdx so
     the app can remove it. Nested repositories (e.g. a content/ checkout) are left alone.

  -DryRun reports sizes and changes nothing.

.EXAMPLE
  pwsh -NoProfile -File purge-session-files.ps1 -Scratchpad $scratch -DryRun
  pwsh -NoProfile -File purge-session-files.ps1 -Scratchpad $scratch
  pwsh -NoProfile -File purge-session-files.ps1 -DiscardChanges
#>
param(
  [string]$Path = (Get-Location).Path,
  [string]$Scratchpad,
  [switch]$DiscardChanges,
  [switch]$IncludeMainCheckout,
  [int]$MainOlderThanDays = 1,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
function Norm([string]$p) { [IO.Path]::GetFullPath(($p -replace '/', '\')).TrimEnd('\') }
function SizeGB($p) { '{0:N2} GB' -f (((Get-ChildItem -LiteralPath $p -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum) / 1GB) }
function Remove([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return }
  $size = SizeGB $p
  if ($DryRun) { Write-Host "  [dry-run] would delete $p ($size)"; return }
  # Remove-Item fails on very long paths; fall back to robocopy-mirroring an empty folder.
  try { Remove-Item -LiteralPath $p -Recurse -Force -EA Stop }
  catch {
    $empty = Join-Path ([IO.Path]::GetTempPath()) ("purge-empty-" + [guid]::NewGuid())
    New-Item -ItemType Directory $empty | Out-Null
    robocopy $empty $p /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    Remove-Item -LiteralPath $p -Recurse -Force -EA SilentlyContinue
    Remove-Item -LiteralPath $empty -Force -EA SilentlyContinue
  }
  if (Test-Path -LiteralPath $p) { Write-Host "  FAILED to delete $p (something may still hold files open)" }
  else { Write-Host "  deleted $p ($size)" }
}

$top = Norm (& git -C $Path rev-parse --show-toplevel)
$isWorktree = $top -like '*\.claude\worktrees\*'
Write-Host "Checkout: $top $(if ($isWorktree) {'(app worktree)'} else {'(main checkout)'})$(if ($DryRun) {'   (DRY RUN)'})"

# 1. ai-work/
$aiWork = Join-Path $top 'ai-work'
if (Test-Path -LiteralPath $aiWork) {
  if ($isWorktree) { Remove $aiWork }
  elseif ($IncludeMainCheckout) {
    $cut = (Get-Date).AddDays(-$MainOlderThanDays)
    Get-ChildItem -LiteralPath $aiWork -Force | Where-Object LastWriteTime -lt $cut | ForEach-Object { Remove $_.FullName }
  } else { Write-Host "  kept $aiWork ($(SizeGB $aiWork)): main checkout is shared; pass -IncludeMainCheckout to prune entries older than $MainOlderThanDays day(s)" }
}

# 2. Session temp folder
if ($Scratchpad) {
  $tempRoot = Norm (Join-Path ([IO.Path]::GetTempPath()) 'claude')
  $sessionDir = Split-Path (Norm $Scratchpad) -Parent
  if ($sessionDir -like "$tempRoot\*\*") { Remove $sessionDir }
  else { Write-Host "  kept ${sessionDir}: not a session folder under $tempRoot" }
}

# 3. Uncommitted changes / unpushed commits
$dirty = @(& git -C $top status --porcelain)
$branch = & git -C $top branch --show-current
$unpushed = @()
if ($branch -and (& git -C $top rev-parse --verify --quiet "refs/remotes/origin/$branch")) {
  $unpushed = @(& git -C $top rev-list "origin/$branch..HEAD")
}
if ($unpushed.Count) { Write-Host "  NOTE: $($unpushed.Count) commit(s) on $branch not pushed to origin" }
if ($dirty.Count) {
  if ($DiscardChanges) {
    if ($DryRun) { Write-Host "  [dry-run] would discard $($dirty.Count) uncommitted change(s)" }
    else { & git -C $top reset --hard --quiet; & git -C $top clean -fdx --quiet; Write-Host "  discarded $($dirty.Count) uncommitted change(s)" }
  } else {
    Write-Host "  KEEPING $($dirty.Count) uncommitted change(s); the app will keep this worktree after archive:"
    $dirty | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
  }
} elseif ($isWorktree) { Write-Host "  worktree clean: the app deletes it when the session is archived" }
else { Write-Host "  no uncommitted changes" }
