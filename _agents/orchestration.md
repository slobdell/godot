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
git merge --no-ff <the commit its check went green on> -m "Merge stream/<s>: <summary>"
# NOT the branch tip unless the worker said the tip is the green commit: a tip that has moved since the
# check is unverified, and a worker fixing their own breakage can leave a broken pair in between.
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
10. **Every number carries its commit and its machine.** "The tick costs 6.7 ms" is not a fact; "6.7 ms at
    `d781ed05`, builder0, `sim-profile` 31 v 27" is. Round 5 lost hours to two streams comparing builder0 numbers
    with laptop numbers (the laptop is ~2.75x slower for identical work), to a comparison of two runs that were
    different fights, and to an 18-shell sample read as a behaviour regression. State the commit, the machine, the
    workload and the sample size, every time — the stream that suggested this rule caught both of its own wrong
    numbers by re-running, and neither would have survived the rule in the first place.
11. **Say which commit is green.** When you report a branch ready, name the hash the check actually ran on
    (`this commit is green, merge here: <sha>`), not "the branch". A tip that has moved since the check is unverified,
    and round 5 put a broken pair on `main` exactly that way.
12. **Done** = every backlog item complete, waiting on a lead gate, or written up as blocked; `make check` green on
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
    *The same trap caught the fix an hour later:* the orchestrator approved switching doctrine on by default on a
    52-28 result measured in five-vehicle mirrors with no control point. Re-measured in the setup `make skirmish`
    actually plays — faction armies, 30 a side, control point on — brains-only beat doctrine 32-16, and the flip was
    withdrawn. Before acting on any number, ask in which configuration it was taken, and whether that is the one
    players get.
24. **Check how a thing is built before asking someone to investigate a failure it cannot have.** Round 5: the
    orchestrator told arena to check whether Jolt made container stacks settle or drift; they are StaticBody3D boxes
    drawn by a MultiMesh and cannot move under any engine. Half a minute of reading would have produced the right
    request instead (vehicle contact against them). A confident wrong instruction costs a worker more than silence.
25. **A per-behaviour outcome ratio measures selection, not causation.** Round 5: `far_ambush` showed a 0.16-0.26
    exchange over 44 deaths, and the orchestrator told ai to cut it. Removing it from the army changed nothing
    (55-65, and 20-20 head to head against standard doctrine) — the drill was being *selected* in situations that
    were already lost. `break_contact`, cut on the same kind of evidence, really was the problem: without it the army
    went 91-29 and won on every arena. The difference was only visible because ai measured the army **with and
    without** rather than reading the per-drill column. Attribute a cost to a behaviour only by removing it.
26. **A relayed number becomes a fact: ask the sample size before passing it on.** Round 5: a stream reported dodging
    falling from 17% to 1% after the 30 Hz change, and the orchestrator relayed it to the lead within minutes as a
    behaviour cost of his own decision. It was 18 shells — 5.5 percentage points per shell — and the real finding,
    found an hour later, was that dodging had **never fired at either tick rate** (254 of 254 candidate directions
    scored "would still be hit"). The orchestrator's job in a relay is to ask *how many samples, over what, against
    what control* before a stream's number reaches the lead, because the lead cannot ask and will act on it.
27. **When a fix does not take, check the fix reached the build before theorising.** Round 5: three straight
    "fixes" for a black rectangle under every vehicle failed, because a `sed` edit silently matched nothing and the
    screenshot after it was trusted. A failed edit and a wrong diagnosis look identical from the outside. Verify the
    edit landed (and the build rebuilt) before reasoning about the renderer, the engine or the data.
28. **A piped command reports the pipe's exit code, not the command's.** Round 5: the orchestrator ran
    `make remote T=check 2>&1 | tail -20` and read the 0 that came back as "main is green". The exit code was
    `tail`'s; the remote build had failed, and main sat red for an hour until a worker ran the suite locally and said
    so. The signal to read is the wrapper's own line, `>> remote: make check exited <N>`, and the pass/fail summary
    from the runner -- never the shell's status through a pipe, and never the harness's "[exited with code 0]", which
    reports the wrapper, not the build. Run heavy checks unpiped, then grep the saved output.
29. **Merge at the commit whose own check went green, not at the branch tip.** Round 5: a worker's `Merge main`
    resolved a conflict wrongly, their own check caught it, and they fixed it in the next commit — but the
    orchestrator merged the branch *between those two commits*, so main got the broken pair. The branch tip is not a
    verified state; only the commit a check ran on is. **Workers: say "this commit is green, merge here" with the
    hash** rather than leaving the orchestrator to infer it, especially when the tip has moved since you reported.
    **Orchestrators: merge that hash**, and if the tip is ahead of it, either wait for its check or read every commit
    in between.
30. **Changing the tick rate re-times everything counted in ticks, frames or interpolation — three instances in one
    day, and *six* by the time round 6 went looking.** Round 5's 30 Hz move: (a) K1's response contract said "within 3 ticks", which silently meant 50 ms and
    would have meant 100 ms — a guarantee about what a player's hand feels belongs in milliseconds; (b) a brain's
    think cadence was `TICK_RATE * 3 / 20`, which integer-divided to 12% *more* thinking at 30 Hz — rates must be
    booked in Hz with the leftover fraction carried, not in whole ticks; (c) physics interpolation arrived with the
    tick change, so a test that assigned `global_position` read the *drawn* (interpolated) position and aimed a
    camera 79% of the way along the teleport — every teleport needs `reset_physics_interpolation()`. The
    generalisation: **before changing a rate, grep for every constant and assertion expressed in ticks or frames, and
    ask what each one means in seconds at both rates.** Audio, which had already converted everything to seconds,
    needed no changes at all.
    **Round 6 found three more, all surviving the round-5 sweep, and two of them were lying to a reader rather than
    breaking a test:** (d) a test awaited `SECONDS * 60` frames, so a "12 s" assertion ran 24 s with a drift threshold
    — a test sitting at twice its intended duration; (e) the *dither metric itself* divided by `unit_ticks / 3600.0`,
    so every dither rate ever reported was **double** the real one, and the behaviour it was gating had never actually
    breached its bar; (f) `game/agent/discovery_bridge.gd` reported `seconds` and `age_seconds` to the discovery agent
    as `tick / 60`, so **every time the LLM saw was half the real elapsed time**. The lesson on top of the lesson:
    a rate bug in an *instrument* or a *report* does not fail anything — it silently changes what everyone downstream
    believes, and it outlives the sweep that was supposed to catch it. When you change a rate, grep the things that
    **describe** the simulation as carefully as the things that run it.
31. **Saved measurements need provenance, written from the note and not from memory.** Round 5's close: three
    streams had hours of match results and perf baselines living only inside a worktree's git-ignored `build/`,
    which the round's own cleanup would have deleted — leaving published conclusions with no evidence behind
    them. Rescue compact extracts into `_agents/streams/references/`, cite them from the document that quotes
    the numbers, and give each directory a README with one row per file: what it is, what commit and machine it
    was taken on, the headline number, and the caveat that makes it misleading if missed. **Write each row from
    the contemporaneous note, not from recollection** — that is the step that caught the errors: one stream was
    about to mislabel a baseline's conditions, another found a score it had reported was really its record in a
    different matchup. Better still, make the tool record its own conditions, so the next file cannot lose them.
32. **"It's missing" usually means "it doesn't reach me": survey the code before briefing a build.** Round 6's
    planning: the lead reported the ambient crowd in the stands as *"non-existent"*. It had shipped four days
    earlier — a MultiMesh of up to 4,000 figures seated from the stands' rows, reacting to kills, with a murmur and
    roar bed under it. A brief that said "build a crowd" would have built a second one. The brief says "find out what
    hides it, with a screenshot, before changing anything". The same survey turned three other complaints into
    one-line diagnoses: camera pitch welded to zoom (so framing anything *becomes* the bird's-eye view he disliked),
    a unit declaring its order complete from 12 m away after 3 s of no progress (so a jammed horde looks like it
    decided to stop), and firing with no acquisition step at all (so seeing is shooting). **Spend an hour reading the
    code the lead is complaining about before you write the brief** — the difference between a symptom and a cause is
    the difference between a round that lands and a round that adds.
33. **The same abstraction built three times is worse than not building it.** Round 6's survey found formation slots
    implemented in `group_formation.gd`, in `formations.gd` + `squad.gd`, and in `tactics_formation.gd` — three shape
    tables, three assignment rules, three pacing rules, each reached by a different order verb, none owned. The lead's
    verdict was *"I don't think we have any coherent formations working"*, and he was right for a reason nobody would
    guess from the code: each one works. This is trip-up 60 (two streams, one concept) grown over four rounds. When a
    round splits work by discipline, **name the concept each stream owns, not just the paths** — and when an item's
    first step is "collapse these into one", say so in the brief, because a worker will otherwise extend whichever
    copy it finds first.
34. **A measurement's own bugs reach the next stream as facts about the game.** Round 6, day one: arena built nav's
    acceptance harness and caught two defects in it before relaying anything. (a) `off_navmesh` was computed as a 3D
    distance, so a hull centre sitting 0.7 m *above* the mesh was charged to every unit — it reported **17 of 60 units
    "off the map"** where the flat x/z distance reports **0**, and that was one relay away from being filed as a
    navigation bug for another stream to hunt. (b) The target read a bare `UNITS`, and `mk/ai.mk` sets `UNITS ?= 60`
    globally, so a run whose help text *and* output both said "30 units" was silently running 60 — cf. trip-up 67,
    where GNU make's own `WINDOW = 2` did the same thing. The general rules: **a new instrument gets checked against a
    case whose answer you already know before its first number leaves the stream**, and **never give a shared
    Makefile a bare, guessable variable name** — prefix it (`NAV_UNITS`, not `UNITS`) and print what it resolved to.
35. **Lesson 23 inverted: an *exception* the default path always passes is as invisible as a feature behind a flag it
    never passes.** Round 6, combat building CP4: fire discipline was written with an "unless explicitly ordered to
    engage" escape, faithful to the brief. But `TankBrain`'s ENGAGE state issues a `target` weapon order *every tick*,
    so that one exception exempted **every CPU unit in the game**, and the whole engagement envelope would have
    shipped doing nothing — while every rule test passed, because the tests exercised the rule and not the caller.
    The fix was to make the override an explicit `"long_shot": true` that nothing sets by default. **When you write an
    exception, go and count who takes it in the default configuration**, exactly as you would go and check who passes
    a new flag. The general form of lessons 23 and 35 together: a behaviour's reach is decided by the callers, not by
    the code you are looking at, so read the callers before believing either a feature or an exemption is rare.
    **The instruction, in the stream's own sharpening of it: when you add an exception to a rule, grep for every
    caller that would take it *before* you write the test that proves the rule works.** The passing test was written
    first and told them nothing — it exercised the rule while the callers decided the outcome.
36. **A test that shares a global with its neighbours and passes may be testing its neighbour.** Round 6, arena: the
    maze's navigation tests passed 5/5 run alone and failed run after `test_arena_layouts`, because `Pathing.is_ready()`
    answers only *"does the world's navigation map have polygons"* — and the previous test's arena is freed a frame or
    two before `NavigationServer3D` drops its regions. So it returned true immediately, against the **old** map, and
    every path was a straight line through the new arena's walls. The fix is to wait for geometry only *this* layout
    has (a point inside one of its own collision boxes must be off the navmesh); waiting for polygons is not waiting
    for *this arena's* polygons.
    **The part that is not about navmeshes:** the same flaw sat in `test_arena_kit`'s all-layouts connectivity test,
    the one asserting that every shipped layout connects both bases and the centre. It had **never failed** — because
    it had been proving the *previous* arena was connected, once per layout. It was only caught because a maze has a
    **known wrong answer** (a straight line base to base, a dead end with no walls) where a normal arena's wrong answer
    looks like a right one. So: when a test depends on a global the engine owns (a navigation map, a physics space, a
    singleton, an import cache), **assert on something only this case can produce**, and treat a suite-order-dependent
    pass as a failure. A test that has never failed in a suite that changes its inputs deserves suspicion, not trust —
    design at least one case whose wrong answer is obviously wrong.
37. **A constant nobody derived can own an entire finding.** Round 6, arena: its flanking analysis used a hard-coded
    110 m "watcher range", and on that number a flank cost a **1.8–2.1× detour** on six of seven arenas — written up
    as "cover is priced out of reach". combat then derived the real figure from the rosters
    (`min(effective_range, sight_radius)`, median **45 m**), and the same geometry and the same code priced the same
    flanks at **1.0–1.1×**. Same maps, opposite conclusion, and the whole result had lived in one number that had been
    guessed once and never questioned. arena **rewrote the section rather than appending to it**, because the old
    table would have been quoted. Two rules: **a magic number inside a metric is a finding waiting to be wrong** — ask
    which stream owns the quantity and get it derived from the data — and when a correction inverts a published
    conclusion, replace the text, never append to it.
38. **Baseline the suite before you attribute its failures to your change — especially a suite that is not in
    `make check`.** Round 6, combat landing CP4: `make ai-scenarios` came back 37 passed, 9 failed. The tempting
    reading is nine regressions. combat instead ran the same suite on a **pristine tree first** and found the honest
    split: **5 failures pre-existed**, **1 was fixed** by its change, and **4 were genuinely new**. Without that
    baseline it would have spent a day on five failures that were never its own, or — worse — reported nine
    regressions to the orchestrator and had another stream spend the day. The reason the baseline was missing in the
    first place is the part to fix: **`ai-scenarios` is not in `make check`**, so nobody had a known-good number for
    it, and a suite nobody baselines drifts until the next person to touch it inherits the whole backlog. Either put
    a behavioural suite in the gate, or record its expected pass count somewhere a stream will find it.
39. **A rule and a heuristic that reason about the same quantity in different units will deadlock.** Round 6: N5 made
    firing depend on *effective* range while `TankBrain._combat_move()` still decided where to stand from
    `weapon["range"]` — full reach. The outranging branch therefore parked a tank **61 m** from a scout it could not
    shoot at, for the whole 45 s: 0 shots, 0 metres, never arrived, with the brain printing the cause every tick
    (`opt=ENGAGE why="outranging it" move={"type":"stop"}`). The fix was two tokens, and the result was *faster* than
    before the rule existed (14.9 s against 20.8 s) because the unit stopped trying to snipe. The general form:
    **when you narrow a quantity, grep for every consumer of the old one** — a rule about "may I fire" and a
    heuristic about "where should I stand" have to share a definition or the unit freezes between them. Note this is
    lesson 17 seen from the other side: the starved behaviour and the starving rule were written by different streams
    a round apart, which is exactly when nobody notices.
40. **A repeated *load* can masquerade as per-instance *work* when something evicts the cache between instances.**
    Round 6, the lead's "big lag between pressing Fight and the game loading": control profiled it honestly and
    concluded per-instance work — the first vehicle of a type cost ~95 ms and every later one ~63 ms, and "if it were
    loading, later instances would be near-free" is exactly the right inference from that shape. It was still wrong.
    feel traced the nodes and found a **70–90 ms gap immediately before the hull node** on every new-faction vehicle:
    each one's hull `VisualSlot` first fills the *default* slot (the Condemned dozer), then swaps in its own art; the
    dozer instance is freed, nothing else references its `.glb`, the engine unloads it, and the next vehicle re-reads
    it from disk. Condemned vehicles stayed at 2 ms precisely because their own live dozers kept the model cached —
    the control group was sitting in the data all along. One strong reference per slot scene in `GameTheme.scene()`
    took **106–128 ms per vehicle to 0.9**. The instruction: **"later instances are not free" narrows the cause to
    per-instance work *or* a cache being evicted between them** — and the way to tell them apart is a node/resource
    trace showing *where the time sits*, not a per-call profile showing how much. Look for the cost in the gaps
    between the functions you suspect, and look for the population that is unexpectedly cheap.
41. **"The asymmetry is obviously wrong" is a hypothesis, not a result — and a negative result is worth relaying.**
    Round 6, hunting the dither that CP4 exposed: combat found a real structural leak of its own making. It had
    exempted `suppress` orders from fire discipline, which made suppressive fire **strictly more available than
    engaging** beyond the band — a crew that could not legally shoot *at* a contact at 48 m could still put rounds on
    the ground under it, and the utility scorer could see exactly that. It watched a unit flip
    `ENGAGE → SUPPRESS → ENGAGE` in 1.4 s at 47–50 m, right at the band edge. The mechanism was visible in the log,
    the reasoning was sound, and the write-up's line — *"an exemption only the optimiser can see is not a design, it
    is a leak"* — is still true. **Closing it moved the dither not at all** (17.7 / 15.6 per minute, identical) **and
    broke two more behaviours** (9 scenario failures to 11). Reverted.
    Two instructions. **(a)** This is lesson 20 again from a new angle: measure an optimisation *or a correctness fix*
    against behaviour, not against the mechanism you can see. A leak you can explain is not thereby the cause of the
    symptom next to it. **(b) Tell the orchestrator your negative results, and the orchestrator must relay them.** The
    stream that owned the dither would otherwise have spent an afternoon rediscovering the same dead end, and the
    finding that the real driver is upstream in option scoring **and is not the suppress exemption** is worth nearly
    as much as a fix would have been.
42. **Do not fix an un-baselined suite by adding it to the gate.** Round 6: `ai-scenarios` had drifted because nothing
    baselined it (lesson 38), and the obvious fix — put it in `make check` — would have turned the gate **red for six
    streams** over its 6 pre-existing failures, which nobody had triaged and which belong to several owners. That is
    how a suite gets excluded from a gate in the first place. The honest sequence: **record the expected pass count in
    a committed baseline file** (the way `tests/baselines/sim_state_hash.txt` works), fail only on a *change* in that
    count, and let each owner decide whether their failure is a bug or a stale expectation. Then tighten.
43. **Adding a member to a shared list is not an additive change: grep every consumer of the list.** Round 6, arena,
    twice in one day, and both failures were the same bug wearing different clothes.
    **(a) The lucky kind, which failed loudly.** `arenas/` grew a *test fixture* (the maze), and the announcer's
    `test_arena_names.py` asserts that every layout in `arenas/` has a spoken name **and a recorded clip**. Adding one
    would have been wrong three ways — the booth should not name a map nobody plays, and the recording is paid
    ElevenLabs time behind a lead gate. The right fix was to give the new member a *kind*: `"fixture": true`, with
    `Arena.is_fixture()` and `Arena.shipping_layout_names()` for anything that offers arenas to a human.
    **(b) The dangerous kind, which had been failing silently for an unknown length of time.** The same list grew an
    arena whose *wrong* answer is visible — a maze where a straight-line path base-to-base is obviously bogus — and
    that is what exposed `Pathing.is_ready()` answering for the *previous* arena (lesson 36). The connectivity test
    that claims every layout connects had never failed because it had never been testing what it claimed.
    So: when you add to a list other code iterates, **the question is not "does my member work" but "what does every
    consumer assume about members"** — and if your member is of a genuinely new kind, say so in the data rather than
    making it pass as the old kind.
    **Corollary, learned on a 25-minute build queue:** *run the full check before claiming green, not the tests your
    change touches.* The thing that broke was a different stream's check, and no amount of testing the changed file
    would have found it.
44. **A make variable set in any `mk/*.mk` is global: name a stream's knobs after the target that owns them.** Round 6,
    combat: `mk/ai.mk` sets `VARIANTS ?= r1,a4,a6` — three *brain-variant names* — and `mk/match.mk` used `VARIANTS`
    for a *path to a JSON file*. Make has one namespace, so `$(if $(VARIANTS),--variants $(VARIANTS))` was **always
    true and always wrong**: `FileNotFoundError: 'r1,a4,a6'`. Two things make this worse than a crash:
    - **It broke the exact command our own reference file tells you to run.** `streams/references/combat/README.md`
      documents a baseline as reproducible with `make engagement PAIRS=… SEEDS=3 TIME=240`, and that command cannot
      have worked since the `VARIANTS` default landed. **A "reproduce with" line nobody re-runs is a claim, not a
      reproduction** — the soft spot in lesson 31: we made the tools record their conditions, and nothing checks that
      the recipe still runs.
    - **The sibling target took it silently.** `matchup-search` passes `--variants` as a *required* argument, so it
      would have searched three brain names instead of the file you meant and produced a plausible result for the
      wrong question. This is trip-up 60 (two streams, one concept) in a namespace nobody thinks of as a namespace,
      and it had already bitten once before — `UNITS ?= 60` in `mk/ai.mk` silently made an arena run labelled
      "30 units" run 60 (lesson 34).

    **The audit, run on `main` 2026-09-18** (`^[A-Z_]*\s*\?=` defaults against `$(VAR)` uses across files): 28 knobs
    cross a file boundary, and almost all are the root `Makefile` deliberately sharing `PYTHON`, `JOBS`, ports, `BOTS`
    and so on — that is fine. **The dangerous shape is a default in one *stream's* file consumed by a different
    stream's file**, and there are four:
    | Knob | Defaulted in | Also used in | How it failed | Status |
    |---|---|---|---|---|
    | `VARIANTS` | `ai.mk` (squad) | `match.mk` (combat) | **loudly** — `FileNotFoundError: 'r1,a4,a6'` | fixed → `VARIANT_FILE` |
    | `UNITS` | `ai.mk` (squad) | `match.mk` (combat) | **silently** — `$(if $(UNITS),--units $(UNITS))` always fired, so *every* `matchup-search` run passed `--units 60` whatever the caller asked, and said nothing | fixed → `SEARCH_UNITS` |
    | `ARENAS` | `tactics.mk` (squad) | `arena.mk` (arena) | not established | fixed → `TACTICS_ARENAS` |
    | `SECONDS` | `net.mk` (paused) | `tactics.mk` (squad) | not established | fixed → `PARITY_SECONDS` (squad's side; `net.mk` untouched) |
    | `RUNS` | `ai.mk` | `tactics.mk` | **silently** — a ladder run that *said* 2 runs did 4 | fixed → `AI_RUNS` / `TACTICS_RUNS` |

    The fifth (`RUNS`) was found by the owner while fixing the others, which is the argument for having one stream
    sweep its whole namespace rather than patching the reported case.
    **The fix pattern to copy** (squad, `3db1251f`): rename each knob to carry its owner's prefix, keep the old name
    working **but only from the command line** — `$(if $(filter command line,$(origin VAR)),…)` — so another file's
    *default* can never reach your targets while a human's explicit `VAR=` still does; and **echo what each target
    resolved to**. That preserves every documented invocation, closes the namespace, and makes a wrong value visible
    in the artefact. Verify with `make -n` on every form.

    **The loud/silent asymmetry is the whole reason to run the audit rather than wait for a crash.** `engagement`
    crashed on a missing file; its sibling `matchup-search` took the same wrong value as a *required* argument and
    produced plausible answers to the wrong question. **A collision that crashes is the lucky one** (cf. lesson 43's
    two halves) — so do not reason "a crash would have told me" about the knobs you have not checked.
    **The integrity consequence, recorded because it cannot be undone:** any conclusion drawn from `matchup-search`
    that assumed a non-default unit count is unreliable, **and there is no way to tell from the saved output, because
    the tool never recorded the value it used.** That is the same hole as the reproduce-line one above. The cheap
    permanent fix is to **print every resolved knob into the output**, so a wrong value is visible in the artefact
    rather than only in the behaviour.
    The rule to apply: **a knob two streams share deliberately belongs in the root `Makefile`; a knob one stream owns
    takes that stream's prefix** (`NAV_UNITS`, `VARIANT_FILE`). And print what a knob resolved to, so a wrong value is
    visible in the output rather than only in the behaviour.
