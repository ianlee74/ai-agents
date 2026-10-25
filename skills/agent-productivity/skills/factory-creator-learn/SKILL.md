---
name: factory-creator-learn
description: Improve the factory-creator skill from experience. Reviews factory-creator's creation journals and the factories it has built (including what each factory's own learn skill later had to fix), then proposes and, once approved, applies changes to factory-creator's workflow, the director pattern, its harness adapters, and its templates. Use when the user says "improve factory-creator", "learn from the factories we've built", "factory-creator-learn", "why do my factories keep needing the same fixes", or when factory-creator offers it at the end of a factory creation session.
license: MIT
---

# Factory Creator Learn

You improve `factory-creator` so that the factories it builds come out right the first time, on every
harness it targets: fewer questions for the user, fewer design changes at the checkpoint, fewer
validation fixes, and fewer fixes the factories' own learn skills have to make later.

## 1. Find the source

Edit the **source** of the `agent-productivity` bundle, never an installed copy (updates overwrite
those, so edits there are lost). The source is `skills/agent-productivity/` in the `ianlee74/ai-agents`
repository. That folder is both a Claude Code plugin (listed in the repo's
`.claude-plugin/marketplace.json`, marketplace `ianlee74-ai-agents`) and a plain Agent Skills bundle.
If the current working directory is a checkout of that repository, use it. Otherwise ask the user for
the path to their clone. If they don't have one, do the analysis and hand them the proposed changes.

## 2. Gather the evidence

There are two kinds of evidence. Gather both.

**How creation went**, from factory-creator's own journals:

- `.factory/creations/*.md` in the current repo and any other repo the user has built factories in
  (ask). `.factory/creations/learned.md` lists the journals already reviewed; focus on newer ones, but
  use older ones to confirm patterns. Each journal records the harness it ran in and the adapter it
  used.
- Anything the user said about factory-creator in this conversation.

**How the factories turned out**, from the factories factory-creator built:

- Each factory's `LEARNINGS.md`. Its first entry is the original design; later entries are changes
  its learn skill made from real use. Those later entries are the most valuable evidence you have:
  a fix that several factories needed after the fact is a fix factory-creator should make up front.
- Each factory's current director, worker definitions, and learn skill, compared with
  factory-creator's templates, to see where factories have drifted and whether the drift is an
  improvement.
- Each factory's run journals (`.factory/runs/*/journal.md`), if the user points you to projects
  where the factories were used.

Find factories by looking for a `LEARNINGS.md` next to a director skill and a learn skill, in the
repos the user tells you about. If there's a lot to read, have `small`-tier workers or subagents
digest each factory's evidence into a short summary, and work from those.

Also read factory-creator's current `SKILL.md`, `references/` (the director pattern and every
harness adapter), `templates/`, and the bundle's own `LEARNINGS.md`, so you don't undo deliberate
decisions.

If there's little evidence (one or two factories, no learn history yet), say so: structural changes
probably aren't justified, but clear user preferences and obvious fixes still are.

## 3. Analyse

Look for patterns across factories, not one-offs:

| Look for | Evidence | Typical change |
| --- | --- | --- |
| **Recurring post-hoc fixes** | several factories' learn runs made the same kind of change (e.g. always added a reviewer, always lowered a tier for formatting work) | build it into the design guidance or templates |
| **Checkpoint churn** | users often change the proposed roster or tiers in the same way | change the default design heuristics or tier guidance |
| **Unnecessary questions** | journals show questions whose answers could have been inferred | infer them, or propose a default instead of asking |
| **Missing questions** | factories later needed information the intake never asked for | add it to step 1 |
| **Template gaps** | placeholders that didn't fit, sections every factory had to add or delete | reshape the templates |
| **Validation failures** | the same validator errors across creations | fix the templates or the adapter's validation section |
| **Adapter gaps** | creations on one harness hit the same workaround, or used the portable adapter for a harness that keeps coming up | fix that adapter, or write a new one (see `references/harnesses.md`) |
| **Leaking harness details** | something harness-specific crept into the pattern, the templates or SKILL.md | move it into the adapters as a slot |
| **Weak director contract** | factories' directors repeatedly drifted from a rule, or users pushed back on one | clarify the rule in `director-pattern.md`, or raise it with the user |
| **Stated preferences** | the user said how they want factories built | write it into the skill |

Keep the split clean: the director pattern, the workflow and the templates stay harness-neutral, and
everything specific to one harness lives in its adapter. Changes to the director pattern itself (the
rules in `references/director-pattern.md`) change every future factory on every harness. Propose them
only with strong evidence or at the user's request, and say clearly that that's what they are.

## 4. Propose

Present the proposed changes, most valuable first. For each: what changes, the evidence (which
creations or factories, on which harness, what happened), and the expected gain. Keep it scannable.
Prefer a few well-supported changes over a rewrite. Ask the user which to apply, and change nothing
before they approve.

## 5. Apply

For the approved changes:

1. Edit factory-creator's `SKILL.md`, `references/`, and `templates/` in the source. If you change
   this skill's own workflow, edit this file too.
2. Bump the version in `skills/agent-productivity/.claude-plugin/plugin.json` and in its entry in the
   repo's `.claude-plugin/marketplace.json`, keeping them equal: minor for workflow, pattern or adapter
   changes, patch for wording and template tweaks.
3. Append an entry to the bundle's `LEARNINGS.md`: the date, the new version, each change, and the
   evidence behind it.
4. Append the reviewed journals to `.factory/creations/learned.md`.
5. Validate from the repo root:
   - `claude plugin validate --strict skills/agent-productivity` and `claude plugin validate --strict .`,
     if the `claude` CLI is available;
   - the Agent Skills rules for each `SKILL.md` (name matches its folder, lowercase letters, digits and
     single hyphens, at most 64 characters; description at most 1024 characters), with
     `skills-ref validate` if it's installed;
   - no unintended `{{` outside `templates/` and the adapters' slot tables.

   Fix any errors.

## 6. Report and offer to upgrade existing factories

Tell the user what changed and how to pick it up on each harness they use: for Claude Code, the
update commands in `references/harness-claude-code.md`, then a restart; elsewhere, pull the source
and copy the skill folders again (symlinked folders update on their own).

Existing factories don't change when factory-creator does. If an applied change would help factories
already built (a new contract rule, a fixed template section), list which factories it applies to
and offer to bring them up to date. If the user agrees, make the change in each one, bump its version,
and add an entry to its `LEARNINGS.md`. Don't overwrite what a factory's own learn skill has
deliberately tuned.

Offer to commit the changes; don't commit or push unless asked.
