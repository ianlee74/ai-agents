# Harness Adapter: Portable (Agent Skills)

Use this adapter for any harness without its own adapter. It produces a plain bundle of
[Agent Skills](https://agentskills.io/specification) (folders holding a `SKILL.md`) that any host
supporting the format can load. Worker definitions travel inside the director's skill, so the
director can find them wherever the host installs it. Nothing here depends on a particular vendor's
tools; where the harness's own mechanism matters, the director is told to use "the harness's"
equivalent and to fall back as described in rule 10 of the director pattern.

Some of this adapter is necessarily general. When you use it for a specific harness, look up that
harness's documentation for how it loads skills and runs subagents, use what it offers, and note in
the creation journal what you had to work out. That is how a dedicated adapter gets written.

## 1. Where it goes

Look for existing bundles in the current repository first: directories that hold one or more
`<name>/SKILL.md` skill folders alongside a `LEARNINGS.md`. If there are any, ask whether to add the
factory to one of them or create a new one. Otherwise ask what the factory should be called (suggest
a kebab-case name derived from the outcome, e.g. `grant-proposal-factory`) and where it should live
(default: `factories/<name>/`). Follow the repo's own conventions if it has them.

## 2. Layout

```text
<factory>/
├── README.md
├── LEARNINGS.md                       # changelog of what learn changed, and why
├── VERSION                            # one line, e.g. 0.1.0
└── skills/
    ├── <factory>-director/
    │   ├── SKILL.md                   # the director (user invokes this)
    │   └── workers/
    │       ├── <worker-a>.md          # one definition per worker role
    │       └── <worker-b>.md
    ├── <factory>-learn/
    │   └── SKILL.md                   # self-improvement from run journals
    └── <factory>-<worker-skill>/      # optional reusable procedures/reference
        ├── SKILL.md
        └── references/...
```

Each skill folder is self-contained, as the Agent Skills format expects: it refers to its own files by
relative path (`workers/<worker>.md`) and to sibling skills by name, never by a path outside itself.

## 3. Names

Hosts don't namespace skills from different bundles, so every skill name starts with the factory
name: `<factory>-director`, `<factory>-learn`, `<factory>-<worker-skill>`. Names follow the Agent
Skills rules: 1–64 characters of lowercase letters, digits and single hyphens, not starting or ending
with a hyphen, and equal to the folder name. Descriptions are 1–1024 characters and say what the skill
does and when to use it. The user invokes the director by its name or by describing a request its
description matches.

## 4. Workers

One file per worker at `skills/<factory>-director/workers/<worker-name>.md`:

```markdown
---
name: <worker-name>
description: <what this worker does and when the director should use it>
tier: small | medium | large
effort: low | medium | high | max       # optional
tools: <the capabilities this worker needs, e.g. read files, write files, run shell commands, web search>
skills: <factory>-<worker-skill>        # optional
---
<the worker's role prompt>
```

Tools are described as capabilities rather than one harness's tool names, so the director can map them
to whatever the harness provides. A worker that uses a worker skill loads it through the harness's
skill mechanism; if the harness has none it can reach, the director pastes the skill's content into
the brief.

## 5. Dispatch

The director reads the worker's definition and starts it with the harness's subagent or delegation
mechanism: the definition's body is the worker's instructions, followed by the brief. Run workers in
the background if the harness can and dispatch independent ones together. If the harness can't run
subagents, the director follows rule 10 of the director pattern and runs each role as a clearly
separated step.

## 6. Tiers

The tier names `small`, `medium` and `large` are used as written. At dispatch, the director maps them
to the harness's models (its fastest, its default balanced, and its most capable) if the harness lets
it choose a model per subagent. If it doesn't, the tiers stay in the definitions as documentation, and
the director says once that workers run on the session's model. The same goes for `effort`.

## 7. Tools

Use the harness's equivalents where they exist: a structured-question tool for checkpoints (otherwise
ask in plain text with numbered options), and a timer for heartbeats (otherwise skip the heartbeat
and report at each dispatch, completion and user message).

## 8. Validation

There's no manifest to validate. Check by hand, or with
[`skills-ref validate`](https://github.com/agentskills/agentskills/tree/main/skills-ref) on each
skill folder if it's installed:

- no `{{` left anywhere in the factory (grep for it);
- every `SKILL.md` has valid `name` and `description` frontmatter by the rules in section 3, and its
  name matches its folder;
- every worker definition has `name`, `description` and `tier`, its name matches its file name, `tier`
  is `small`, `medium` or `large`, and any `effort` is `low`, `medium`, `high` or `max`;
- every skill named in a worker's `skills:` exists in the bundle.

## 9. Install, update, share

Tell the user to copy or symlink each folder under `skills/` into the directory their harness loads
Agent Skills from, as its documentation describes, and to start a new session. To update, pull the
latest source and copy again (a symlink picks it up automatically). To share, push the repo; others
do the same. Remind them the installed copies are copies: improvements belong in the source.

## 10. Separate session

If the harness can start a separate session or task, start one with the most capable model and a
prompt that invokes `factory-creator-learn`. Otherwise tell the user to start a new session in the
repo and ask for `factory-creator-learn`.

## 11. Template slots

| Slot | Value |
| --- | --- |
| `{{tier:small}}` / `{{tier:medium}}` / `{{tier:large}}` | `small` / `medium` / `large` |
| `{{slot:worker-header}}` | The worker frontmatter in section 4 |
| `{{slot:worker-skills}}` | "Before you start, make sure you have the `<factory>-<skill>` skill loaded; if your harness can't load it, the director has pasted it into your brief." |
| `{{slot:dispatch}}` | "Each worker's definition is in `workers/<worker-name>.md` next to this file. To dispatch one, start a subagent with the harness's delegation mechanism, giving it that file's body followed by your brief. Run workers in the background if the harness can, and dispatch independent ones together. If the harness can't run subagents, run each role as a clearly separated step (rule 10 of the director pattern)." |
| `{{slot:override}}` | "choosing a different model for that one subagent, if the harness allows it" |
| `{{slot:heartbeat}}` | "if the harness offers a timer or recurring check-in, schedule one every N minutes while workers are running … cancel it when the last worker finishes; without a timer, report at every dispatch, completion and user message" |
| `{{slot:learn-skill}}` | the `<factory>-learn` skill |
| `{{slot:worker-files}}` | `skills/<factory>-director/workers/<worker-name>.md` |
| `{{slot:installed-copy}}` | wherever the harness keeps installed skills |
| `{{slot:version-files}}` | `VERSION` |
| `{{slot:validate}}` | The checks in section 8 |
| `{{slot:update}}` | "pull the latest source and copy the skill folders again (symlinks update automatically), then start a new session" |
