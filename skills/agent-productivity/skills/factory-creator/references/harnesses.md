# Harness Adapters

factory-creator is harness-agnostic: the director pattern, the design method, the journals and the
learn loop work the same everywhere. What differs between harnesses (Claude Code, other coding
agents, a plain Agent Skills host) is how a factory is packaged, how the director starts a worker,
which models the tiers map to, and how the result is installed. An **adapter** captures those
differences for one harness.

## Pick the adapter

Build each factory for one target harness. By default that's the harness you're running in; use
another only if the user asks for it.

| Harness | Adapter | Use when |
| --- | --- | --- |
| Claude Code | [harness-claude-code.md](harness-claude-code.md) | You're running in Claude Code (you have its Agent and Skill tools and the `claude` CLI), or the user asks for a Claude Code plugin |
| Any other Agent Skills host | [harness-portable.md](harness-portable.md) | Any other harness, or when you're unsure. It produces a plain Agent Skills bundle that a host can load and the user can wire up |

Read the chosen adapter in full before step 2 of the workflow. If you used the portable adapter
because no specific one exists for the user's harness, say so in the hand-off and in the creation
journal: that's the evidence for writing a new adapter.

## What an adapter defines

Every adapter has the same sections, so factory-creator and the learn skills can rely on them:

1. **Where it goes**: how to find existing packages (marketplaces, bundles) in the repo, the
   checkpoint question to ask, and the default location for a new factory.
2. **Layout**: the factory's files and folders, and any manifests.
3. **Names**: how skills and workers are named and namespaced, and how the user invokes the director
   and the learn skill.
4. **Workers**: where worker definitions live, their header format, and how a worker gets the worker
   skills it uses.
5. **Dispatch**: how the director starts a worker, whether it runs in the background, how the
   director hears it finished, and how to stop one.
6. **Tiers**: what `small`, `medium` and `large` (and reasoning effort) map to, and how to override a
   worker's default tier for one dispatch.
7. **Tools**: the harness's names for common worker tools, a structured-question tool for
   checkpoints, and a timer for status heartbeats, where they exist.
8. **Validation**: commands to run and checks to do by hand.
9. **Install, update, share**: the commands to give the user, and where the installed copy lives (so
   learn skills edit the source, not the copy).
10. **Separate session**: whether factory-creator can start `factory-creator-learn` in a new session,
    and how.
11. **Template slots**: the value for each `{{slot:...}}` and `{{tier:...}}` placeholder in
    `../templates/`.

## Template slots

The templates are harness-neutral. Anything harness-specific is a slot the adapter fills:

| Slot | Meaning |
| --- | --- |
| `{{tier:small}}`, `{{tier:medium}}`, `{{tier:large}}` | How the tier is written in this harness (a model alias, or the tier name itself) |
| `{{slot:worker-header}}` | The header at the top of each worker definition (front matter: name, description, tier, tools, skills) |
| `{{slot:worker-skills}}` | How a worker makes sure it has its worker skills loaded |
| `{{slot:dispatch}}` | One paragraph telling the director how to start a worker and how it hears back |
| `{{slot:override}}` | How the director overrides a worker's tier for one dispatch |
| `{{slot:heartbeat}}` | How the director schedules a recurring status check-in, or what to do without a timer |
| `{{slot:learn-skill}}` | How the user invokes the factory's learn skill |
| `{{slot:worker-files}}` | Where worker definitions live, relative to the factory root |
| `{{slot:installed-copy}}` | Where the harness keeps installed copies, which learn must not edit |
| `{{slot:version-files}}` | The files that carry the factory's version and must stay in sync |
| `{{slot:validate}}` | The validation commands for the factory |
| `{{slot:update}}` | The commands a user runs to pick up a new version, plus any restart needed |

## Writing a new adapter

To support another harness, copy [harness-portable.md](harness-portable.md) to
`harness-<name>.md`, fill each section from that harness's documentation, add a row to the table at
the top of this file, and record the change in the plugin's `LEARNINGS.md`. Verify each claim
against the harness's docs or by building and running a small factory; mark anything unverified as
such rather than guessing.
