<#
.SYNOPSIS
  Branch and worktree hygiene after a PR merges.

.DESCRIPTION
  For each branch (default: the branch checked out where you run it):
    1. Confirms GitHub reports a MERGED PR for it and no OPEN one; otherwise skips it.
    2. Confirms the local branch has nothing beyond what was merged; otherwise keeps it.
    3. Removes clean worktrees under .claude/worktrees/ that sit on the branch (or are
       detached on one of the PR's commits). The worktree you run from is never removed:
       if it is clean it is detached onto origin/<default> so the branch can be deleted,
       and the desktop app removes it when the session is archived.
    4. Deletes the local branch (git branch -d, or -D once the PR is confirmed MERGED).
    5. Deletes the remote branch if it still exists.
  Then: git fetch --prune, fast-forwards the main checkout's default branch, and
  git worktree prune.

  Worktrees with uncommitted changes, and branches with an OPEN PR, are never touched.
  -DryRun prints the plan and changes nothing (it fetches without --prune).

.EXAMPLE
  pwsh -NoProfile -File post-merge-cleanup.ps1 -DryRun
  pwsh -NoProfile -File post-merge-cleanup.ps1 -Branch claude/foo -Path C:\Code\llacer
  pwsh -NoProfile -File post-merge-cleanup.ps1 -AllMerged -DryRun    # sweep every local branch
#>
param(
  [string]$Path = (Get-Location).Path,
  [string[]]$Branch,
  [switch]$AllMerged,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-Location $Path

function Invoke-Git { $out = & git @args 2>&1; if ($LASTEXITCODE) { throw "git $($args -join ' ') failed: $out" }; $out }
function Test-Git { & git @args *> $null; -not $LASTEXITCODE }
function Norm([string]$p) { if ($p) { [IO.Path]::GetFullPath(($p -replace '/', '\')).TrimEnd('\').ToLowerInvariant() } }
$log = [Collections.Generic.List[string]]::new()
function Say([string]$m) { $log.Add($m); Write-Host $m }
function Act([string]$what, [scriptblock]$do) {
  if ($DryRun) { Say "  [dry-run] would $what"; return $true }
  try { & $do | Out-Null; Say "  $what"; return $true } catch { Say "  FAILED to $what : $_"; return $false }
}

$here = Norm (Invoke-Git rev-parse --show-toplevel)
$mainCheckout = Split-Path (Norm (Resolve-Path (Invoke-Git rev-parse --git-common-dir)).Path) -Parent
$default = ((Invoke-Git symbolic-ref --short refs/remotes/origin/HEAD) -replace '^origin/', '')

Say "Repo: $mainCheckout   default: $default   running in: $here$(if ($DryRun) {'   (DRY RUN)'})"
if ($DryRun) { Invoke-Git fetch origin --quiet | Out-Null } else { Invoke-Git fetch origin --prune --quiet | Out-Null }

function Get-Worktrees {
  $list = @(); $cur = $null
  foreach ($line in (Invoke-Git -C $mainCheckout worktree list --porcelain)) {
    if ($line -like 'worktree *') { if ($cur) { $list += $cur }; $cur = [ordered]@{ path = Norm $line.Substring(9); head = $null; branch = $null } }
    elseif ($line -like 'HEAD *') { $cur.head = $line.Substring(5) }
    elseif ($line -like 'branch *') { $cur.branch = $line.Substring(7) -replace '^refs/heads/', '' }
  }
  if ($cur) { $list += $cur }
  $list
}

# pwsh -File passes "-Branch a,b" as one string; accept commas as separators.
$Branch = @($Branch | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($AllMerged) {
  $Branch = @(Invoke-Git for-each-ref --format='%(refname:short)' refs/heads | Where-Object { $_ -ne $default })
} elseif (-not $Branch) {
  $b = & git branch --show-current
  if (-not $b) { throw "Detached HEAD: pass -Branch <name>." }
  $Branch = @($b)
}

$summary = [ordered]@{ deleted = @(); kept = @(); worktreesRemoved = @(); worktreesKept = @() }

foreach ($br in $Branch) {
  if ($br -eq $default) { Say "Skip $br (default branch)"; continue }
  Say "Branch $br"
  $prs = @(gh pr list --head $br --state all --limit 20 --json number,state,headRefOid,commits | ConvertFrom-Json)
  $open = @($prs | Where-Object state -eq 'OPEN')
  $merged = @($prs | Where-Object state -eq 'MERGED')
  if ($open) { Say "  keep: PR #$($open[0].number) is still OPEN"; $summary.kept += "$br (open PR #$($open[0].number))"; continue }
  if (-not $merged) {
    $why = if ($prs) { "PR #$($prs[0].number) is $($prs[0].state), not merged" } else { 'no PR found' }
    Say "  keep: $why"; $summary.kept += "$br ($why)"; continue
  }
  $prOids = @($merged | ForEach-Object { $_.headRefOid; $_.commits.oid })
  $mergedNums = ($merged | ForEach-Object { "#$($_.number)" }) -join ', '

  # Anything on the local branch beyond the merged PR is unshipped work: keep the branch.
  $hasLocal = Test-Git rev-parse --verify --quiet "refs/heads/$br"
  if ($hasLocal) {
    $notArgs = @("^origin/$default") + ($merged | Where-Object { Test-Git cat-file -e "$($_.headRefOid)^{commit}" } | ForEach-Object { "^$($_.headRefOid)" })
    $extra = @(& git rev-list $br @notArgs)
    if ($extra) {
      $upstream = @(& git cherry "origin/$default" $br | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
      $extra = @($extra | Where-Object { $_ -notin $upstream -and $_ -notin $prOids })
    }
    if ($extra) {
      Say "  keep: $($extra.Count) local commit(s) not in merged PR $mergedNums"; $summary.kept += "$br (unmerged local commits)"; continue
    }
  }

  # Worktrees on this branch (or detached on one of its PR commits).
  $branchBlocked = $false
  foreach ($wt in Get-Worktrees) {
    if ($wt.path -eq $mainCheckout) {
      if ($wt.branch -eq $br) { Say "  keep: main checkout has $br checked out"; $branchBlocked = $true }
      continue
    }
    $onBranch = $wt.branch -eq $br
    $onPrCommit = (-not $wt.branch) -and ($wt.head -in $prOids)
    if (-not ($onBranch -or $onPrCommit)) { continue }
    $dirty = @(& git -C $wt.path status --porcelain 2>$null)
    if ($dirty.Count) {
      Say "  keep worktree $($wt.path): $($dirty.Count) uncommitted change(s)"; $summary.worktreesKept += $wt.path
      if ($onBranch) { $branchBlocked = $true }; continue
    }
    if ($wt.path -eq $here) {
      if ($onBranch) {
        if (-not (Act "detach current worktree onto origin/$default (the app removes it on archive)" { Invoke-Git -C $wt.path switch --detach "origin/$default" })) { $branchBlocked = $true }
      }
      continue
    }
    if ($wt.path -notlike "*\.claude\worktrees\*") {
      Say "  keep worktree $($wt.path): not under .claude\worktrees"; $summary.worktreesKept += $wt.path
      if ($onBranch) { $branchBlocked = $true }; continue
    }
    if (Act "remove worktree $($wt.path)" { Invoke-Git -C $mainCheckout worktree remove $wt.path }) { $summary.worktreesRemoved += $wt.path }
    elseif ($onBranch) { $branchBlocked = $true }
  }

  if ($hasLocal -and -not $branchBlocked) {
    $ok = Act "delete local branch $br (PR $mergedNums merged)" {
      & git -C $mainCheckout branch -d $br *> $null
      if ($LASTEXITCODE) { Invoke-Git -C $mainCheckout branch -D $br }   # squash/rebase merge: PR state already confirmed MERGED
    }
    if ($ok) { $summary.deleted += $br } else { $summary.kept += "$br (delete failed)" }
  } elseif ($branchBlocked) { $summary.kept += "$br (checked out in a worktree that was kept)" }
  else { Say "  no local branch" }

  $remote = & git ls-remote --heads origin $br
  if ($remote) { Act "delete remote branch origin/$br" { Invoke-Git push origin --delete $br } | Out-Null }
}

# Fast-forward the main checkout's default branch.
$mainBranch = & git -C $mainCheckout branch --show-current
if ($mainBranch -eq $default) {
  $behind = [int](Invoke-Git -C $mainCheckout rev-list --count "$default..origin/$default")
  if ($behind) {
    $mainDirty = @(& git -C $mainCheckout status --porcelain --untracked-files=no)
    if ($mainDirty) { Say "Main checkout has $($mainDirty.Count) modified tracked file(s); trying a fast-forward anyway:"; $mainDirty | ForEach-Object { Say "    $_" } }
    Act "fast-forward $default in $mainCheckout by $behind commit(s)" { Invoke-Git -C $mainCheckout merge --ff-only --quiet "origin/$default" } | Out-Null
  } else { Say "$default in main checkout is up to date" }
} elseif (Test-Git merge-base --is-ancestor $default "origin/$default") {
  Act "fast-forward $default ref (main checkout is on '$mainBranch')" { Invoke-Git -C $mainCheckout branch -f $default "origin/$default" } | Out-Null
}
Act "git worktree prune" { Invoke-Git -C $mainCheckout worktree prune } | Out-Null

Write-Host ''
Write-Host ($summary | ConvertTo-Json -Depth 3)
