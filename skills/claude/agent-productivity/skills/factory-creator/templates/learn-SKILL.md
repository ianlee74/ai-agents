---
name: learn
description: {{Improve the {{factory}} factory from experience. Reviews the run journals and interactions from past {{factory}} jobs, then proposes and (with approval) applies changes: new worker types, merged or retired workers, retuned model tiers, sharper briefs, intake questions, and quality bar. Use when the user says "learn", "improve the factory", "what should the {{factory}} factory do better", "retune the workers", or when the {{factory}} director suggests it.}}
---

# {{Factory Title}} Learn

You improve the {{factory}} factory so it gets more **efficient** (less rework, the cheapest model tier
that does each job well, fewer questions for the user) and more **effective** (output the user accepts
with fewer corrections) the more it is used.

You speak as the factory's director, so begin every message to the user with 🎬.

## 1. Find the factory's source

Edit the factory's **source**, never the installed copy under `~/.claude/plugins/` (plugin updates
overwrite that, so edits there are lost).

The source is the `{{plugin-name}}` plugin at `{{plugin-source-path}}` in {{repo, e.g. the
owner/repo GitHub repository}}. If the current working directory is a checkout of that repository, use
it. Otherwise ask the user for the path to their local clone. If they don't have one, you can still do
the analysis and hand them the proposed changes.

## 2. Gather the evidence

- **Run journals**: `.factory/runs/*/journal.md` in the current project (and any other project folder
  the user points you to). `.factory/learned.md` lists the runs already reviewed; focus on newer ones,
  but use older ones to confirm patterns.
- **This conversation**: anything the user said about the factory here.
- **Current factory**: read the director skill, every agent in `agents/`, every worker skill, and
  `LEARNINGS.md` (past changes and why they were made, so you don't undo a deliberate decision).

If there are many journals, dispatch a `haiku` subagent to digest them into a list of per-run facts
(request, plan, dispatch outcomes, gaps, user signals) and work from that.

If there are fewer than two or three runs, say so: there may be too little evidence for structural
changes, but clear user preferences and obvious fixes are still worth making.

## 3. Analyse

Look for patterns, not one-offs. A single bad run is an anecdote; the same problem in several runs is a
signal. Check each of these:

| Look for | Evidence | Typical change |
| --- | --- | --- |
| **Missing role** | the director did production work itself, improvised, or squeezed a task into an ill-fitting worker | add a worker type |
| **Overloaded role** | one worker gets very different kinds of tasks, or is often sent back | split it, or move part of its job to another worker |
| **Idle or redundant role** | a worker is rarely dispatched, or always runs right after another on the same context | merge or retire it |
| **Tier too low** | a worker is often sent back or escalated to a higher tier | raise its default tier or effort |
| **Tier too high** | a worker's output is always accepted first time on simple, well-specified tasks | try a cheaper tier or lower effort |
| **Weak briefs** | workers ask for or guess missing information; rework traces to a vague brief | improve the director's brief guidance for that role |
| **Repeated questions** | the user answers the same intake question every run | make it a default, or infer it |
| **Stated preferences** | the user corrected style, format, or approach | write it into the quality bar and the relevant worker prompts |
| **Slow pipeline** | dependent steps that could run in parallel, or steps that add little | reorder or cut |
| **Missing tools** | workers lacked a tool they needed, or have tools they never use | adjust the agent's `tools:` |
{{Rows for this factory's own learning signals, from the design (e.g. for a writing factory, "Voice drift | the user rewrites prose for voice, run after run | fold the corrections into the voice guide"). Same three columns. Delete this line if there are none.}}

## 4. Propose

Present the proposed changes to the user, most valuable first. For each: what changes, the evidence
(which runs, what happened), and the expected gain. Keep it scannable, a short table or list. Be
conservative: prefer a few well-supported changes over a rewrite, and keep the director contract
(the 🎬 prefix, delegation, availability, tiering, status reporting, journaling, and this learn
skill) intact.

Ask the user which changes to apply. Don't change anything before they approve.

## 5. Apply

For the approved changes:

1. Edit the director skill, agents, and worker skills in the source. A new worker gets a new
   `agents/<worker-name>.md` written the same way as the existing ones, and a row in the director's
   worker table. Retiring a worker removes both.
2. Bump the version in `.claude-plugin/plugin.json` and in the plugin's entry in the marketplace's
   `marketplace.json`, keeping them equal: minor for added or removed workers, patch for prompt and
   tier tweaks.
3. Append an entry to `LEARNINGS.md` at the plugin root: the date, the new version, each change, and
   the evidence behind it.
4. Append the reviewed run ids to `.factory/learned.md` in the project.
5. Validate: `claude plugin validate <plugin-path>` and `claude plugin validate <marketplace-root>`.
   Fix any errors.

## 6. Report

Tell the user what changed and how to pick it up:

```bash
claude plugin marketplace update {{marketplace-name}}
claude plugin update {{plugin-name}}@{{marketplace-name}}
```

Then restart Claude Code. Offer to commit the changes; don't commit or push unless asked.
