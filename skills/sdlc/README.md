# sdlc

Skills for the software development lifecycle. The skills follow the open
[Agent Skills](https://agentskills.io/specification) format, and this folder is also a Claude Code
plugin.

## Skills

### ship

The closing routine for a coding session: commit → PR → merge → clean up → archive. Ask for any
subset in a few words ("PR it", "PR & merge", "merged. clean up then archive") and it does exactly
those steps, in order.

- **Never pushes onto a finished PR.** Before committing it checks the branch's PRs; if they're all
  merged or closed, it moves the work (commits and uncommitted changes) to a fresh branch cut from
  the default branch and opens a new PR.
- **Syncs with the base branch** before opening and before merging, so conflicts surface locally,
  and resolves them.
- **Merges with merge commits** once CI passes, or turns on auto-merge / auto-fix instead.
- **Cleans up after the merge**: removes the session's worktrees, deletes the local and remote
  branch, fast-forwards the main checkout, and keeps (and reports) anything with unmerged or
  uncommitted work.

Two PowerShell scripts in [`skills/ship/scripts/`](skills/ship/scripts/) do the git work:
`pr-state.ps1` (the branch's PR state, and moving work off a finished PR) and
`post-merge-cleanup.ps1` (branch and worktree hygiene; `-DryRun` shows the plan).

Requires `git`, the [GitHub CLI](https://cli.github.com/) (`gh`, signed in), and PowerShell 7
(`pwsh`). The archive, PR-binding and host-sync steps use the Claude desktop app's tools; in other
harnesses it falls back to plain `git` / `gh`.

## Install

### Claude Code

From GitHub:

```bash
claude plugin marketplace add ianlee74/ai-agents
claude plugin install sdlc@ianlee74-ai-agents
```

From a local clone, use the clone's path in place of `ianlee74/ai-agents`. Restart Claude Code, then
say "PR it" or run `/sdlc:ship`.

### Other harnesses

Copy or symlink `skills/ship/` into the directory your harness loads Agent Skills from (see its
documentation), keeping its `scripts/` folder alongside `SKILL.md`.
