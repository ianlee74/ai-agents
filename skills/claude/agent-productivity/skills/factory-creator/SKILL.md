---
name: factory-creator
description: Build a "factory": a shareable Claude Code marketplace plugin of skills and subagents that work together to achieve an outcome or produce a creation the user describes, organized as a director (a conversational lead that delegates) plus worker subagents at tuned model tiers. Use whenever the user wants to create a skill, set of skills, agent team, workflow plugin, or "something that does X for me" repeatedly, e.g. "make me a factory for writing grant proposals", "build skills that turn podcasts into blog posts", "create a plugin that researches and drafts sales emails", even if they don't say "factory" or "director".
---

# Factory Creator

You build **factories**: plugins that, once installed, let the user start a conversation with a
**director** who breaks their request into roles and dispatches **worker** subagents to do the work.
Every factory you create follows the director pattern in
[references/director-pattern.md](references/director-pattern.md). Read that file before designing
anything; it is the contract every factory must honour.

The output is always a Claude Code **marketplace plugin** so the user can keep it private or share it.
[references/plugin-layout.md](references/plugin-layout.md) has the file layout and manifest formats.

## Workflow

Work through these steps in order. Keep the user in the loop at the two checkpoints (steps 2 and 4);
don't generate files before both are settled.

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

### 2. Choose where the plugin goes (checkpoint)

Look for existing marketplaces in the current repository before asking anything:

```bash
git ls-files --cached --others --exclude-standard | grep -E '(^|/)\.claude-plugin/(marketplace|plugin)\.json$'
```

(If the directory isn't a git repo, search with Glob for `**/.claude-plugin/*.json` instead.)

- **If one or more `marketplace.json` files exist**: read each, then show the user the marketplace
  name(s) and the plugins already listed in them (name + description). Ask, using AskUserQuestion when
  available, whether to:
  1. add the new skills to one of those existing plugins,
  2. create a new plugin inside an existing marketplace (then ask for the plugin name), or
  3. create a brand-new marketplace and plugin elsewhere.
- **If none exist**: ask what the plugin should be called (suggest a kebab-case name derived from the
  outcome, e.g. `grant-proposal-factory`), and where it should live (default: `plugins/<name>/` with a
  `.claude-plugin/marketplace.json` at the repo root). Also ask for a marketplace name if a new
  marketplace is being created (suggest one based on the repo or owner).

Follow the repo's own conventions if it has them (a README describing where skills or plugins go wins
over the defaults here). Names must be kebab-case. If the chosen plugin name collides with an existing
plugin, say so and ask for another.

### 3. Design the factory

Draft the design using [references/director-pattern.md](references/director-pattern.md):

- **Director**: its name (default `<factory>-director`, the skill the user invokes), what it owns,
  the intake questions it asks, how it decomposes a request, and its status-report format.
- **Worker roster**: one row per role. For each: name, responsibility, deliverable, model tier
  (`haiku` / `sonnet` / `opus`) with a one-line reason, effort, tools it needs, and which workers'
  output it depends on. Aim for the smallest roster that covers the work, usually 3-6 workers. Merge
  roles that would always run back-to-back on the same context; split roles that need different
  intelligence levels or can run in parallel.
- **Worker skills (optional)**: reusable procedures or reference material a worker should load (a
  style guide, a checklist, a script). Only add these when a worker needs more than its prompt. Note
  which workers use each one; they get it in `skills:` and the Skill tool (see
  [references/plugin-layout.md](references/plugin-layout.md)).
- **Pipeline**: the typical order of dispatch, marking which steps run in parallel.
- **Deliverables**: what a finished job hands the user. If it's more than one artifact (a post plus
  a directory of code, say), the director gets a "Deliverables" section saying how they travel
  together.
- **Learning signals**: every factory includes a `learn` skill (rule 9 of the director pattern).
  Note anything outcome-specific it should watch for beyond the defaults, e.g. for a writing factory,
  which edits the user makes to final drafts.

### 4. Confirm the design (checkpoint)

Present the design compactly: a roster table plus the pipeline as a short list or diagram. Ask the
user to approve or adjust. Be opinionated: recommend tiers and merges, but let the user overrule.

### 5. Generate the plugin

Create the files using the templates in this skill:

- Director skill: [templates/director-SKILL.md](templates/director-SKILL.md) →
  `<plugin>/skills/<director-name>/SKILL.md`
- One subagent per worker: [templates/worker-agent.md](templates/worker-agent.md) →
  `<plugin>/agents/<worker-name>.md`
- Learn skill: [templates/learn-SKILL.md](templates/learn-SKILL.md) →
  `<plugin>/skills/learn/SKILL.md`. Fill in the plugin's source path (relative to the marketplace
  root), the repository it lives in, and the marketplace name so it can find and edit the source
  later, and turn the learning signals from step 3 into extra rows of its analysis table. One `learn`
  skill per plugin; if the plugin holds several directors, it covers all of them.
  If you're adding to a plugin that already has one, extend it rather than adding a second.
- `<plugin>/LEARNINGS.md`: starts with a single entry recording the initial design and the reasoning
  behind the roster and tiers, so later `learn` runs know what was deliberate.
- Optional worker skills → `<plugin>/skills/<skill-name>/SKILL.md`
- `<plugin>/.claude-plugin/plugin.json` (create, or bump `version` if adding to an existing plugin)
- The marketplace entry in `marketplace.json` (create, or append/update the plugin's entry)
- `<plugin>/README.md`: what the factory does, how to invoke the director, the roster table, and
  install instructions.

Fill every placeholder; never leave `{{...}}` in output. Write the director and worker prompts for the
specific outcome: concrete deliverables, the domain's quality bar, examples of good output where it
helps. Generic boilerplate makes weak factories. Explain *why* behind instructions rather than
stacking MUSTs; the models that run these prompts follow reasoning better than rules.

If adding to an existing plugin, don't overwrite skills or agents that already exist with the same
name; ask first.

### 6. Validate

Run, from the repo root:

```bash
claude plugin validate <path-to-plugin>
claude plugin validate <path-to-marketplace-root>
```

Fix every error, and fix warnings unless there's a reason not to.

The validator checks manifests only: it doesn't look at skill or agent frontmatter values or leftover
placeholders, and it accepts an invalid `model`. So always check these by hand too:

- no `{{` left anywhere in the plugin (grep for it);
- every SKILL.md and agent file has `name` and `description` frontmatter, and names are kebab-case and
  match their folder/file names;
- every agent's `model` is `haiku`, `sonnet`, `opus`, or `inherit`, and any `effort` is `low`,
  `medium`, `high`, `xhigh`, or `max`;
- every skill named in an agent's `skills:` exists in the plugin, and that agent has `Skill` in its
  `tools` (if it lists tools).

If the `claude` CLI isn't available, also check that the JSON parses and that the marketplace `source`
path points at the plugin directory.

### 7. Hand off

Tell the user:

- What was created (paths) and the roster at a glance.
- How to try it locally:
  ```bash
  claude plugin marketplace add <path-to-repo-or-marketplace-root>
  claude plugin install <plugin-name>@<marketplace-name>
  ```
  then start a new session and invoke `/<plugin-name>:<director-name>` (or just describe a request;
  the director's description is written to trigger on it).
- That the factory improves itself: the director keeps run journals under `.factory/runs/`, and
  `/<plugin-name>:learn` reviews them and proposes changes. Suggest adding `.factory/` to the
  `.gitignore` of projects where they use the factory, unless they want to keep the journals.
- How to share it: push the repo to GitHub and others run
  `claude plugin marketplace add <owner>/<repo>` followed by the install command.
- Offer to commit the changes; don't commit or push unless asked.

### 8. Offer to learn

End every factory creation session by offering to run `factory-creator-learn`, so this session's
journal feeds back into factory-creator while it's fresh. Mention anything from this session that
looks worth learning from, if there was something. Don't run it without asking.

Ask both of these at once (one AskUserQuestion call with two questions, when available):

1. **Run factory-creator-learn?**
   - **In a new session (Recommended)**: keeps this session's context out of the analysis and lets
     the user carry on here.
   - **Here, now**: runs in this session, on this session's current model.
   - **Not now.**
2. **Model for the new session?** (only applies to a new session)
   - **Opus (Recommended)**: learning is judgement-heavy work: spotting patterns across factories
     and deciding what to change in the templates.
   - **Sonnet**: cheaper, fine when there's little evidence to review.
   - The user can name another model through the "Other" answer.

Then act on the answers:

- **New session**: if a tool for starting a separate session is available (for example the Claude
  desktop app's `start_session`), start a fresh session with the chosen model (`opus` unless the user
  picked another). Its prompt is to invoke `/agent-productivity:factory-creator-learn`, with a short
  brief: the repo path, the journal just written (`.factory/creations/<file>.md`), the factory that
  was created (its path), and anything from this session worth looking at. Then tell the user it has
  started. If no such tool is available, give the user the command to run in a new terminal from the
  repo root, with their chosen model:
  ```bash
  claude --model opus "/agent-productivity:factory-creator-learn"
  ```
- **Here, now**: invoke the `agent-productivity:factory-creator-learn` skill. If the user picked a
  model, explain that this session keeps its current model, and that they can switch models in their
  client first if they want to.
- **Not now**: leave it there.

## Creation journal

`factory-creator` improves itself too, through the `factory-creator-learn` skill, which works from the
journals you keep. For every factory you create or change, keep
`.factory/creations/<yyyymmdd>-<plugin-name>.md` at the repo root and append to it as you go:

- **Outcome**: what the user wanted the factory to do.
- **Questions**: what you asked in steps 1 and 2, and which answers you could have inferred.
- **Design**: the roster and tiers you proposed, and what the user changed at the checkpoint (and
  why, if they said).
- **Problems**: validation failures, template placeholders that didn't fit this outcome, conventions
  you had to work around, anything you improvised that the templates didn't cover.
- **User signals**: corrections, complaints, praise, preferences about how factories should be built.
- **Result**: what was created (paths) and whether the user was happy with it.

Keep it short and factual, and never record secrets or credentials. Finish the journal before the
hand-off in step 7, so it is complete when step 8 offers to run `factory-creator-learn`.

## Notes

- 🎬 belongs to directors. Never start your own messages with it, including the hand-off: you are
  building a factory, not directing one.

- One factory per outcome. If the user describes two unrelated outcomes, offer to build two directors
  (they can live in the same plugin and share workers).
- A factory can be small. A director with two workers is fine if that's what the job needs.
- When improving an existing factory, read its current director and agents first and edit them in
  place, keeping the director contract intact. If it has run journals, point the user to its
  `learn` skill instead, which works from evidence. If it predates the `learn` rule, add one.
