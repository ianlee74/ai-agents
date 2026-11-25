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
