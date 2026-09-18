# Tank Squad: instructions for Claude

**Work out which role you are first.** In the main checkout `~/projects/godot` on `main` you are the
**orchestrator**: invoke the `round` skill and read `_agents/orchestration.md`. In a `godot-<stream>`
worktree you are a **worker**: read `_agents/orchestration.md` (*The worker contract*),
`_agents/workstreams.md`, and your brief in `_agents/streams/<stream>.md`. This is the orchestrator/worker
pattern and it is how every round of this project runs.

1. Read `HANDOFF.md`, then `_agents/orientation.md`, before doing anything.
2. Every workflow is a Makefile target (`make help`). If `.tools/` is missing, run `make bootstrap`. Heavy
   targets run on builder0: `make remote T=check` (`_agents/remote_builds.md`). **Read its result from the
   wrapper's own `>> remote: make check exited <N>` line and the runner's `N passed, M failed` — never a
   shell exit code through a pipe.**
3. Don't call a task done without the relevant checks in `_agents/verification.md`, and look at the
   screenshots you produce. For anything subjective, a human is the only check that counts.
4. **Every number you report carries its commit and its machine** (the laptop is ~2.75× slower than
   builder0), and every branch you hand over names the commit whose check went green.
5. Before your context is cleared, update `HANDOFF.md` (or, on a workstream branch, your brief's **Status**
   section) and any `_agents/` doc your work made stale. The test: *what would a fresh agent with only this
   repo have to rediscover?*
6. Stay inside the paths your stream owns; contract changes go through `_agents/workstreams.md`.
