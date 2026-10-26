<#
.SYNOPSIS
  Report whether the current branch can take new commits, and optionally move work
  off a branch whose PR is already merged or closed.

.DESCRIPTION
  Read-only by default. Prints one JSON object describing the branch, its PRs, and a
  "verdict":
    on-default-branch   - HEAD is on main (or detached); create a feature branch first
    open-pr             - an OPEN PR exists for this branch; push to it
    no-pr               - no PR yet; push and open one
    needs-new-branch    - every PR for this branch is MERGED or CLOSED; never add
                          commits to it, move the work to a fresh branch (-NewBranch)

  With -NewBranch <name>, also moves the work: stashes uncommitted changes (including
  untracked files), creates <name> from origin/<default>, cherry-picks any commits that
  are not on the default branch and not part of the merged PR, then restores the stash.
  Nothing is pushed. Afterwards "branch" is the new branch, "verdict" is no-pr, and
  "previousBranch" is the finished branch (clean it up with post-merge-cleanup.ps1).

.EXAMPLE
  pwsh -NoProfile -File pr-state.ps1
  pwsh -NoProfile -File pr-state.ps1 -Path C:\Code\llacer -Branch claude/foo
  pwsh -NoProfile -File pr-state.ps1 -NewBranch claude/foo-followup
#>
param(
  [string]$Path = (Get-Location).Path,
  [string]$Branch,          # inspect another branch instead of HEAD (read-only)
  [string]$NewBranch,       # move the current work onto this new branch
  [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'
Set-Location $Path

function Invoke-Git { $out = & git @args 2>&1; if ($LASTEXITCODE) { throw "git $($args -join ' ') failed: $out" }; $out }
function Test-Git { & git @args *> $null; -not $LASTEXITCODE }

$default = ((Invoke-Git symbolic-ref --short refs/remotes/origin/HEAD) -replace '^origin/', '')
if (-not $NoFetch) { Invoke-Git fetch origin --quiet | Out-Null }

$current = (& git branch --show-current 2>$null)
if (-not $Branch) { $Branch = $current }
$isWorktree = (Invoke-Git rev-parse --git-dir) -ne (Invoke-Git rev-parse --git-common-dir)
$dirty = @(& git status --porcelain)

$result = [ordered]@{
  repo            = (Invoke-Git rev-parse --show-toplevel)
  isWorktree      = $isWorktree
  defaultBranch   = $default
  branch          = $Branch
  uncommitted     = $dirty.Count
  prs             = @()
  previousBranch  = $null
  verdict         = $null
  commitsToCarry  = @()
  moved           = $null
}

if (-not $Branch -or $Branch -eq $default) {
  $result.verdict = 'on-default-branch'
} else {
  $prs = gh pr list --head $Branch --state all --limit 20 `
           --json number,state,url,title,headRefOid,mergedAt,baseRefName | ConvertFrom-Json
  $result.prs = @($prs | ForEach-Object { [ordered]@{ number = $_.number; state = $_.state; url = $_.url; title = $_.title; base = $_.baseRefName; headRefOid = $_.headRefOid } })
  $open = @($prs | Where-Object state -eq 'OPEN')
  if ($open) { $result.verdict = 'open-pr' }
  elseif ($prs) { $result.verdict = 'needs-new-branch' }
  else { $result.verdict = 'no-pr' }

  # Commits on this branch that are neither on the default branch nor in a finished PR.
  # These are what must be carried to a new branch.
  $exclude = @("origin/$default")
  foreach ($p in $prs | Where-Object state -ne 'OPEN') {
    if (Test-Git cat-file -e "$($p.headRefOid)^{commit}") { $exclude += $p.headRefOid }
  }
  if (Test-Git rev-parse --verify --quiet "refs/heads/$Branch") {
    $notArgs = @($exclude | ForEach-Object { "^$_" })
    $result.commitsToCarry = @(& git rev-list --reverse $Branch @notArgs)
    if ($result.verdict -eq 'needs-new-branch') {
      # Squash-merged PRs leave the original commits off main; drop any whose patch is already upstream.
      $upstream = @(& git cherry "origin/$default" $Branch | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
      $result.commitsToCarry = @($result.commitsToCarry | Where-Object { $_ -notin $upstream })
    }
  }
}

if ($NewBranch) {
  if ($Branch -ne $current) { throw "-NewBranch moves the checked-out branch; don't combine it with -Branch." }
  if ($result.verdict -eq 'open-pr') { throw "Branch '$Branch' has an open PR; push to it instead of moving." }
  if (Test-Git rev-parse --verify --quiet "refs/heads/$NewBranch") { throw "Branch '$NewBranch' already exists." }
  $state = (Invoke-Git rev-parse --git-path MERGE_HEAD), (Invoke-Git rev-parse --git-path CHERRY_PICK_HEAD), (Invoke-Git rev-parse --git-path rebase-merge)
  if ($state | Where-Object { Test-Path $_ }) { throw "A merge, cherry-pick or rebase is in progress; finish or abort it first." }

  # The stash stack is shared by every worktree (and other sessions), so never pop the top
  # entry blindly: tag ours, remember its SHA, apply by SHA, then drop that exact entry.
  $stashSha = $null
  if ($dirty.Count) {
    $tag = "ship-move-$NewBranch-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    Invoke-Git stash push --include-untracked -m $tag | Out-Null
    $stashSha = (& git stash list --format='%H %gs' | Where-Object { $_ -like "* $tag" } | Select-Object -First 1) -replace ' .*$', ''
    if (-not $stashSha) { throw "Could not find the stash entry '$tag' just created." }
  }
  $stashed = [bool]$stashSha
  Invoke-Git switch -c $NewBranch --no-track "origin/$default" | Out-Null
  $picked = @()
  foreach ($c in $result.commitsToCarry) {
    & git cherry-pick --allow-empty $c *> $null
    if ($LASTEXITCODE) {
      $result.moved = [ordered]@{ branch = $NewBranch; ok = $false; stoppedAt = $c; picked = $picked; stashKept = $stashed; stash = $stashSha
        message = "cherry-pick of $c conflicted. Resolve, 'git cherry-pick --continue', pick the rest, then 'git stash apply $stashSha' and drop that entry." }
      $result | ConvertTo-Json -Depth 5; exit 2
    }
    $picked += $c
  }
  $popOk = $true
  if ($stashed) {
    & git stash apply $stashSha *> $null; $popOk = -not $LASTEXITCODE
    if ($popOk) {
      $ref = & git stash list --format='%gd %H' | Where-Object { $_ -like "* $stashSha" } | ForEach-Object { ($_ -split ' ')[0] }
      if ($ref) { Invoke-Git stash drop $ref | Out-Null }
    }
  }
  # Report the state you're in now; the finished branch is kept for post-merge cleanup.
  $result.previousBranch = $Branch; $result.branch = $NewBranch; $result.verdict = 'no-pr'
  $result.moved = [ordered]@{ branch = $NewBranch; from = $Branch; ok = $popOk; picked = $picked; stashKept = ($stashed -and -not $popOk)
    message = $(if ($popOk) { "Work moved to $NewBranch (based on origin/$default). Nothing pushed." }
                else { "Restoring uncommitted changes conflicted; stash $stashSha is kept. Resolve the conflicted files, then drop that stash entry." }) }
  $result | ConvertTo-Json -Depth 5
  if (-not $popOk) { exit 2 }
  exit 0
}

$result | ConvertTo-Json -Depth 5
