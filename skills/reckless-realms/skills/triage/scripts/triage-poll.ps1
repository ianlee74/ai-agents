<#
.SYNOPSIS
  Token-free triage supervisor: polls both Reckless Realms repos for needs-triage tickets with gh
  and starts a background Claude Code worker (claude --bg) only when a ticket is waiting.

.DESCRIPTION
  One run is one supervisor cycle (SKILL.md, S2). Schedule it every few minutes with Windows Task
  Scheduler. A run that finds nothing to do spends no Claude tokens.

  Each run:
    1. Lists open needs-triage tickets in both repos and reads each ticket's claim comments.
    2. Clears stale claims: a `triaging` label with no live claim (and the dead worker's
       assignment, per SKILL.md S2 step 3).
    3. Reaps workers it started whose tickets are done (claude rm, which also removes the worktree).
    4. Starts workers for waiting tickets, oldest first, up to -Cap running at once.

  Only `<repo>#<N>` reaches the worker's command line. Ticket titles are untrusted player text and
  are only written to the log.

  State, the lock file and the log live in <GameCheckout>\ai-work\triage-poller\.

.EXAMPLE
  pwsh -NoProfile -File triage-poll.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [string]$GameCheckout = 'C:\Code\Reckless-Software\reckless-realms',
  [int]$Cap = 3,
  [int]$GraceMinutes = 20,      # time a new worker gets to post its claim comment
  [int]$MaxAttempts = 3,        # launches per ticket before the poller gives up on it
  [int]$BackoffMinutes = 30,    # wait between launches for the same ticket
  [string]$PermissionMode = 'auto',
  [string]$Claude = 'claude',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$Repos = [ordered]@{
  game    = 'Reckless-Software/reckless-realms'
  content = 'Reckless-Software/reckless-realms-content'
}
$ClaimMarker = '<!-- rr-triage-claim:'
$ClaimLifetime = [TimeSpan]::FromHours(2)

$workDir = Join-Path $GameCheckout 'ai-work\triage-poller'
New-Item -ItemType Directory -Force $workDir | Out-Null
$statePath = Join-Path $workDir 'state.json'
$logPath = Join-Path $workDir 'poll.log'
$now = [DateTimeOffset]::UtcNow

function Write-Log([string]$msg) {
  $line = '{0:u} {1}{2}' -f $now, ($(if ($DryRun) { '[dry-run] ' } else { '' })), $msg
  Write-Host $line
  Add-Content -Path $logPath -Value $line
}

function Invoke-Gh([string[]]$ghArgs) {
  $out = & gh @ghArgs 2>&1
  if ($LASTEXITCODE -ne 0) { throw "gh $($ghArgs -join ' ') failed: $out" }
  return ($out -join "`n")
}

function Get-Json([string[]]$ghArgs) { Invoke-Gh $ghArgs | ConvertFrom-Json -NoEnumerate }

function Save-State {
  if (-not $DryRun) { $state | ConvertTo-Json -Depth 5 | Set-Content $statePath }
}

function Test-LiveClaim($comment) {
  $body = [string]$comment.body
  if (-not $body.Contains($ClaimMarker)) { return $false }
  if ($body.TrimEnd().EndsWith('Released.')) { return $false }
  return ($now - [DateTimeOffset]$comment.created_at) -lt $ClaimLifetime
}

# Single instance: hold an exclusive handle on the lock file for the whole run.
$lockPath = Join-Path $workDir 'poll.lock'
try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
catch { Write-Host 'Another triage-poll run holds the lock; exiting.'; exit 0 }

try {
  $state = @{}
  if (Test-Path $statePath) {
    $loaded = Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable
    if ($loaded) { $state = $loaded }
  }

  $login = (Invoke-Gh @('api', 'user', '-q', '.login')).Trim()

  # 1. Read waiting tickets and their claims.
  $tickets = @()
  foreach ($short in $Repos.Keys) {
    $repo = $Repos[$short]
    $list = Get-Json @('issue', 'list', '-R', $repo, '--state', 'open', '--label', 'needs-triage',
      '--limit', '50', '--json', 'number,title,labels,assignees,createdAt')
    foreach ($t in $list) {
      $comments = @(Get-Json @('api', "repos/$repo/issues/$($t.number)/comments", '--paginate', '--slurp') |
        ForEach-Object { $_ } | ForEach-Object { $_ })
      $claims = @($comments | Where-Object { ([string]$_.body).Contains($ClaimMarker) })
      $tickets += [pscustomobject]@{
        Key       = "$short#$($t.number)"
        Short     = $short
        Repo      = $repo
        Number    = [int]$t.number
        Title     = [string]$t.title
        CreatedAt = [DateTimeOffset]$t.createdAt
        Labels    = @($t.labels | ForEach-Object { $_.name })
        Assignees = @($t.assignees | ForEach-Object { $_.login })
        Claims    = $claims
        LiveClaim = [bool](@($claims | Where-Object { Test-LiveClaim $_ }).Count)
      }
    }
  }
  $byKey = @{}
  foreach ($t in $tickets) { $byKey[$t.Key] = $t }

  # 2. Clear stale claims (SKILL.md S2 step 3).
  foreach ($t in $tickets) {
    if (-not ($t.Labels -contains 'triaging') -or $t.LiveClaim) { continue }
    $editArgs = @('issue', 'edit', "$($t.Number)", '-R', $t.Repo, '--remove-label', 'triaging')
    if ($t.Assignees -contains $login -and $t.Claims.Count) {
      $lastClaim = @($t.Claims | ForEach-Object { [DateTimeOffset]$_.created_at } | Sort-Object)[-1]
      $events = @(Get-Json @('api', "repos/$($t.Repo)/issues/$($t.Number)/events", '--paginate', '--slurp') |
        ForEach-Object { $_ } | ForEach-Object { $_ })
      $assigned = @($events | Where-Object { $_.event -eq 'assigned' -and $_.assignee.login -eq $login } |
        ForEach-Object { [DateTimeOffset]$_.created_at } | Sort-Object)
      if ($assigned.Count) {
        $gap = $assigned[-1] - $lastClaim
        if ($gap -ge [TimeSpan]::Zero -and $gap -le [TimeSpan]::FromMinutes(10)) {
          $editArgs += @('--remove-assignee', '@me')
          $t.Assignees = @($t.Assignees | Where-Object { $_ -ne $login })
        }
      }
    }
    Write-Log "$($t.Key): cleared stale triaging claim"
    if (-not $DryRun) {
      Invoke-Gh $editArgs | Out-Null
      Invoke-Gh @('issue', 'comment', "$($t.Number)", '-R', $t.Repo, '--body',
        'Released a stale triage claim (the `triaging` label had no live claim comment). The ticket is waiting for triage again.') | Out-Null
    }
    $t.Labels = @($t.Labels | Where-Object { $_ -ne 'triaging' })
  }

  # 3. Settle this poller's workers and reap finished ones.
  # Reap only on positive evidence: the worker is listed and not busy. If the listing fails, keep
  # every worker (and its slot) until a later run can read it.
  $agents = $null
  try {
    $agents = @{}
    foreach ($s in @(& $Claude agents --json --all 2>$null | ConvertFrom-Json)) { $agents[[string]$s.name] = [string]$s.status }
  } catch { $agents = $null; Write-Log "could not read claude agents, so no worker is removed this run: $_" }

  $running = 0
  foreach ($key in @($state.Keys)) {
    $rec = $state[$key]
    if (-not $rec['sessionId']) { continue }
    $t = $byKey[$key]
    $launched = [DateTimeOffset]$rec['lastLaunch']
    $inGrace = ($now - $launched) -lt [TimeSpan]::FromMinutes($GraceMinutes)
    $done = (-not $t) -or ((-not $t.LiveClaim) -and (-not $inGrace))
    if (-not $done) { $running++; continue }
    if ($null -eq $agents) { $running++; continue }
    $status = $agents[[string]$rec['sessionName']]
    if ($null -eq $status) {
      Write-Log "${key}: worker $($rec['sessionId']) is done but not listed by claude agents; remove it by hand if it remains (claude rm $($rec['sessionId']))"
      $rec['sessionId'] = $null
      continue
    }
    if ($status -eq 'busy') { continue }   # done on GitHub, still wrapping up; its slot is free
    Write-Log "${key}: worker $($rec['sessionId']) finished; removing its session"
    if (-not $DryRun) {
      & $Claude rm $rec['sessionId'] 2>&1 | ForEach-Object { Write-Log "  claude rm: $_" }
    }
    $rec['sessionId'] = $null
  }
  foreach ($key in @($state.Keys)) {          # ticket left needs-triage: forget it
    if (-not $byKey[$key] -and -not $state[$key]['sessionId']) { $state.Remove($key) }
  }

  # 4. Choose and start workers, oldest first.
  $waiting = @()
  foreach ($t in ($tickets | Sort-Object CreatedAt)) {
    $rec = $state[$t.Key]
    if ($rec -and $rec['sessionId']) { continue }          # our worker is on it
    if ($t.LiveClaim) { continue }                       # claimed, label or not (S2 step 3)
    if ($t.Assignees.Count) {
      if ($t.Assignees -contains $login -and -not ($rec -and $rec['reportedAssigned'])) {
        Write-Log "$($t.Key): assigned to $login with no live claim; triage skips it until it is unassigned"
        if (-not $rec) { $rec = @{ attempts = 0 }; $state[$t.Key] = $rec }
        $rec['reportedAssigned'] = $true
      }
      continue
    }
    if ($rec) {
      $rec['reportedAssigned'] = $false
      if ($rec['attempts'] -ge $MaxAttempts) {
        if (-not $rec['reportedGaveUp']) {
          Write-Log "$($t.Key): $($rec['attempts']) workers ended without triaging it; giving up (delete its entry in $statePath to retry)"
          $rec['reportedGaveUp'] = $true
        }
        continue
      }
      if ($rec['lastLaunch'] -and ($now - [DateTimeOffset]$rec['lastLaunch']) -lt [TimeSpan]::FromMinutes($BackoffMinutes)) { continue }
    }
    $waiting += $t
  }

  $free = [Math]::Max(0, $Cap - $running)
  $toStart = @($waiting | Select-Object -First $free)
  foreach ($t in $toStart) {
    $suffix = -join ((1..4) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    $worktree = "triage-$($t.Short)-$($t.Number)-$suffix"
    $name = "triage $($t.Key)"
    $prompt = "/reckless-realms:triage $($t.Key) - background worker started by triage-poll.ps1; follow references/harness-cli.md"
    Write-Log "$($t.Key): starting worker ($name) for `"$($t.Title)`""
    $rec = $state[$t.Key]
    if (-not $rec) { $rec = @{ attempts = 0 }; $state[$t.Key] = $rec }
    $id = "dry-run-$suffix"
    if (-not $DryRun) {
      Push-Location $GameCheckout
      try { $out = & $Claude --bg -w $worktree -n $name --permission-mode $PermissionMode $prompt 2>&1 }
      finally { Pop-Location }
      if ($LASTEXITCODE -ne 0) { Write-Log "  start failed: $out"; continue }
      $id = (@($out | ForEach-Object { "$_".Trim() } | Where-Object { $_ }))[-1]
      Write-Log "  started $id"
    }
    $rec['attempts'] = [int]$rec['attempts'] + 1
    $rec['lastLaunch'] = $now.ToString('o')
    $rec['sessionId'] = $id
    $rec['sessionName'] = $name
    $rec['reportedGaveUp'] = $false
    Save-State   # a later error must not lose this launch, or the next run would start it again
  }

  $summary = "seen $($tickets.Count), running $running, waiting $($waiting.Count), started $($toStart.Count)"
  if ($toStart.Count -or $DryRun) { Write-Log $summary } else { Write-Verbose $summary }

  Save-State
}
catch { Write-Log "error: $_"; exit 1 }
finally { $lock.Dispose() }
