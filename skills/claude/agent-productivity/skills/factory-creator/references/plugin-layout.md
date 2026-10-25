# Plugin and Marketplace Layout

A factory is a Claude Code plugin listed in a marketplace. A marketplace is a git repo (or directory)
with a `.claude-plugin/marketplace.json` that lists one or more plugins.

## Layout

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

Names (plugin, skills, agents) are kebab-case. A skill's folder name matches its `name` frontmatter;
an agent's file name matches its `name` frontmatter.

## marketplace.json

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

## plugin.json

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

## Skill frontmatter

```markdown
---
name: <skill-name>
description: <what it does AND when to use it, with example phrasings; this is how Claude decides to load it>
---
```

## Agent frontmatter

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

`plugin validate` checks manifests only. It accepts unknown frontmatter fields and invalid `model` or
`effort` values, so check those by hand.

Use model aliases (`haiku`, `sonnet`, `opus`), not dated model IDs, so factories keep working as
models are updated. Grant only the tools a worker needs; a researcher doesn't need `Edit`, a
formatter doesn't need `WebSearch`.

Inside a plugin, the director dispatches a worker with the Agent tool using the agent's namespaced
type, `<plugin-name>:<worker-name>`.

## Installing and sharing

```bash
# local test
claude plugin marketplace add <path-to-repo-root>
claude plugin install <plugin-name>@<marketplace-name>

# others, once pushed to GitHub
claude plugin marketplace add <owner>/<repo>
claude plugin install <plugin-name>@<marketplace-name>
```

Validate before handing off:

```bash
claude plugin validate <path-to-plugin>
claude plugin validate <path-to-repo-root>
```
