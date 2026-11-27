# Claude Code notes for `triage`

These need the Claude desktop app (Code tab). Most tools are deferred: load them with
`ToolSearch select:<name>` before the first call.

## Supervisor

- **Timer (S2 step 6):** at setup, create an in-session recurring check-in with `CronCreate`
  (every 5 minutes, or the user's cadence) whose prompt is `/reckless-realms:triage`. Use an
  off-minute cron such as `2-59/5 * * * *` rather than `*/5`. Without `CronCreate`, run the
  supervisor under `/loop 5m /reckless-realms:triage`. To stop, delete the cron job
  (`CronDelete`) or end the loop.
- **Cycle triggers (S2):** a worker that ends its own turn wakes the supervisor with a
  `<side-sessions-event>` message; run a full cycle on it and refill the slot then. A worker the
  **user archived** sends no side-sessions note, so the supervisor only learns of it on its next
  turn: the 5-minute timer is the backstop for that case. Any user message is a cycle trigger too.
- **Finished or not (S2 step 2):** go by GitHub, not by `list_sessions` state. An archived
  session may have finished its ticket or abandoned it; a running one may already have released
  its claim and be about to archive.
- **Starting workers (S2 step 4):** `mcp__ccd_session__start_session` with
  `initiation: "user_asked"` (the user asked for the supervisor to start them), `context: "fresh"`,
  `use_worktree: true`, `title: "#<N>: <title>"`, `prompt` = the brief, and `background` naming the
  ticket URL, the repo and that this is an unattended triage worker. Keep each returned session id
  and name against its ticket; that is the "worker still running" list. `list_sessions`
  `{"linked": true}` shows their state.
- **Start every free slot in one message.** The `start_session` result tells you to end your turn,
  so a second start sent afterwards never happens. Send the start calls for all free slots in
  parallel in a single message, together with any timer change (see below), then end the turn.
- **Never ask the user to start workers.** The supervisor starts them on its own. No permission
  questions, no "Go" buttons, no `wrap_up` question about a refused start: report it, nothing more.
- **If a start is refused:** under Remote Control, timer turns can't start sessions (the refusal
  says "The user is working over Remote Control, and this turn can't start that session"). Starts
  do work on a turn with a real user message, such as a typed `/reckless-realms:triage`.
  - List the refused tickets in the one-line cycle report and retry them on the next turn that has
    a user message.
  - The one-shot scheduled-task fallback (`mcp__scheduled-tasks__create_scheduled_task`, `fireAt`
    a minute from now, `taskId` `triage-<repo>-<N>`, a self-contained brief naming repo, number,
    URL and "use the reckless-realms:triage skill's worker mode") is usually blocked by the
    auto-mode classifier. Try it at most once per supervisor session; if it's blocked, don't try
    it again.
  - While starts are blocked, slow the timer to about 30 minutes: create a cron such as
    `7,37 * * * *` and delete the 5-minute one. After the first successful start, recreate
    `2-59/5 * * * *` and delete the slow cron.
  - Send at most one push notification (`PushNotification`) about the blocked backlog per
    supervisor session, not one per cycle.
  - Never turn Remote Control off (`set_remote_control`) to get around it, and never triage a
    ticket in the supervisor or in a subagent instead.
- **Long-running supervisors:** after many cycles the session hits "conversation too long for auto
  mode's classifier" and needs `/compact`. To delay that:
  - Keep cycle turns lean: one `gh issue list` per repo, no re-reading of this skill or other
    files.
  - On a cycle where nothing changed, give the shortest possible recap and closing line (S2 step
    5: say nothing more).
  - After many cycles (a few hours), compact or restart the supervisor.
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
