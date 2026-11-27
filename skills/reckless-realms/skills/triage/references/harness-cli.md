# Claude Code CLI notes for `triage` (poll script and background workers)

[scripts/triage-poll.ps1](../scripts/triage-poll.ps1) is a supervisor without a model. Windows
Task Scheduler runs it every few minutes. It runs one S2 cycle with `gh`: it reads both repos,
clears stale claims, removes finished workers, and starts workers with
`claude --bg -w <worktree> -n "triage <repo>#<N>" --permission-mode auto`, oldest tickets first, up to 3 running at once. Claude tokens are spent only by workers.

## Setup (once per machine)

1. Install the plugin (`claude plugin install reckless-realms@ianlee74-ai-agents`) and sign the
   CLI in to the Claude subscription: `claude auth login`. The desktop app's sign-in doesn't
   carry over. If `ANTHROPIC_API_KEY` is set, workers bill the API instead.
2. `gh auth status` must show the account that triages. Workers and the script use that login.
3. The game checkout (default `C:\Code\Reckless-Software\reckless-realms`, `-GameCheckout` to
   change it) must have its setup done (`npm run setup`) so workers can run a live repro.
   `claude -w` creates each worker's worktree from it. The script keeps `state.json`,
   `poll.lock` and `poll.log` in its `ai-work\triage-poller\`.
4. Check it with a dry run, which reads GitHub and writes nothing:

   ```powershell
   pwsh -NoProfile -File "$HOME\.claude\plugins\marketplaces\ianlee74-ai-agents\skills\reckless-realms\skills\triage\scripts\triage-poll.ps1" -DryRun
   ```

5. Register the task as your own user, so it uses your `gh` and `claude` sign-ins. The path is
   the marketplace clone, so it follows plugin updates:

   ```powershell
   $script = "$HOME\.claude\plugins\marketplaces\ianlee74-ai-agents\skills\reckless-realms\skills\triage\scripts\triage-poll.ps1"
   $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$script`""
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
   $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
   Register-ScheduledTask -TaskName 'Reckless Realms triage poll' -Action $action -Trigger $trigger -Settings $settings
   ```

   Stop it with `Disable-ScheduledTask 'Reckless Realms triage poll'`. Don't also run a
   supervisor session: both would start workers.

## Script behavior

- **Claims:** a ticket with any live claim is skipped, whether or not it has `triaging`. A
  `triaging` label with no live claim is cleared as stale (S2 step 3), together with the dead
  worker's assignment when the events show it made that assignment.
- **Launch-to-claim gap:** a worker it started counts as running for `-GraceMinutes` (20) even
  before its claim appears, and after that for as long as the ticket has a live claim. When the ticket leaves
  `needs-triage`, or the grace period ends with no live claim, the worker is finished. If
  `claude agents --json --all` lists it and not as busy, `claude rm` deletes the session and its
  worktree. A finished worker that isn't listed is logged for removal by hand. If the listing
  fails, nothing is removed that run.
- **Retries:** a ticket whose worker ended without triaging it is retried after
  `-BackoffMinutes` (30), at most `-MaxAttempts` (3) times. After that the log says it gave up.
  Delete the ticket's entry in `state.json` to retry it.
- **Assigned tickets** are skipped. One assigned to the login with no live claim is logged once
  (S2 step 5).
- **Untrusted text:** only `<repo>#<N>` reaches the worker's command line. Titles go only to the
  log.
- **Watching:** `poll.log` gets a line for each start, removal, stale claim and give-up. A cycle
  that changes nothing writes nothing. `claude agents` lists running workers,
  `claude attach "triage game#123"` opens one, and `claude logs <id>` shows its output.

## Worker (started with `--bg`)

The poll script's prompt says the worker is a background worker. In that case:

- **No desktop session tools.** Skip W1's rename (the script already named the session). The
  W2 claim token is 8 random hex characters.
- **Don't archive (W7).** Report and end your turn; the poll script removes the session and its
  worktree once the ticket is done.
- **Never ask questions or wait for input.** Nobody is attached. Take the "Needs a human" outcome
  instead. If a tool call needs approval and is refused, treat it as a failure: release the claim
  (W6) and end.
- **Live repro (W4):** use the `reckless-realms:test` skill as in the desktop app. It hasn't yet
  been run from a background worker, so if it can't start a game here, skip the live run and say
  so in the spec. Always pass `--pid` to bridge commands, and stop the test game before ending.
