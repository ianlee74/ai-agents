# Learnings

Changes to the agent-productivity plugin and why they were made. `factory-creator-learn` adds an entry
for every change it applies, so it doesn't undo deliberate decisions later.

## 2026-10-25 · v0.1.0 · Initial design

- **factory-creator** builds every factory as a marketplace plugin made of a director skill and
  worker subagents, following `references/director-pattern.md`. The pattern's rules came from Ian:
  the director prefixes messages with 🎬, is a creative partner that delegates rather than doing the
  work, stays available while workers run, breaks requests down, picks a model tier per task, and
  reports status regularly.
- Workers are plugin agents with a default `model`/`effort` in their frontmatter, so each role's tier
  is pinned and tunable. The director can override it per dispatch.
- Workers write progress logs under `.factory/runs/<run-id>/status/` so the director can report real
  status on a heartbeat without interrupting them.
- Every factory includes a `learn` skill and the director keeps run journals (rule 9), at Ian's
  request, so factories improve from use.
- **factory-creator-learn** was added at Ian's request so factory-creator improves from its own
  creation journals (`.factory/creations/`) and from what each factory's `learn` skill later had to fix.

## 2026-10-25 · v0.2.0 · First factory-creator-learn pass

Evidence: two creation journals from 2026-10-25: `ant-news-factory` (interactive test) and
`talk-to-post` (non-interactive dry run with pre-supplied answers). Neither factory has been used, so
there was no `learn` history; changes are limited to template gaps and validation holes both runs hit.

- **Worker skills are wired explicitly.** The worker template gets a `skills:` frontmatter line, `Skill`
  in `tools`, and a fallback line to load the skill with the Skill tool; `plugin-layout.md` documents
  it. Evidence: the template had no way to say a worker uses a skill. ant-news improvised `skills:` plus
  a fallback; talk-to-post told workers to "read" a skill without giving them the Skill tool, which
  likely fails once installed. The Claude Code docs confirm `skills:` preloads skill content into
  subagents but don't say whether plugin-namespaced names resolve, hence the fallback.
- **Step 6 always checks by hand** for leftover `{{`, valid `model`/`effort` values, name/folder
  agreement, and that skills named in `skills:` exist. Evidence: both journals; `claude plugin
  validate --strict` checks manifests only and accepted a bogus `model` in the ant-news test.
- **Learn template has a slot for outcome-specific analysis rows**, filled from step 3's learning
  signals. Evidence: both factories added rows by hand (2 and 9).
- **🎬 is reserved for directors**: factory-creator never uses it itself. Evidence: the talk-to-post
  dry run started its hand-off with 🎬.
- **Multi-artifact deliverables**: the worker template's Deliverable section allows several files or
  a directory, the director template has an optional Deliverables section, and step 3 asks about it.
  Evidence: talk-to-post (one factory) ships `post.md` plus a `code/` directory.

Considered and not applied (Ian's call): a "temporary/test location" option in step 2 and inferring
the marketplace name from the repo README title; a design tip for breaking apparent mutual
dependencies between roles (one-off).
