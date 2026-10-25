# Skills

This directory holds reusable AI agent skills. They're written to be harness-agnostic wherever
possible, so they work across agent harnesses (Claude Code and others), and they're packaged so each
harness can install them.

## Organization

- **Agnostic by default.** Put a skill, or a bundle of related skills, at the top level of this
  directory. Write each skill in the open [Agent Skills](https://agentskills.io/specification) format
  (a folder holding a `SKILL.md`), and keep harness-specific details (tool names, model names, install
  commands) out of the skill's main instructions: put them in per-harness reference files the skill
  loads when it needs them.
- **Harness packaging lives beside the bundle.** A bundle that's also a Claude Code plugin keeps its
  `.claude-plugin/plugin.json` in its own folder; other harnesses' manifests can sit next to it. A
  bundle's files must all live inside its folder, since installers copy only that folder.
- **`claude/` is for skills that only make sense in Claude Code** (they depend on Claude-only
  features and have no portable form). Prefer the top level whenever a skill can be made agnostic.
- Add supporting files such as templates, examples, or references next to the skill.

## Example structure

```text
skills/
├── agent-productivity/          # bundle: factory-creator, factory-creator-learn
│   ├── .claude-plugin/plugin.json
│   ├── README.md
│   ├── LEARNINGS.md
│   └── skills/
│       ├── factory-creator/
│       └── factory-creator-learn/
├── claude/                      # Claude Code-only skills
│   ├── README.md
│   └── templates/
│       └── README.md
└── README.md
```

## Bundles

| Bundle | Contents |
| --- | --- |
| [agent-productivity](agent-productivity/README.md) | `factory-creator`: builds director-pattern factories for a desired outcome, on any harness; `factory-creator-learn`: improves factory-creator from experience |

For Claude Code, the bundles are listed in [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json)
at the repo root (marketplace name `ianlee74-ai-agents`). For other harnesses, see each bundle's README.
