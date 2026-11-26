# Claude Code notes for `triage`

These need the Claude desktop app (Code tab). Most tools are deferred: load them with
`ToolSearch select:<name>` before the first call.

## Supervisor

- **Timer (S2 step 5):** at setup, create an in-session recurring check-in with `CronCreate`
  (every 15 minutes, or the user's cadence) whose prompt is `/reckless-realms:triage`, or, without
  `CronCreate`, run the supervisor under `/loop 15m /reckless-realms:triage`. A worker finishing
  also wakes the supervisor through a side-sessions event; run a cycle then too. To stop, delete
  the cron job (`CronDelete`) or end the loop.
- **Starting workers (S2 step 3):** `mcp__ccd_session__start_session` with
  `initiation: "user_asked"` (the user asked for the supervisor to start them), `context: "fresh"`,
  `use_worktree: true`, `title: "#<N>: <title>"`, `prompt` = the brief, and `background` naming the
  ticket URL, the repo and that this is an unattended triage worker. Keep each returned session id
  and name against its ticket; that is the "worker still running" list. `list_sessions`
  `{"linked": true}` shows their state.
- **If a start is refused** on a timer turn, fall back to a one-shot scheduled task:
  `mcp__scheduled-tasks__create_scheduled_task` with `fireAt` a minute from now, `taskId`
  `triage-<repo>-<N>`, and the brief as `prompt` (self-contained: repo, number, URL, "use the
  reckless-realms:triage skill's worker mode"). Note it in the cycle report so the user knows why.
- **Permission mode:** workers inherit the supervisor's mode. Unattended work goes much smoother in
  auto mode; if the supervisor isn't in it, say once at setup that workers may stop on approval
  prompts.

## Worker

- **Rename (W1):** `mcp__ccd_session_mgmt__set_session_title` with `session_id: "self"`.
- **Claim token (W2):** `mcp__ccd_session_mgmt__get_session` with `session_id: "self"` gives the
  session id.
- **Live repro (W4):** invoke the `reckless-realms:test` skill with the Skill tool. Always pass
  `--pid` to bridge commands.
- **Archive (W7):** `mcp__ccd_session_mgmt__archive_session` with `session_id: "self"` and a reason
  such as `"Triage of #<N> done"`. It ends the conversation, so report first. It cleans up the
  worktree. If the archive is refused or needs approval nobody gives, leave the report as the last
  message; the supervisor's next cycle notices the ticket left `needs-triage`.
- **No wrap-up questions:** a worker runs unattended. Don't stop to ask the user; take the "Needs a
  human" outcome instead.
