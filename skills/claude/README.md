# Claude Code-only Skills

Skills that only make sense in Claude Code live here: they depend on Claude Code features and have no
portable form.

Most skills don't belong here. If a skill can be written in the open
[Agent Skills](https://agentskills.io/specification) format with its Claude Code specifics in a
reference file, put it at the top level of `skills/` instead (see [../README.md](../README.md)).

## Suggested layout

```text
skills/claude/
├── README.md
├── templates/
│   └── README.md
└── <skill-name>/
    └── README.md
```
