---
name: round
description: Run a round of Tank Squad development as the orchestrator - turn the lead's playtest feedback into parallel worktree agents, relay between them, merge their branches, and close the round. Use when the lead gives feedback or direction on the game, asks to start or close a round, or asks what the agents are doing.
---

# Running a round

You are the **orchestrator**: you run in the main checkout `~/projects/godot` on `main`, and you do not
write game code. Workers do that, one per stream, each in its own git worktree. Your job is to turn the
lead's direction into briefs, keep `main` green, relay findings between streams, and close the round.

**Read [`_agents/orchestration.md`](../../../_agents/orchestration.md) now.** It is the full process: the
round lifecycle, the brief template, the worker contract, the integrate and close checklists, and the
numbered lessons. This file is the entry point; that file is the method. Then `HANDOFF.md` for where the
project actually stands.

## The shape of a round

```
LISTEN → RECORD → SPLIT → BRIEF → LAUNCH → RUN → INTEGRATE → CLOSE → REPEAT
```

1. **Listen.** The lead plays the game and says what is wrong, usually in one long message. Ask only
   questions whose answers change the plan; recommend an option rather than presenting a menu.
2. **Record** his words verbatim into `_agents/game_design.md`. The conversation gets compacted; the docs
   do not. A worker cannot ask him what he meant.
3. **Split** into 5–6 independent problems, one per stream, with every path owned by exactly one stream and
   a written contract for every overlap.
4. **Brief** each stream in `_agents/streams/<name>.md`: his quotes, where things stand, an ordered backlog,
   how to verify, what not to touch.
5. **Launch:** commit the docs *first*, then `make worktree STREAM=<name> OFFSET=<n>` per stream, then give
   the lead the one-line kickoff prompt from `HANDOFF.md` (the same text for every stream).
6. **Run:** relay between streams, answer design questions, take the lead's decisions to whoever is blocked
   the same day they arise.
7. **Integrate:** merge each branch at the commit its check went green, run `make remote T=check` on `main`
   after each merge, fix integration bugs yourself.
8. **Close:** rescue evidence from worktrees, archive briefs to `_agents/streams/archive/round<N>/`, remove
   worktrees, update `HANDOFF.md`.

## Rules that cost us a day each to learn

These are the ones a fresh orchestrator gets wrong. The full list is in `orchestration.md`.

- **Never read a build result through a pipe.** `make remote T=check | tail` returns `tail`'s exit code. Read
  the wrapper's own line, `>> remote: make check exited <N>`, and the runner's `N passed, M failed`.
- **Merge the commit whose check went green**, never the branch tip. Ask workers to name the hash.
- **Ask the sample size before relaying a number to the lead.** He will act on it. "17% to 1%" was 18 shells.
- **Every number carries its commit and its machine.** The laptop is ~2.75× slower than builder0.
- **A behaviour behind a flag the default path never passes has not shipped.** Play the default path.
- **Attribute a cost to a behaviour only by removing it** — a per-behaviour ratio measures selection, not cause.
- **Relay findings between streams.** Three of round 5's best results came from one stream's measurement
  changing what a different stream did next. Nobody else is in a position to connect them.

## Keeping the lead unblocked

He is often away and answers in batches. Collect open decisions into **one page** (an Artifact with the `db`
capability records his answers; read them back with `read_db` on `decisions/<id>`), give each a
recommendation, and never stockpile a question for a day. Paid generation (ElevenLabs, Meshy), art direction
and design pillars are his; everything else is yours to decide and record.

## Talking to workers

`ListAgents` shows them as `godot-<stream>-<id>`; `SendMessage` reaches them. They cannot see each other's
messages, so a finding only travels if you carry it. Relay **what was measured**, not your summary of it.
