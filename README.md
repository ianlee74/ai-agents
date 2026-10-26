# ai-agents

Open-source AI agent skills and other AI research work.

Skills here are written to be harness-agnostic wherever possible: they follow the open
[Agent Skills](https://agentskills.io/specification) format and keep harness-specific details in
per-harness reference files, so they can run in Claude Code and other agent harnesses. See
[skills/README.md](skills/README.md) for the layout and [research/](research/README.md) for research
notes.

## Bundles

- [agent-productivity](skills/agent-productivity/README.md): `factory-creator` builds self-improving
  "factories" (a director that delegates to workers at tuned model tiers) for any outcome you
  describe; `factory-creator-learn` improves factory-creator from experience.
- [sdlc](skills/sdlc/README.md): `ship` closes out a coding session: commit, PR, merge, branch and
  worktree cleanup, and archive.

Claude Code users can install everything from this repo's marketplace:

```bash
claude plugin marketplace add ianlee74/ai-agents
```

Licensed under the [MIT License](LICENSE).
