# Tank Squad: instructions for Claude

1. Read `HANDOFF.md`, then `_agents/orientation.md`, before doing anything. We work in the **orchestrator/worker pattern** (`_agents/orchestration.md`): in the main checkout you're the orchestrator; in a `godot-<stream>` worktree you're a worker, so also read `_agents/workstreams.md` and your brief in `_agents/streams/`.
2. Every workflow is a Makefile target (`make help`). If `.tools/` is missing, run `make bootstrap`. Heavy targets run on builder0: `make remote T=check` (`_agents/remote_builds.md`).
3. Don't call a task done without the relevant checks in `_agents/verification.md`, and look at the screenshots you produce.
4. Before your context is cleared, update `HANDOFF.md` (or, on a workstream branch, your brief's **Status** section) and any `_agents/` doc your work made stale.
5. Stay inside the paths your stream owns; contract changes go through `_agents/workstreams.md`.
