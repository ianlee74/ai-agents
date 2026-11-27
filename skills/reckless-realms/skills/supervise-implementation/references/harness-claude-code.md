# Claude Code notes for `supervise-implementation`

These need the Claude desktop app (Code tab). Most tools are deferred: load them with
`ToolSearch select:<name>` before the first call.

## No timers

Don't create a cron, `/loop` or scheduled task. Timer turns can't start sessions: their starts are
refused and fall back to a click-to-start card, which the user doesn't want. Starts work on a turn
the user began and on a `<side-sessions-event>` turn that follows one. The chain that keeps work
moving:

1. Start each worker with `wake_when_done: true`.
2. When no worker is still working, the app continues the supervisor with a
   `<side-sessions-event>` turn. Handle every note in it (section 3) and start the next workers
   there.
3. Any user turn also continues the chain: check GitHub and refill free slots.
4. If a start is refused anyway, say in one line that the next user message will start it, and
   start it on that message.

## Starting a worker

`mcp__ccd_session__start_session` with `initiation: "user_asked"`, `context: "fresh"`,
`use_worktree: true`, `wake_when_done: true`, `title: "#<N>: <title>"` (or
`"content#<N>: <title>"`), a short `name` such as `ticket-<N>`, `prompt` = the brief, and
`background` naming the repo, the ticket URL and that the supervisor merges and posts to Discord.
Keep each returned id against its ticket.

Send the start calls for every free slot in parallel in one message: the `start_session` result
tells you to end the turn, so a start sent afterwards never happens.

## Talking to workers

- `SendMessage` with `to` set to the worker's `local_…` session id. Make the first line say what
  it is about ("Go ahead: approved, build it").
- Quote the user's own words in every approval. Paraphrased approvals ("pre-approved by the
  supervisor") get blocked by the worker's auto-mode check.
- A worker's note is cut to 400 characters; read more with `mcp__ccd_session_mgmt__get_session`
  or `list_events` when the cut-off part matters.

## Archiving

`mcp__ccd_session_mgmt__archive_session` with the worker's id and a reason such as
`"#<N> closed, PRs merged, Discord posted"`. If a hook adds a `session` field and asks for a
retry, retry once with exactly that input. Archiving removes the session's own worktree; other
worktrees and branches it made (for example in the content repo) are the supervisor's to clean up.

## Status links

`mcp__ccd_session_mgmt__list_sessions` `{"linked": true}` gives each worker's `link`
(`claude://claude.ai/epitaxy/<id>`), branch, PR and state. Use `link` in the status table; a
`#local_…` link renders as the long session title.
