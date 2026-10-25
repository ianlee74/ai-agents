# agent-productivity

Skills that build other skills. Harness-agnostic: the skills follow the open
[Agent Skills](https://agentskills.io/specification) format, and this folder is also a Claude Code
plugin.

## Skills

### factory-creator

Turns a desired outcome ("write grant proposals", "turn podcasts into blog posts") into a **factory**:
a shareable set of skills and workers built on the director pattern.

- A **director** skill (prefixed with 🎬) talks with you as a creative partner, breaks requests into
  roles, and dispatches workers. It stays available while work runs and reports status regularly.
- **Workers** do the production work, each at a tuned model tier: `small` for light work, `medium`
  for standard work, `large` for creative or deep-reasoning work.
- A **learn** skill makes the factory self-improving. The director keeps a short journal of every job
  (plan, rework, gaps, your corrections and preferences), and learn reviews those journals and
  proposes changes: new worker types, merged or retired workers, retuned tiers, sharper briefs. It
  applies them only once you approve.

The [director pattern](skills/factory-creator/references/director-pattern.md) is the same on every
harness. A **harness adapter** maps it onto a particular harness: how the factory is packaged, how the
director starts workers, and which models the tiers mean. There are two so far:

| Adapter | Produces |
| --- | --- |
| [Claude Code](skills/factory-creator/references/harness-claude-code.md) | A plugin in a marketplace; workers are plugin subagents, tiers map to `haiku` / `sonnet` / `opus` |
| [Portable](skills/factory-creator/references/harness-portable.md) | A plain Agent Skills bundle for any other host; worker definitions travel inside the director skill |

factory-creator builds for the harness it's running in unless you ask for another. To add support for
a new harness, see [references/harnesses.md](skills/factory-creator/references/harnesses.md).

### factory-creator-learn

Makes factory-creator self-improving. factory-creator keeps a short journal of each factory it builds
(harness, questions asked, design changes you made, problems hit), and `factory-creator-learn` reviews
those journals together with each factory's `LEARNINGS.md`. When several factories needed the same
fix after the fact, factory-creator should get it right up front. It proposes changes to
factory-creator's workflow, the director pattern, the adapters and the templates, applies them once
you approve, and offers to bring existing factories up to date. factory-creator offers to run it at
the end of every factory creation session, by default in a new session on the most capable model.
Changes are recorded in [LEARNINGS.md](LEARNINGS.md).

## Install

### Claude Code

From GitHub:

```bash
claude plugin marketplace add ianlee74/ai-agents
claude plugin install agent-productivity@ianlee74-ai-agents
```

From a local clone, use the clone's path in place of `ianlee74/ai-agents`. Restart Claude Code, then
ask it to "build a factory for ..." or run `/agent-productivity:factory-creator`.

### Other harnesses

Copy or symlink `skills/factory-creator/` and `skills/factory-creator-learn/` into the directory your
harness loads Agent Skills from (see its documentation), then ask it to "build a factory for ...". Keep
the two folders side by side: factory-creator-learn reads factory-creator's references. factory-creator
uses the portable adapter on harnesses that don't have their own yet; the factories it builds there
are Agent Skills bundles too.
