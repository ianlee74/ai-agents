# reckless-realms

Skills for developing [Reckless Realms](https://github.com/Reckless-Software/reckless-realms). The
skills follow the open [Agent Skills](https://agentskills.io/specification) format, and this folder
is also a Claude Code plugin.

## Skills

### test

Say "start a test game" or "start a local test". From the session's own reckless-realms checkout
(main or a worktree) it:

- launches `npm run play` in the background on an isolated `test-<name>` save and a free port, with
  `RR_DEV_BRIDGE=1` so only this client runs the [dev bridge](https://github.com/Reckless-Software/reckless-realms/blob/main/docs/Dev-Bridge.md);
- waits for the join code and the new bridge session, then `ping`s it;
- creates a new admin character populated for the test with `tools/create-character.mjs`;
- labels the client window `[<session name>] Reckless Realms — <character>` through a small bridge
  install, so you can tell test games apart;
- reports the save, port, join code, bridge pid and log path, and leaves the game running.

It never touches the default `adventure` save, the installed release's bridge setting, or other
sessions' games. Requires the game repo's own setup (`npm run setup`).

### triage

Say "start triage" or run `/reckless-realms:triage` in a Claude desktop session. As a supervisor
it polls `reckless-realms` and `reckless-realms-content` (every 5 minutes by default, and again as soon as a worker finishes) for open
tickets labelled `needs-triage`, and starts one worker session per ticket (up to 3 at a time),
oldest tickets first.
Each worker:

- claims the ticket with a `triaging` label and a claim comment, so other supervisors skip it;
- reads the report, checks whether it's already fixed or a duplicate, traces the likely cause, and
  reproduces it (live in a test game for visual or in-world bugs);
- posts a rough spec as a comment (never edits the body), then swaps `needs-triage` for
  `AI READY`, or `question` when a human is needed. An already-fixed ticket is closed as completed
  and a duplicate is closed as duplicate (linked to the original), both with all labels removed;
- releases the claim and archives its own session.

Workers only touch the ticket: no code edits, branches or pushes. Run `/reckless-realms:triage
<repo>#<N>` (or `triage 133`) to triage one ticket directly.

### supervise-implementation

Say "supervise implementation" or run `/reckless-realms:supervise-implementation` in a Claude
desktop session. The session becomes a supervisor that watches `reckless-realms` and
`reckless-realms-content` for open, unassigned tickets labelled `AI READY` and starts one worker
session per ticket (oldest first, up to 3 in flight), titled `#N: title`. Each worker uses
`sdlc:implement-issue` to claim, build, verify and open PRs, and never merges or posts. The
supervisor:

- answers workers' proposal, scope and next-slice questions itself, asking the user only about
  major unsettled questions;
- ships big tickets as small, self-contained slices (on by default), one PR each;
- merges each PR as soon as it's ready, with `[skip ci]` on all but the last player-facing merge of
  a batch, so one release covers the batch;
- posts one player-facing Discord note per release through the `RR_DISCORD_WEBHOOK` user
  environment variable;
- archives a worker and removes its worktrees and merged branches once its ticket is closed, its
  PRs are merged and its note is posted;
- answers "status" with a table of active workers.

It uses no timers: workers wake the supervisor when they finish.

## Install

### Claude Code

```bash
claude plugin marketplace add ianlee74/ai-agents
claude plugin install reckless-realms@ianlee74-ai-agents
```

Restart Claude Code, then say "start a test game" or run `/reckless-realms:test`.

### Other harnesses

Copy or symlink `skills/test/` into the directory your harness loads Agent Skills from, keeping its
`references/` folder alongside `SKILL.md`.
