# agent-productivity

Skills that build other skills.

## Skills

### factory-creator

Turns a desired outcome ("write grant proposals", "turn podcasts into blog posts") into a **factory**:
a shareable marketplace plugin built on the director pattern.

- A **director** skill (prefixed with 🎬) talks with you as a creative partner, breaks requests into
  roles, and dispatches workers. It stays available while work runs and reports status regularly.
- **Worker** subagents do the production work, each at a tuned model tier (`haiku` for light work,
  `sonnet` for standard work, `opus` for creative or deep-reasoning work).
- A **learn** skill makes the factory self-improving. The director keeps a short journal of every job
  (plan, rework, gaps, your corrections and preferences), and `learn` reviews those journals and
  proposes changes: new worker types, merged or retired workers, retuned tiers, sharper briefs. It
  applies them only once you approve.

Before it creates anything, factory-creator checks the current repo for existing marketplaces and asks
whether to add to one of them; if there are none, it asks what to call the new plugin.

### factory-creator-learn

Makes factory-creator self-improving. factory-creator keeps a short journal of each factory it builds
(questions asked, design changes you made, problems hit), and `factory-creator-learn` reviews those
journals together with each factory's `LEARNINGS.md`. When several factories needed the same fix
after the fact, factory-creator should get it right up front. It proposes changes to factory-creator's
workflow, the director pattern, and the templates, applies them once you approve, and offers to bring
existing factories up to date. factory-creator offers to run it at the end of every factory creation session, by default in a new session on Opus (you can pick another model or run it in place). Changes are recorded in [LEARNINGS.md](LEARNINGS.md).

See [skills/factory-creator/references/director-pattern.md](skills/factory-creator/references/director-pattern.md)
for the pattern every factory follows.

## Install

From a local clone:

```bash
claude plugin marketplace add <path-to-ai-agents-repo>
claude plugin install agent-productivity@ianlee74-ai-agents
```

From GitHub:

```bash
claude plugin marketplace add ianlee74/ai-agents
claude plugin install agent-productivity@ianlee74-ai-agents
```

Then ask Claude to "build a factory for ..." or run `/agent-productivity:factory-creator`.
