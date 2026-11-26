<#
.SYNOPSIS
  Post a message to a Discord channel through a webhook whose URL is kept in an
  environment variable.

.DESCRIPTION
  Reads the message from a UTF-8 file and POSTs it to the webhook named by the
  environment variable -WebhookEnv (default RR_DISCORD_WEBHOOK) as
  {"content": ..., "allowed_mentions": {"parse": []}}, so @everyone, @here and
  user/role pings in the text never notify anyone.

  The webhook URL is a secret: anyone who has it can post to the channel. This
  script never prints, logs or echoes it, not even in error messages.

  Exit codes: 0 posted (or dry run), 1 bad input (missing file, empty or over
  2000 characters), 2 environment variable missing or not a Discord webhook URL,
  3 Discord rejected the post or could not be reached.

  To set the variable (once, in your own PowerShell, then restart the app):
    [Environment]::SetEnvironmentVariable('RR_DISCORD_WEBHOOK', '<webhook url>', 'User')

.EXAMPLE
  pwsh -NoProfile -File post-discord.ps1 -File post.md -DryRun
  pwsh -NoProfile -File post-discord.ps1 -File post.md
  pwsh -NoProfile -File post-discord.ps1 -File post.md -WebhookEnv LLACER_DISCORD_WEBHOOK
#>
param(
  [Parameter(Mandatory)][string]$File,
  [string]$WebhookEnv = 'RR_DISCORD_WEBHOOK',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Print emoji correctly when the console is not already UTF-8.
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}

# 1. Message
if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
  Write-Host "Message file not found: $File"
  exit 1
}
$content = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $File).Path, [Text.UTF8Encoding]::new($false))
$content = $content.TrimStart([char]0xFEFF).Trim()
if (-not $content) {
  Write-Host "Message file is empty: $File"
  exit 1
}
# Discord's limit is 2000 characters. .Length counts UTF-16 units, so an emoji counts
# as 2; that only ever overestimates, which keeps us safely under the limit.
if ($content.Length -gt 2000) {
  Write-Host "Message is $($content.Length) characters; Discord allows at most 2000. Shorten it and try again."
  exit 1
}

# 2. Webhook (never print it)
# Fall back to the saved User value, so a variable set after the app started still works.
$url = [Environment]::GetEnvironmentVariable($WebhookEnv)
if (-not $url) { $url = [Environment]::GetEnvironmentVariable($WebhookEnv, 'User') }
$howToSet = @"
Set it once in your own PowerShell (not through Claude), then restart the app so it sees the variable:
  [Environment]::SetEnvironmentVariable('$WebhookEnv', '<webhook url>', 'User')
(Discord: channel settings > Integrations > Webhooks > New Webhook > Copy Webhook URL.)
"@
if ($DryRun) {
  $state = if ($url) { 'set' } else { 'NOT SET' }
  Write-Host "[dry-run] Would post $($content.Length) characters to the webhook in `$env:$WebhookEnv ($state):"
  Write-Host ''
  Write-Host $content
  if (-not $url) { Write-Host ''; Write-Host "`$env:$WebhookEnv is not set. $howToSet" }
  exit 0
}
if (-not $url) {
  Write-Host "Environment variable $WebhookEnv is not set, so the post was not sent."
  Write-Host $howToSet
  exit 2
}
if ($url -notmatch '^https://(ptb\.|canary\.)?discord(app)?\.com/api/(v\d+/)?webhooks/\d+/[\w-]+(\?.*)?$') {
  Write-Host "`$env:$WebhookEnv does not look like a Discord webhook URL (https://discord.com/api/webhooks/<id>/<token>), so the post was not sent."
  Write-Host $howToSet
  exit 2
}

# 3. Post. Send the JSON as UTF-8 bytes so emoji survive; wait=true makes Discord
# return the created message, which confirms it landed.
$body = @{ content = $content; allowed_mentions = @{ parse = @() } } | ConvertTo-Json -Depth 4 -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($body)
$sep = if ($url.Contains('?')) { '&' } else { '?' }
try {
  $msg = Invoke-RestMethod -Method Post -Uri "$url${sep}wait=true" -Body $bytes `
    -ContentType 'application/json; charset=utf-8' -TimeoutSec 30
} catch {
  # Report the status and Discord's own error text only; the exception message can
  # include the request URL.
  $status = $_.Exception.Response.StatusCode
  $detail = $_.ErrorDetails.Message
  if ($status) {
    Write-Host "Discord rejected the post: HTTP $([int]$status) $status."
    if ($detail -and $detail -notmatch 'webhooks/') { Write-Host "Discord says: $detail" }
    if ([int]$status -in 401, 404) { Write-Host "The webhook in `$env:$WebhookEnv may have been deleted or regenerated. $howToSet" }
  } else {
    Write-Host "Could not reach Discord: $($_.Exception.GetType().Name). Check the network and try again."
  }
  exit 3
}
Write-Host "Posted to Discord via `$env:$WebhookEnv (message id $($msg.id), $($content.Length) characters)."
exit 0
