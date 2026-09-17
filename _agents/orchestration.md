# The orchestrator/worker pattern

> **The reusable process for building this game with parallel Claude agents.** The lead asked for it to be written
> down (2026-09-15): *"this pattern that we have should be documented as an orchestrator/worker pattern that we want
> to re-use. In the future when I have a fresh agent, I don't want to have to re-explain this iterative pattern."*
> Proven over rounds 1–2 (2026-09-14/15). The *current* round's streams, owners, and contracts are in
> [workstreams.md](workstreams.md); this file is how every round works.

## The roles

| Role | Who | Where | Job |
|---|---|---|---|
| **Lead** | the human | anywhere | Sets direction, answers lead gates (concept art, text reviews, spending, design pillars), playtests, pushes `main` |
| **Orchestrator** | one Claude session | the main checkout `~/projects/godot`, on `main` | Turns the lead's direction into docs and a round of streams; integrates branches; fixes integration bugs; keeps docs true |
| **Worker** | one Claude session per stream | a git worktree `~/projects/godot-<stream>`, branch `stream/<stream>` | Works through its brief autonomously, tests, commits, reports in its brief's Status |

**If you are a fresh agent:** you're the orchestrator when you run in `~/projects/godot` on `main` and the lead talks
to you about direction or integration. You're a worker when your folder is `godot-<stream>`. Workers read *The worker
contract* below; orchestrators read everything.

## The round lifecycle

```
 1 LISTEN      lead feedback + direction  ─▶  ask only decisions that change the plan (AskUserQuestion, ≤4)
 2 RECORD      decisions into game_design.md / vision.md / art_direction.md, with the lead's words quoted
 3 SPLIT       streams by independent problem; path ownership; contracts for every overlap
 4 BRIEF       one brief per stream in streams/<stream>.md (the lead's words, backlog in order, verify, don't touch)
 5 LAUNCH      commit docs on main → make worktree per stream → give the lead the /goal kickoff prompt
 6 RUN         workers run unattended; orchestrator relays lead gates, answers design questions, keeps notes
 7 INTEGRATE   merge finished branches into main in dependency order, make check after each, fix what breaks
 8 CLOSE       preserve ignored assets → remove worktrees → archive briefs to streams/archive/roundN → HANDOFF
 9 REPEAT      the lead playtests and gives feedback → back to 1
```

### 1–2. Listen and record
- The lead gives broad direction and feedback (often one long message). **Quote the lead's words** into the docs; they
  are the source of truth a worker can't ask about later.
- Ask only questions whose answers change the split or the plan; recommend an option. Broad strokes are Claude's call
  (memory: *broad strokes, Claude decides*).
- Every idea discussed, even if not scheduled, goes into a doc (usually `game_design.md` or `roadmap.md`). Nothing
  lives only in chat: the conversation will be compacted.

### 3. Split into streams
- **One independent problem per stream**, sized so an agent can work for many hours. 5–6 streams fit this laptop
  (each Claude session is ~300–400 MB RAM); heavy builds go to builder0 ([remote_builds.md](remote_builds.md)).
- **Path ownership:** every path has exactly one owner; shared files (`project.godot`, `Makefile`, `mk/core.mk`,
  `game/main.gd`) get minimal additive edits listed in merge notes.
- **Contracts for every overlap** (data shapes, signals, APIs) written *before* launch in workstreams.md, so all
  streams start at once against the contract, with stubs in their own paths until the real thing merges.
- Prefer splits with few overlaps. Where a stream depends on another's output, define a **checkpoint** (the
  orchestrator merges that item to `main` early and tells the others to `git merge main`).
- Keep one stream that can run in total isolation when possible (e.g. the announcer against fixture data).

### 4. Write the briefs
A brief (`_agents/streams/<stream>.md`) is the worker's whole world. Template:

```markdown
# Stream: <name> (<one-line scope>)
> Read <design docs>. You own <paths>. <shared contract notes>.
## The lead's direction (<date>)          ← verbatim quotes
## Where things stand                     ← what exists, known problems, measured numbers
## Backlog (in order)                     ← X1, X2…: each with acceptance notes and tests to write first
## How to verify                          ← make targets, screenshots to look at, measurements
## Don't touch                            ← other streams' paths
## Waiting on the lead                    ← lead gates in progress
## Status                                 ← the worker keeps this current (its report)
```
Backlogs are deliberately longer than one session; stretch items at the end. Put every lead direction in the brief:
**the kickoff prompt stays one generic line** (memory: *agent prompts live in docs*).

### 5. Launch
```bash
cd ~/projects/godot && make check                  # or: make remote T=check  (green baseline first)
git add -A _agents HANDOFF.md && git commit
make worktree STREAM=<name> OFFSET=<1-9>           # once per stream: folder, branch, ports, user dir
make worktrees
```
Give the lead the kickoff prompt from `HANDOFF.md` (the same text for every stream; the stream comes from the folder).
Worktrees must be created **after** the docs commit, or workers start without the latest HANDOFF (a round-1 mistake).

### 6. While the round runs (orchestrator)
- Relay lead gates: the art review page, text reviews. Record the lead's answers in the stream's brief.
- Design conversations with the lead continue here; record every decision in docs on `main` and in HANDOFF.
  Don't push new scope into running workers' briefs mid-run unless it's cheap and theirs; queue it for the next round.
- **Checkpoints:** when a foundation item lands, merge it to `main`, run `make remote T=check`, and tell workers to
  `git merge main` (SendMessage to each worker session; ListAgents shows them as `godot-<stream>-…`). Relay every
  cross-stream request you find in a worker's Status or messages to the stream that owns the work.
- Also skim each worker's Status now and then (`git show stream/<s>:_agents/streams/<s>.md`) for announcements that
  weren't messaged.
- Watch progress without disturbing workers: `git -C ../godot-<s> log --oneline main..HEAD`, `status --short`.

### 7. Integrate

**Before each merge, check the branch for infrastructure it shouldn't carry:** `git ls-tree -r --name-only stream/<s> |
grep -E '^\.tools$'` (a worktree's toolchain symlink; two of five streams committed it on one night in round 4, and
merging it replaced the real toolchain with a link to itself and deleted the pinned Godot), and skim
`git diff --stat main...stream/<s>` for paths the stream doesn't own.

Order: foundations first (rules/combat before ai before ui before art), or least-coupled first when nothing depends.
For each branch:
```bash
git show stream/<s>:_agents/streams/<s>.md | less      # read its report and merge notes first
git merge --no-ff stream/<s> -m "Merge stream/<s>: <summary>"
# resolve conflicts: the owner's version wins in its paths; combine docs
make remote T=check                                     # or make check; fix integration bugs on main
```
- Integration bugs are the orchestrator's: tests written against the old world (e.g. "every vehicle is a tank"),
  NaNs on first frames, float thresholds. Fix, add a regression test, **mutation-check it** (it must fail without
  the fix), commit with the reason.
- The **sim baseline** changes only on purpose: `make remote T=sim-baseline-record` (twice, to confirm it repeats), copy
  `build/sim_state_hash.txt` over `tests/baselines/`, and say why in the commit. Hashes are per glibc version.
- Merging several independent branches back to back and checking once at the end is fine (the lead agreed); each
  merge is its own commit, so a failure can be bisected.
- A worker may keep committing after its first merge: check `git log main..stream/<s>` before closing.

### 8. Close the round
1. Every `stream/*` branch is an ancestor of `main` (`git merge-base --is-ancestor`), and `make check` is green.
2. **Preserve git-ignored work** before removing a worktree: raw Meshy downloads, announcer masters, CC0 sources —
   anything under `assets/` a worker generated (`rsync -a` into the main checkout; check `git status --ignored` in each
   worktree). The 30-minute backup timer only watches the main checkout, so until you copy it in, a worktree's payload
   exists **once** ([backups.md](backups.md)).
3. `make worktree-remove STREAM=<s>`, then delete merged branches (`git branch -D` after the ancestor check; `-d`
   refuses when the remote branch is behind).
4. Archive briefs: `git mv _agents/streams/<s>.md _agents/streams/archive/roundN/`, add an archive banner, fix links
   (code comments reference briefs too: grep the whole repo).
5. Fold streams' requests into docs: contract additions into workstreams.md, the lead's answers into game_design.md.
6. Update `HANDOFF.md` (current state, open questions, follow-ups) and `roadmap.md`. The lead pushes.

## The worker contract

The kickoff prompt is one line; this section is the rest.

1. **Orient:** confirm `pwd` is `godot-<stream>` and `git branch --show-current` is `stream/<stream>` (stop if they
   disagree). Read `CLAUDE.md` → `HANDOFF.md` → [orientation.md](orientation.md) → [game_design.md](game_design.md)
   → [workstreams.md](workstreams.md) → your brief. Start from a green `make remote T=check`.
2. **Plan** the brief's backlog into an ordered list in its Status (smallest foundation first). Where the brief leaves a
   choice, decide like a good game designer/engineer and record a one-line reason.
3. **Loop per item:** a failing test or scenario first → build → `make remote T=check` → **smoke test like a player**
   (screenshots at desktop and phone aspect and look at them; scripted input; match series for gameplay) → fix what
   felt wrong → commit to your branch with what and why → update Status.
4. **Never wait for an answer.** Questions go under *Questions for the lead* in Status; take the most reversible
   reasonable option and keep going. Lead gates (below) stop only that item.
5. **Need another stream's code?** Don't edit their paths. Build an adapter or stub in yours, write the request under
   *Requests to other streams*, continue.
5a. **Tell the orchestrator directly** for anything someone else must act on: a checkpoint is ready, a request to another
   stream, a bug in shared code or on `main`. Write it in Status *and* send a short message to the orchestrator session
   (Claude Code's SendMessage; the orchestrator's session runs in `~/projects/godot`, find it with ListAgents). Status
   alone gets missed (round 3: combat's CP2 announcement sat unread in its Status).
6. **Merge `main` only at announced checkpoints.** Commit after every green step. You may
   `git push -u origin stream/<stream>`. Never push `main`, never force-push, never touch another worktree.
7. **Shared machine:** heavy runs go through `tools/slot.sh` automatically (locally) or to builder0
   (`make remote`). At most one long-running background process of yours; stop it by PID; never `pkill -f`; never kill
   processes you didn't start. Background commands can be killed by the session's memory guard: detach long runs with
   `setsid nohup … > log 2>&1 &` and poll the log.
8. **No new money, accounts, or secrets** beyond what your brief allows. Never commit keys.
9. **Time-box:** ~90 minutes without progress on one item → write down what you learned, move on.
10. **Done** = every backlog item complete, waiting on a lead gate, or written up as blocked; `make check` green on
    your last commit; Status holds the report: done (with measurements), decisions, questions for the lead, requests
    to other streams, known issues, what to playtest (exact commands), next steps, merge notes (shared-file edits).

## Lead gates (standing)

1. **Paid generation:** Meshy concept images go on the review page before any image-to-3D; ElevenLabs audio is
   generated only after the lead approves the text. Log every paid request in the stream's ledger. No hard caps;
   don't be wasteful.
2. **Design pillars** in game_design.md change only with the lead.
3. **Money, accounts, destructive actions** outside your worktree.

## The kickoff prompt (copy/paste; the same for every stream)

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your
> working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and
> `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an
> answer except at lead gates; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md,
> `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`,
> `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch
> items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and
> look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item
> is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the
> Status holds your report.

## Lessons (add to this list every round)

1. Create worktrees **after** committing the round's docs (round 1: workers started without the new HANDOFF).
2. A stream that depends on another's foundation needs an explicit checkpoint, or it builds against stubs all round
   (round 2: checkpoint 1 was never called; integration adapted army's stub and ai's scenarios at the end).
3. Tests that encode today's content ("all tanks", "5 identical units") break when another stream changes content:
   derive expectations from the data.
4. Flaky under load ≠ fine: find the cause (round 2: a float threshold on a clock summed from frame deltas).
5. Memory guard: this laptop kills background tasks under pressure; detach long runs and poll their logs, or use
   builder0.
6. Before removing worktrees, rescue git-ignored paid assets (round 2: 397 MB of raw Meshy downloads).
7. `grep -q DONE` matched Godot's own `[ DONE ]` progress lines: use unique end markers (`CHECK_EXIT=`).
8. The same Godot binary simulates differently on machines with different glibc (libm trig): baseline hashes are keyed
   by glibc version, builder0 canonical (round 3 setup).
9. Infra fixes a worker finds (round 3: remote screenshots after the first frame were stale on builder0) go to `main`
   right away as their own commit, then every stream is told to `git merge main`; don't wait for a checkpoint.
10. Read every test result line before committing a fix, especially after a mutation check: the orchestrator once
    restored a guard, misread `40 passed, 1 failed` as green, and broke `main` for all six streams (a test assumed
    `Geometry2D.triangulate_polygon` rejects a collinear triangle; it doesn't). Probe engine behavior with a tiny
    `--script` before encoding an assumption in a test.
11. Workers announced checkpoints only in their Status, and one sat unmerged: workers now message the orchestrator, and
    the orchestrator skims Status files too.
12. **Relay lead gates the day they open.** Round 3's three faction review pages sat unseen for a day because the
    orchestrator never sent the lead their links; the assets stream idled on approvals it had already earned. When a
    worker lists something under *Waiting on the lead*, put the links in front of the lead in your next message.
13. **A make target and the code it calls land in the same commit** when the target is in `check`. Round 4: a
    half-finished `announcer-variance` entered `announcer-check` before its CLI flags existed and broke `main` for five
    streams. The orchestrator's fix is to cut the target out of `check` on `main` immediately (one line, with a comment),
    not to wait for the owner.
14. **"Passes in isolation, fails in a check" is not proof of a load problem.** Round 3 and 4 both blamed a loaded
    builder0 for a short audio mixdown; the real cause was `apad` after `amix` not padding on ffmpeg 6.1.1. Chase the
    tool's behavior before blaming the machine.
15. Killing a local `make remote` leaves the build running on builder0, and the next run rsyncs `--delete` under it
    (remote_builds.md). Stop the remote process first.
16. `git add -A` is how unreviewed files get committed: in round 4 it swept a half-finished make target into `check`
    and a worktree's `.tools` symlink into a merge, both from the same session. Stage paths you looked at.
17. **A behaviour that looks under-written is usually being starved by a rule above it.** Round 4, three times in two
    streams: the announcer's Veteran seemed short of material and was being silenced by a priority rule; doctrine's
    react-to-contact restarted every update, so no maneuver after it ever finished; and its encircle and bait drills
    stole the element from each other every tick, so neither completed once. Each time the obvious fix was "write more
    of it", and the real fix was one line of precedence. Before adding content to a weak or quiet behaviour, log what
    *selected* it each tick and check whether something upstream keeps pre-empting it.
18. **Anything expensive to change after the fact should describe, not evaluate.** A recorded announcer line outlives
    the measurement that justified it: it can't be edited, only re-recorded for credits and re-shipped, so a claim about
    how the game works is a promise the build has to keep. Round 4 caught two pending lines asserting that bounding
    overwatch keeps a crew alive — the opposite of what it measured, and resting on a mechanic another stream was still
    landing. The working arrangement that saved it: the measuring stream sends numbers **marked stable or resting on an
    unfinished mechanic**, and only stable ones get recorded.
19. **A human is a check, and for subjective quality the only one that counts.** Round 4's announcer shipped a version
    that passed every automated check — transcription, levels, durations all clean — and was obviously wrong to the
    first person who listened: stitched words sound pasted, which no metric measured. Put a cheap sample in front of
    the lead *before* the expensive run, not after. The second pilot cost 1,875 credits and saved the 113k run from
    being wrong the same way.
20. **Measure an optimisation against behaviour, not just the clock.** Round 4: two cost cuts in the AI passed every
    test at the time and quietly removed most of a behaviour — a 6-tick check interval saved 370 µs and cost a unit
    most of its chances to notice a wall of bullets while there was still room to go round (3 ticks turned out to be
    both better behaved *and* cheaper than 1). The scenario that would have caught it was written after the cut.
21. Unwatched scope creep: when the lead adds ideas mid-round, record them in docs and queue them; don't retarget
   running workers unless the change is small and inside their paths.
22. **The same measurement repeated across variants is not more samples.** Round 5: arena ran 18 seeds on each of four
    arenas and read 72 results, but the seeded armies depend on seed and team, not on the arena — so it was 18 army
    pairings measured four times, and the 13/18 lean it found was p ≈ 0.05 on its own. The fix for a suspected bias is
    never more repetitions; it is a **control that cancels the suspected cause** (here: swap the armies between teams
    and pair the runs, or mirror them outright). Before running a bigger series, name the thing that varies between
    samples and check it actually varies.
23. **A feature behind a flag the default path never passes has not shipped.** Round 5: the lead played several
    matches and reported *"it's just these 2 masses shooting at each other"*. The cause was that the skirmish CPU ran
    individual brains only — elements, formations and battle drills, the entire output of round 4, sat behind
    `--element-cpu`, which `make skirmish` never passed and the match runner never passed at all. Doctrine wins 52-28
    when it is switched on. Every test passed the whole time, because the tests passed the flag. So when a round ships
    a behaviour, closing it includes **playing the default path and confirming the behaviour is visible there** — and
    any series used for balance must run the configuration players actually get, or it measures a game nobody plays.
24. **Check how a thing is built before asking someone to investigate a failure it cannot have.** Round 5: the
    orchestrator told arena to check whether Jolt made container stacks settle or drift; they are StaticBody3D boxes
    drawn by a MultiMesh and cannot move under any engine. Half a minute of reading would have produced the right
    request instead (vehicle contact against them). A confident wrong instruction costs a worker more than silence.
