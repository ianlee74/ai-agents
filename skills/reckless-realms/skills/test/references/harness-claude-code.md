# Claude Code notes for `test`

- **Launch:** run the step 4 command with the Bash tool and `run_in_background: true`. Keep the
  returned task id: stopping the game is `TaskStop` on it.
- **Wait:** use `Monitor` with an until-loop over `node tools/dev-bridge.mjs status` and
  `play.log`, rather than foreground `sleep` (which is blocked). If the background task exits, you
  are notified; read `play.log` then.
- **Working directory:** in the desktop app the session usually runs in a worktree under
  `<game>/.claude/worktrees/<name>`. That worktree is the game checkout to launch; its `ai-work/`
  (saves, staged client, bridge session files) is separate from the main checkout's.
- **Session name (step 7):** in the desktop app, load `mcp__ccd_session_mgmt__get_session` with
  ToolSearch and call it with `session_id: "self"`. Its `title` is the label. In a plain CLI
  session there is no title, so use the step 3 short name.
- **Git Bash paths:** set `MSYS_NO_PATHCONV=1` for bridge commands whose node path starts with `/`
  (see the game's `docs/Dev-Bridge.md`).
