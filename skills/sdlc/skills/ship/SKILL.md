---
name: ship
description: "Ship the current change: commit, push, open a PR, and optionally merge it, clean up the branch and worktree, and archive the session. Use whenever the user says 'PR it', 'commit and PR', 'open a PR then merge', 'PR and merge', 'merge it', 'clean up and archive', 'ship it', 'merged. clean up', or any combination of commit/PR/merge/cleanup/archive, even without the word 'ship'. Also use when the user says a PR was already merged or completed and the new change needs its own PR, or asks to resolve merge conflicts on a PR before merging."
---

# Ship

The closing routine for a coding session: commit → PR → merge → clean up → archive. The user
usually asks for a subset in a few words ("PR & merge", "merged. clean up then archive"). Do
exactly the steps they asked for, in order, without asking again for permission they've already
given. The request *is* the authorization for the steps it names.

Two scripts in `scripts/`, next to this file, do the error-prone git work the same way every
time. Run them with `pwsh -NoProfile -File "<this skill's folder>/scripts/<name>.ps1"` from the
repo or worktree (they work from either Bash or PowerShell). Use the skill's actual install path
(the base directory the harness reports when it loads this skill), not a guessed one: as a plugin
it lives in the plugin cache, not `~/.claude/skills/`.

- `pr-state.ps1`: prints JSON with the branch's PRs and a `verdict`. `-NewBranch <name>` moves
  the work off a finished PR. Read-only without `-NewBranch`.
- `post-merge-cleanup.ps1`: branch and worktree hygiene after a merge. `-DryRun` shows the plan.

The desktop app's tools are deferred. Load the ones the scope needs in one call, e.g.
`ToolSearch select:mcp__ccd_host__sync_with_base_branch,mcp__ccd_pr__get_status,mcp__ccd_pr__bind_pr,mcp__ccd_session_mgmt__archive_session`
(add `mcp__ccd_pr__set_auto_merge` / `mcp__ccd_pr__set_monitor` when asked). If a tool
isn't listed at all (e.g. a plain CLI session), use the git/gh fallback given in each step.

## 1. Work out the scope

| The user says | Do |
|---|---|
| "commit", "commit this" | commit (push only if a PR is already open) |
| "PR it", "commit and PR", "open a PR" | commit, push, open PR |
| "ship it", "PR and merge", "PR & merge", "open a PR then merge", "merge it" | …and merge |
| "…with auto-merge" / "…and auto-fix" | open PR, then turn on the app switch instead of merging now (see §6) |
| "clean up", "merged. clean up" | cleanup only (§7); the PR is already merged |
| "…and archive", "archive this session when complete" | finish everything else, then archive (§8) |

If the scope is truly unclear (e.g. just "done?"), ask. Otherwise go.

## 2. Check the branch before committing anything

Run `pr-state.ps1`. This is the step that prevents the user's most repeated complaint: new work
pushed onto a PR that was already merged ("PR #34 is already completed. We need a new PR for
this."). A merged PR never picks up new commits, so the work would silently go nowhere.

| verdict | Meaning | Do |
|---|---|---|
| `open-pr` | An OPEN PR exists for this branch | Commit and push to it. Don't open another PR. |
| `no-pr` | Branch has no PR yet | Commit, push, open a PR. |
| `needs-new-branch` | Every PR for this branch is MERGED or CLOSED | Run `pr-state.ps1 -NewBranch claude/<short-topic-slug>`, then carry on as `no-pr`. |
| `on-default-branch` | On `main` or detached | `git switch -c claude/<short-topic-slug>` first. |

`-NewBranch` stashes uncommitted changes (tagged entry, applied back by SHA, because the stash
stack is shared with the user's other worktrees and sessions), branches from fresh
`origin/<default>`, cherry-picks any commits not already in the merged PR, then restores the
changes. On exit code 2 it stopped on a conflict: the JSON `message` says what to finish.
Afterwards the JSON's `branch` is the new branch and `previousBranch` the finished one. Remember
`previousBranch`: §7 cleans it up too. Mention the move in your summary ("PR #34 was already
merged, so this went to a new branch / PR #35").

Do the check again right before pushing if a lot of time has passed in the session. PRs get
merged from the GitHub UI while you work.

## 3. Commit

- Stage only this session's work. Look at `git status`; leave unrelated files alone and tell the
  user about them rather than sweeping them in. Leftover uncommitted files in the main checkout
  are what have blocked the user's pulls before.
- Match the repo's commit style (`git log --oneline -10`): a short imperative summary, often
  `Area: what changed`, and a body explaining why when it isn't obvious. End with the
  attribution lines from the system prompt, if any.
- Run the project's checks/tests first when they're quick and obvious (e.g. `npm test`,
  `dotnet build`). Report failures; don't ship red without saying so.

## 4. Sync with the base branch

Before opening a PR (and again before merging), bring in the latest base so conflicts surface
here, not on GitHub.

Skip it before the PR when the branch was just cut from a freshly fetched `origin/<default>`
(e.g. by `-NewBranch`). Nothing can have landed in between.

- **App-made worktree** (path contains `\.claude\worktrees\`, and
  `mcp__ccd_host__sync_with_base_branch` is available): commit first (it refuses with
  uncommitted changes), then call it with no arguments. It runs git on the host, so it can write the protected files
  (`.claude/skills`, `.mcp.json`…) a sandboxed `git merge` can't.
- **Otherwise:** `git fetch origin` and `git merge origin/<default>`.
- **Conflicts:** resolve them by understanding both sides, keeping both intents where possible.
  Then `git add`, `git commit --no-edit`, rerun checks. If a resolution needs a product decision,
  ask.

The same applies when the user says an existing PR "has merge conflicts": check out its branch
(or use its worktree), sync, resolve, push, then merge if asked. For "fix the conflicts in the
other open PRs", list them with `gh pr list --state open --json number,headRefName,mergeable`
and do each one the same way.

## 5. Push and open the PR

```bash
git push -u origin HEAD
gh pr create --base <default> --title "<summary>" --body-file <file>
```

- Body: what changed and why, how it was tested, then the PR attribution line from the system
  prompt, if any. Write the body to a temp file in the scratchpad so quoting survives on Windows.
- **Issues:** if the work came from a GitHub issue (the user mentioned `#N`, the branch is named
  like `issue-N-…`, or the session started from an issue), add a line `Closes #N` so merging
  closes it.
- **Bind it:** call `mcp__ccd_pr__get_status`; if it doesn't show this PR, call
  `mcp__ccd_pr__bind_pr` with `url` set to the PR URL. Then read CI from `get_status` rather
  than polling `gh pr checks`. Skip this in sessions without the `ccd_pr` tools.

## 6. Merge (only if asked)

1. Confirm it's mergeable: `gh pr view <n> --json state,mergeable,mergeStateStatus`. If
   `CONFLICTING`, go back to §4.
2. CI: llacer and regatta have no checks. JobTracker's `CI` build takes about 15 seconds. Read
   `get_status` (or `gh pr checks <n>` once). If checks pass or there are none, merge. If they're
   still running, finish the rest of the work, then check one more time. If they're still pending,
   tell the user and offer auto-fix or merging when they finish. Don't loop on `gh pr checks` or
   schedule polling. If a check failed, stop and report; don't merge red unless the user says to.
3. `gh pr merge <n> --merge`. The user's repos all use merge commits, so keep it. Leave out
   `--delete-branch`: from a worktree gh tries to check out `main`, which is already checked out
   in the main folder, and the merge looks like it failed. §7 deletes the branch instead.
4. Confirm with `gh pr view <n> --json state` that it reports `MERGED`.

**Auto-merge / auto-fix instead of merging now:**
- Auto-merge: `mcp__ccd_pr__set_auto_merge` with `merge_method: "merge"`. GitHub's "Allow
  auto-merge" setting is off on llacer, JobTracker and regatta right now, so this will likely
  fail. If it does, say so and offer to merge directly once checks pass, or point them at
  repo Settings → General → "Allow auto-merge".
- Auto-fix: `mcp__ccd_pr__set_monitor` with `auto_fix: true` and the PR URL. The app then wakes this
  session on CI failures, conflicts and review comments.

## 7. Clean up after the merge

Run `post-merge-cleanup.ps1` from the session's worktree or repo. It cleans the checked-out
branch by default. Pass `-Branch a,b` to name branches instead, e.g. the merged branch plus the
`previousBranch` left over from a §2 move, so the finished branch isn't left behind. For each
branch it:

1. Refuses unless GitHub shows a MERGED PR and no OPEN one, and the local branch has nothing
   beyond what merged.
2. Removes clean worktrees under `.claude\worktrees\` that are on that branch or detached on one
   of its PR commits. The worktree it runs in is detached onto `origin/<default>` rather than
   removed; the app deletes it when the session is archived. Worktrees with uncommitted changes
   are always kept.
3. Deletes the local branch (`-d`, or `-D` for squash merges once MERGED is confirmed) and the
   remote branch if GitHub didn't auto-delete it (llacer and regatta don't). That is a push to
   GitHub, and the cleanup request covers it.
4. `git fetch --prune`, fast-forwards `main` in the main checkout, `git worktree prune`.

Relay what it kept and why: a dirty main checkout, a worktree with uncommitted changes,
unmerged local commits. Those are what the user needs to act on. Don't force past them.

`-AllMerged` sweeps every local branch. Use it only when the user asks for a broad cleanup
("clean up all the old branches"), and always run it with `-DryRun` first and show the user the
list before running it for real. Those worktrees may belong to other sessions.

## 8. Archive (only if asked)

Archiving ends this conversation, so send the final summary first, then call
`mcp__ccd_session_mgmt__archive_session` with `session_id: "self"` and a reason like
`"PR #35 merged"` as the last action of the turn. If the tool isn't available, say the
session is ready to archive.

If the user asks for this often, mention once that `auto_archive_on_pr_close` (Settings →
Claude Code) archives sessions automatically when their PR merges.

## Summary to the user

Keep it short: commit(s), PR link (and whether it's new or existing, and why if the work moved),
merge result, what cleanup removed and what it kept and why, and anything the user needs to do.
