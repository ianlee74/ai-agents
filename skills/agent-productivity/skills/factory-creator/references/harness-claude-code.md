# Harness Adapter: Claude Code

A Claude Code factory is a **plugin** listed in a **marketplace**: a git repo (or directory) with a
`.claude-plugin/marketplace.json` that lists one or more plugins. Workers are plugin subagents.

## 1. Where it goes

Look for existing marketplaces in the current repository before asking anything:

```bash
git ls-files --cached --others --exclude-standard | grep -E '(^|/)\.claude-plugin/(marketplace|plugin)\.json$'
```

(If the directory isn't a git repo, search with Glob for `**/.claude-plugin/*.json` instead.)

- **If one or more `marketplace.json` files exist**: read each, then show the user the marketplace
  name(s) and the plugins already listed in them (name + description). Ask whether to:
  1. add the new skills to one of those existing plugins,
  2. create a new plugin inside an existing marketplace (then ask for the plugin name), or
  3. create a brand-new marketplace and plugin elsewhere.
- **If none exist**: ask what the plugin should be called (suggest a kebab-case name derived from the
  outcome, e.g. `grant-proposal-factory`), and where it should live (default: `plugins/<name>/` with a
  `.claude-plugin/marketplace.json` at the repo root). Also ask for a marketplace name if a new
  marketplace is being created (suggest one based on the repo or owner).

If the chosen plugin name collides with an existing plugin, say so and ask for another. Plugin names
must not start with `claude-` or `anthropic-` (the validator reserves them).

## 2. Layout

```text
<repo-root>/
├── .claude-plugin/
│   └── marketplace.json          # lists the plugins in this repo
└── <plugins-dir>/<plugin-name>/  # e.g. plugins/grant-proposal-factory/
    ├── .claude-plugin/
    │   └── plugin.json           # plugin manifest
    ├── README.md
    ├── LEARNINGS.md              # changelog of what learn changed, and why
    ├── skills/
    │   ├── <director-name>/
    │   │   └── SKILL.md          # the director (user invokes this)
    │   ├── learn/
    │   │   └── SKILL.md          # self-improvement from run journals
    │   └── <worker-skill>/       # optional reusable procedures/reference
    │       ├── SKILL.md
    │       └── references/...
    └── agents/
        ├── <worker-a>.md         # one subagent per worker role
        └── <worker-b>.md
```

Every file a plugin uses must live inside the plugin directory: installed plugins are copied to a
cache, and paths that leave the plugin root don't load.

### marketplace.json

```json
{
  "name": "<marketplace-name>",
  "owner": { "name": "<owner name>" },
  "metadata": { "description": "<what this marketplace holds>" },
  "plugins": [
    {
      "name": "<plugin-name>",
      "source": "./<plugins-dir>/<plugin-name>",
      "description": "<one sentence>",
      "version": "0.1.0"
    }
  ]
}
```

`source` is relative to the repo root (the directory containing `.claude-plugin/`) and starts with
`./`. When adding a plugin to an existing marketplace, append to `plugins` and keep everything else.

### plugin.json

```json
{
  "name": "<plugin-name>",
  "description": "<one sentence>",
  "version": "0.1.0",
  "author": { "name": "<author name>" },
  "keywords": ["..."]
}
```

Keep `version` in plugin.json and the marketplace entry in sync. Bump the minor version when adding
skills or agents to an existing plugin, the patch version for prompt fixes.

## 3. Names

Names (plugin, skills, agents) are kebab-case. A skill's folder name matches its `name` frontmatter;
an agent's file name matches its `name` frontmatter. Claude Code namespaces everything under the
plugin name, so the learn skill is just `learn`: the user runs `/<plugin-name>:<director-name>` and
`/<plugin-name>:learn`, and the director dispatches `<plugin-name>:<worker-name>`.

## 4. Workers

One agent file per worker at `agents/<worker-name>.md`:

```markdown
---
name: <worker-name>
description: <what this worker does and when the director should use it>
model: haiku | sonnet | opus | inherit
effort: low | medium | high | xhigh | max     # optional
tools: Read, Grep, Glob, Write, Edit, Bash, WebSearch, WebFetch   # optional; omit to inherit all
skills: <plugin-name>:<worker-skill>   # optional; worker skills to preload
---
<system prompt for the worker>
```

`skills:` preloads each listed skill's full content into the worker at startup. The docs don't say
whether plugin-namespaced names resolve there, so a worker that uses a worker skill also gets `Skill`
in its `tools` and a line in its prompt telling it to load the skill with the Skill tool if it isn't
already in context. Don't tell a worker to "read" a skill by path: the installed plugin lives
somewhere the worker can't predict.

Grant only the tools a worker needs; a researcher doesn't need `Edit`, a formatter doesn't need
`WebSearch`. Plugin agents ignore `hooks`, `mcpServers` and `permissionMode` frontmatter.

## 5. Dispatch

The director starts a worker with the Agent tool, `subagent_type: "<plugin-name>:<worker-name>"`.
Subagents run in the background and the director is notified when each finishes, so it stays
available to the user. Independent workers are dispatched together in one message. A running worker
can be stopped with the task-stop tool when its output is no longer needed.

## 6. Tiers

| Tier | Claude Code `model` |
| --- | --- |
| `small` | `haiku` |
| `medium` | `sonnet` |
| `large` | `opus` |

Use these aliases, not dated model IDs, so factories keep working as models are updated. `effort:`
(`low` → `max`) is the reasoning-effort dial. The director overrides a worker's default for one
dispatch with the Agent tool's `model` parameter.

## 7. Tools

- Common worker tools: `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `WebSearch`, `WebFetch`,
  `Skill`.
- Structured questions at checkpoints: `AskUserQuestion`, when available.
- Heartbeat timer: an in-session recurring check-in via `CronCreate`, or `/loop`, when available.

## 8. Validation

Run, from the repo root:

```bash
claude plugin validate --strict <path-to-plugin>
claude plugin validate --strict <path-to-marketplace-root>
```

The validator checks manifests and component paths only: it doesn't look at skill or agent
frontmatter values or leftover placeholders, and it accepts an invalid `model`. So also check by
hand:

- no `{{` left anywhere in the plugin (grep for it);
- every SKILL.md and agent file has `name` and `description` frontmatter, and names are kebab-case and
  match their folder/file names;
- every agent's `model` is `haiku`, `sonnet`, `opus`, or `inherit`, and any `effort` is `low`,
  `medium`, `high`, `xhigh`, or `max`;
- every skill named in an agent's `skills:` exists in the plugin, and that agent has `Skill` in its
  `tools` (if it lists tools).

If the `claude` CLI isn't available, also check that the JSON parses and that the marketplace `source`
path points at the plugin directory.

## 9. Install, update, share

```bash
# local test
claude plugin marketplace add <path-to-repo-root>
claude plugin install <plugin-name>@<marketplace-name>

# others, once pushed to GitHub
claude plugin marketplace add <owner>/<repo>
claude plugin install <plugin-name>@<marketplace-name>

# pick up a new version
claude plugin marketplace update <marketplace-name>
claude plugin update <plugin-name>@<marketplace-name>
```

Restart Claude Code after installing or updating. Installed copies live under `~/.claude/plugins/`;
updates overwrite them, so edit the source.

## 10. Separate session

If a tool for starting a separate session is available (for example the Claude desktop app's
`start_session`), start one with the chosen model and a prompt that invokes
`/agent-productivity:factory-creator-learn`. Otherwise give the user the command to run in a new
terminal from the repo root:

```bash
claude --model opus "/agent-productivity:factory-creator-learn"
```

## 11. Template slots

| Slot | Value |
| --- | --- |
| `{{tier:small}}` / `{{tier:medium}}` / `{{tier:large}}` | `haiku` / `sonnet` / `opus` |
| `{{slot:worker-header}}` | The agent frontmatter in section 4, with `model` from the tier table |
| `{{slot:worker-skills}}` | "Before you start, make sure the `<skill>` skill is in your context. If it isn't, load it with the Skill tool (`<plugin-name>:<skill>`)." |
| `{{slot:dispatch}}` | "Dispatch workers with the Agent tool, using `subagent_type: "<plugin-name>:<worker-name>"`. Workers run in the background and you are notified when each finishes, so you stay available to the user the whole time. Dispatch independent workers together in one message." |
| `{{slot:override}}` | "the Agent tool's `model` parameter" |
| `{{slot:heartbeat}}` | "if a timer tool is available (for example CronCreate for an in-session recurring check-in, or `/loop`), schedule a check-in every N minutes while workers are running … cancel it when the last worker finishes" |
| `{{slot:learn-skill}}` | `/<plugin-name>:learn` |
| `{{slot:worker-files}}` | `agents/<worker-name>.md` |
| `{{slot:installed-copy}}` | `~/.claude/plugins/` |
| `{{slot:version-files}}` | `.claude-plugin/plugin.json` and the plugin's entry in the marketplace's `marketplace.json` |
| `{{slot:validate}}` | The two `claude plugin validate --strict` commands in section 8, plus the manual checks |
| `{{slot:update}}` | The two update commands in section 9, then restart Claude Code |
