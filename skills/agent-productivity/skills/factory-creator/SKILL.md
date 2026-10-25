---
name: factory-creator
description: Build a "factory": a shareable set of skills and worker agents that work together to achieve an outcome or produce a creation the user describes, organized as a director (a conversational lead that delegates) plus workers at tuned model tiers, and packaged for the user's agent harness (a Claude Code plugin, or a portable Agent Skills bundle for other harnesses). Use whenever the user wants to create a skill, set of skills, agent team, workflow plugin, or "something that does X for me" repeatedly, e.g. "make me a factory for writing grant proposals", "build skills that turn podcasts into blog posts", "create a plugin that researches and drafts sales emails", even if they don't say "factory" or "director".
license: MIT
---

# Factory Creator

You build **factories**: packages of skills and worker definitions that, once installed, let the user
start a conversation with a **director** who breaks their request into roles and dispatches
**workers** to do the work. Every factory you create follows the director pattern in
[references/director-pattern.md](references/director-pattern.md). Read that file before designing
anything; it is the contract every factory must honour.

The pattern is harness-agnostic. How a factory is packaged, how its director starts workers, and which
models its tiers map to depend on the harness it will run in (Claude Code, another coding agent, any
Agent Skills host). [references/harnesses.md](references/harnesses.md) says how to pick the adapter
for the target harness; that adapter covers everything harness-specific below.

## Workflow

Work through these steps in order. Keep the user in the loop at the two checkpoints (steps 2 and 4);
don't generate files before both are settled. Use the harness's structured-question tool at
checkpoints when it has one.

### 1. Understand the outcome

Find out what the factory should produce or achieve. Pull what you can from the conversation first,
then ask only for what is missing:

- **The outcome**: what does "done" look like? A document, code, a decision, a recurring report?
- **Inputs**: what will the user hand the director each time (a topic, a URL, a repo, files)?
- **Stages of work**: what steps would a skilled human team go through? Who would be on that team?
- **Quality bar**: how will the user judge the result? Any house style, constraints, or tools
  (MCP servers, CLIs, APIs) the workers must use?
- **Cadence**: one-shot creations, or a pipeline run over and over?

Keep this conversational and short; two or three rounds of questions is usually enough. If the user
gives a one-liner, propose a sensible interpretation and let them correct it rather than interrogating.

### 2. Choose the harness and where the factory goes (checkpoint)

Pick the target harness as [references/harnesses.md](references/harnesses.md) describes (by default,
the one you're running in) and read its adapter in full. Don't ask about the harness unless the user
has mentioned another one.

Then follow the adapter's **Where it goes** section: look for existing packages in the repo first,
and ask whether to add to one of them or create a new one. Follow the repo's own conventions if it has
them (a README describing where skills or plugins go wins over the adapter's defaults). Names must be
kebab-case. If the chosen name collides with an existing one, say so and ask for another.

### 3. Design the factory

Draft the design using [references/director-pattern.md](references/director-pattern.md):

- **Director**: its name (default `<factory>-director`, the skill the user invokes), what it owns,
  the intake questions it asks, how it decomposes a request, and its status-report format.
- **Worker roster**: one row per role. For each: name, responsibility, deliverable, tier (`small` /
  `medium` / `large`) with a one-line reason, effort, tools it needs, and which workers' output it
  depends on. Aim for the smallest roster that covers the work, usually 3-6 workers. Merge roles that
  would always run back-to-back on the same context; split roles that need different intelligence
  levels or can run in parallel.
- **Worker skills (optional)**: reusable procedures or reference material a worker should load (a
  style guide, a checklist, a script). Only add these when a worker needs more than its prompt. Note
  which workers use each one; the adapter's **Workers** section says how they get it.
- **Pipeline**: the typical order of dispatch, marking which steps run in parallel.
- **Deliverables**: what a finished job hands the user. If it's more than one artifact (a post plus
  a directory of code, say), the director gets a "Deliverables" section saying how they travel
  together.
- **Learning signals**: every factory includes a learn skill (rule 9 of the director pattern).
  Note anything outcome-specific it should watch for beyond the defaults, e.g. for a writing factory,
  which edits the user makes to final drafts.

### 4. Confirm the design (checkpoint)

Present the design compactly: a roster table plus the pipeline as a short list or diagram. Show tiers
as `small` / `medium` / `large` with the adapter's mapping alongside (e.g. `large (opus)`). Ask the
user to approve or adjust. Be opinionated: recommend tiers and merges, but let the user overrule.

### 5. Generate the factory

Create the files in the adapter's **Layout**, using the templates in this skill and filling every
`{{slot:...}}` and `{{tier:...}}` placeholder from the adapter's **Template slots**:

- Director skill: [templates/director-SKILL.md](templates/director-SKILL.md).
- One definition per worker: [templates/worker.md](templates/worker.md), with the adapter's worker
  header.
- Learn skill: [templates/learn-SKILL.md](templates/learn-SKILL.md). Fill in the factory's source path
  (relative to the repo root) and the repository it lives in, so it can find and edit the source
  later, and turn the learning signals from step 3 into extra rows of its analysis table. One learn
  skill per factory package; if it holds several directors, it covers all of them. If you're adding
  to a package that already has one, extend it rather than adding a second.
- `LEARNINGS.md` at the factory root: starts with a single entry recording the initial design, the
  target harness, and the reasoning behind the roster and tiers, so later learn runs know what was
  deliberate.
- Optional worker skills, in the adapter's layout.
- Any manifests and version files the adapter lists (create them, or bump the version if adding to an
  existing package).
- `README.md` at the factory root: what the factory does, how to invoke the director, the roster
  table, and install instructions from the adapter.

Fill every placeholder; never leave `{{...}}` in output. Write the director and worker prompts for the
specific outcome: concrete deliverables, the domain's quality bar, examples of good output where it
helps. Generic boilerplate makes weak factories. Explain *why* behind instructions rather than
stacking MUSTs; the models that run these prompts follow reasoning better than rules.

If adding to an existing package, don't overwrite skills or workers that already exist with the same
name; ask first.

### 6. Validate

Run the adapter's **Validation** commands and do its manual checks. Fix every error, and fix warnings
unless there's a reason not to.

### 7. Hand off

Tell the user:

- What was created (paths), the target harness, and the roster at a glance.
- How to install and try it, from the adapter's **Install, update, share** section, and how to invoke
  the director (or that describing a request is enough; the director's description is written to
  trigger on it).
- That the factory improves itself: the director keeps run journals under `.factory/runs/`, and the
  factory's learn skill reviews them and proposes changes. Suggest adding `.factory/` to the
  `.gitignore` of projects where they use the factory, unless they want to keep the journals.
- How to share it, from the adapter.
- If you used the portable adapter because the user's harness has no adapter yet, say so, and that
  the creation journal records what a dedicated adapter would need.
- Offer to commit the changes; don't commit or push unless asked.

### 8. Offer to learn

End every factory creation session by offering to run `factory-creator-learn`, so this session's
journal feeds back into factory-creator while it's fresh. Mention anything from this session that
looks worth learning from, if there was something. Don't run it without asking.

Ask both of these at once:

1. **Run factory-creator-learn?**
   - **In a new session (Recommended)**: keeps this session's context out of the analysis and lets
     the user carry on here.
   - **Here, now**: runs in this session, on this session's current model.
   - **Not now.**
2. **Model for the new session?** (only applies to a new session)
   - **The `large` tier (Recommended)**: learning is judgement-heavy work: spotting patterns across
     factories and deciding what to change in the templates.
   - **The `medium` tier**: cheaper, fine when there's little evidence to review.
   - The user can name another model.

Then act on the answers:

- **New session**: follow the adapter's **Separate session** section. The new session's prompt is to
  run `factory-creator-learn`, with a short brief: the repo path, the journal just written
  (`.factory/creations/<file>.md`), the factory that was created (its path), and anything from this
  session worth looking at. Tell the user once it has started, or give them the command if you can't
  start it yourself.
- **Here, now**: run the `factory-creator-learn` skill. If the user picked a model, explain that this
  session keeps its current model, and that they can switch models in their client first if they
  want to.
- **Not now**: leave it there.

## Creation journal

`factory-creator` improves itself too, through the `factory-creator-learn` skill, which works from the
journals you keep. For every factory you create or change, keep
`.factory/creations/<yyyymmdd>-<factory-name>.md` at the repo root and append to it as you go:

- **Outcome**: what the user wanted the factory to do.
- **Harness**: the harness you ran in, the target harness, and the adapter you used.
- **Questions**: what you asked in steps 1 and 2, and which answers you could have inferred.
- **Design**: the roster and tiers you proposed, and what the user changed at the checkpoint (and
  why, if they said).
- **Problems**: validation failures, template placeholders that didn't fit this outcome, conventions
  you had to work around, anything you improvised that the templates or the adapter didn't cover.
- **User signals**: corrections, complaints, praise, preferences about how factories should be built.
- **Result**: what was created (paths) and whether the user was happy with it.

Keep it short and factual, and never record secrets or credentials. Finish the journal before the
hand-off in step 7, so it is complete when step 8 offers to run `factory-creator-learn`.

## Notes

- 🎬 belongs to directors. Never start your own messages with it, including the hand-off: you are
  building a factory, not directing one.
- One factory per outcome. If the user describes two unrelated outcomes, offer to build two directors
  (they can live in the same package and share workers).
- A factory can be small. A director with two workers is fine if that's what the job needs.
- A factory targets one harness at a time. To run the same factory elsewhere, build it again with that
  harness's adapter; the design and prompts carry over.
- When improving an existing factory, read its current director and worker definitions first and
  edit them in place, keeping the director contract intact. If it has run journals, point the user to
  its learn skill instead, which works from evidence. If it predates the learn rule, add one.
