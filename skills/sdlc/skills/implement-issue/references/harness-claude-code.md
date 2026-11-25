# Claude Code

- **Rename the session (step 3):** in the desktop app, call
  `mcp__ccd_session_mgmt__set_session_title` with `session_id: "self"` and the title. It is usually
  deferred: load it first with `ToolSearch select:mcp__ccd_session_mgmt__set_session_title`. The
  app may ask the user to approve if they named the session themselves. A subagent can't rename its
  session. In a plain CLI session, where the tool isn't listed, offer `/rename #<N>: <title>`.
- **Other sessions (step 1):** in the desktop app, `mcp__ccd_session_mgmt__list_sessions` (deferred
  too) shows sessions by title. Link a match so the user can open it.
- **Gates:** put the proposal or report in the message itself, then ask. If the harness provides a
  turn wrap-up (`mcp__ccd_turn__wrap_up`), put the question there (blocked: true; e.g. "Build it" /
  "Change it" at Gate 1, "I'll test it" / "PR it" at Gate 2). Don't offer its commit or PR app
  actions at Gate 2; the reply should come back here. Otherwise ask in the last line. Avoid a modal
  question tool here: it can hide the proposal the user needs to read.
- **Plan mode:** if the session is already in it, Gate 1 is the plan approval; don't ask twice.
  Claiming and renaming change things outside the plan, so if plan mode blocks them, do them right
  after approval.
- **Skills at Gate 2:** `sdlc:ship` for the PR; a project's own launch skill (such as
  `reckless-realms:test`) for testing.
