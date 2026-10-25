# Skills

This directory holds reusable AI agent skills intended to be packaged as marketplace plugins.

## Organization

- Keep skills grouped by model/provider or capability.
- Use a `claude/` namespace for Claude-focused skills since Claude is the primary model.
- Add supporting files such as templates, examples, or manifests next to the skill.
- If a skill is general-purpose and not model-specific, place it at the top level of this directory.

## Example structure

```text
skills/
├── claude/
│   ├── README.md
│   └── templates/
│       └── README.md
└── README.md
```
