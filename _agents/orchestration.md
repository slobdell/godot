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
45. **A filtered test run cannot establish that a new test is correct — only that it is not obviously broken.**
    Round 6, arena, and it is the half of lesson 43 that nearly got away. Before reporting CP2 ready it ran
    `FILTER=arena_maze` and saw 5/5 green, and told the orchestrator so. **The filter was the whole problem:** it
    excluded precisely the neighbouring tests whose leftover navmesh its own tests were reading, so the run that was
    meant to build confidence had removed the only thing that could have failed. The interference you are most
    exposed to is with the tests a filter takes away. So: **iterate with a filter, but never make a readiness claim
    from one** — and when a new test depends on a global the engine owns (a navigation map, a physics space, a
    singleton, an import cache), deliberately run it *after* its noisiest neighbours before believing it. Only
    lesson 29 (merge the commit whose own check went green) kept this to a 25-minute round trip instead of a red
    `main` for six streams.
46. **A harness that runs the game slower than real time silently invalidates every *time-domain* conclusion drawn
    from it — and only those.** Round 6: `audio-pass` on builder0 recorded **3.1 seconds of match per 30 seconds of
    wall clock**, because a vsync'd window on an idle desktop presents at a crawl (`--disable-vsync` gives 25.6 s).
    Round 5 had already *noticed* the 10× discrepancy and left the cause open, then published mix conclusions taken
    through it. The discipline that makes this recoverable rather than a wholesale retraction is the one feel applied:
    **sort the affected numbers into those that describe what was recorded and those that describe the game.** Loudness,
    peak and clipping stand — they are properties of the file. Battle density, ducking behaviour and "layer changes
    look rare" do not — they are properties of events per second, and slow motion is the most flattering possible case
    for anything being ducked *under*. So: **when you find an instrument was running at the wrong rate, do not ask
    "are the numbers wrong", ask "which of these numbers is about time"** — and re-take only those. See also lesson 30,
    where three of six tick-rate bugs lied to a reader rather than breaking a test.
47. **A product guarantee that no test isolates can be held up by a coincidence — and it will look fine until
    something unrelated moves.** Round 6, the sharpest finding of the round. Product constraint #4 is the lead's own
    ruling: *"the player's units hold until ordered — an army that moves without being told is not an army."* CP4 broke
    it, and the reason it had ever worked is worse than the bug: **before N5, a held unit that entered ENGAGE hit the
    *outranging* branch** — `distance <= weapon["range"]` was true at that range — **and `_combat_move` returned
    `{"type": "stop"}`.** The player's units held still because an unrelated range heuristic happened to return "stand
    still", not because any hold logic said so. Narrow the range and the coincidence stops happening: the unit holds
    for 21.5 s and then **decides on its own to flank**, weaving for the enemy's side with its front armour on.
    The test had passed for rounds. **It asserted the outcome (the unit ended up near where it started) and never the
    mechanism (a held unit issues no move order)**, so nothing could ever reveal that the mechanism was absent.
    Three instructions, and the third is the one that is new:
    - **For every guarantee you have promised a human, write the test that isolates the mechanism**, not the one that
      observes the happy outcome. An outcome test cannot distinguish "enforced" from "lucky".
    - **When a guarantee breaks under an unrelated change, do not restore the unrelated thing.** Restoring the old
      range comparison here would put the guarantee back to being luck. Find out what was actually enforcing it —
      often nothing.
    - This is lesson 17 for the third time in one round, but in a worse form. Twice it was a rule **starving** a
      behaviour (the announcer silenced by a priority; a tank frozen at 61 m). Here it is a rule **sustaining a
      guarantee it knows nothing about**. Starvation shows up as something missing; a load-bearing coincidence shows
      up as nothing at all, until the day it does.
    Method worth copying: the stream **bisected and sent the table rather than the conclusion** — N5 ~8 m, the brain
    fix ~5 m, X6 **nothing** — and said the X6 row was the one that would have been easy to assume the other way. It
    also corrected its own earlier report that the failure was machine variance, having set out to prove it rather
    than assume it.
48. **A wait with no heartbeat is indistinguishable from a hang — and a queue without ageing is a race that starves.**
    Round 6, found by combat after its pilot run sat **41 minutes without ever starting a single process**, while
    builder0's load average was **1.35 on 8 cores** and two of the three slots were held by *rendering* jobs that
    barely touch the CPU. `tools/slot.sh` had no queue at all: every waiter woke each 5 s and raced for whichever lock
    happened to be free, so a job queuing for 41 minutes had exactly the same chance as one that arrived 5 seconds ago.
    **That is starvation, not contention, and it gets worse the more streams are live** — precisely when fairness
    matters most. It also printed its "waiting" banner **once** and then went silent forever, so a starved job and a
    running job looked identical in a log; that is most of why an hour went into diagnosing "builder0 is slow", and
    why the orchestrator had to `ssh` in to tell a stream whether its own build was running.
    Three instructions:
    - **Any wait longer than a minute must report itself periodically**, with its age and its position. A one-shot
      "waiting…" line is worse than nothing, because it looks like progress information and is not.
    - **A shared resource needs a queue, not a lock.** Ageing or ticketing turns "random" into "first come, first
      served"; without it, adding contenders does not slow everyone down evenly, it starves someone completely.
    - **When the fix is to a primitive every agent depends on, the orchestrator writes it, not the finder** — a
      deadlock in a locking script stops six streams at once. combat proposed the fix, declined to commit it to a
      shared file, and was right to. The counterpart obligation is to *test it*: an isolated queue directory, a
      three-waiter ordering check, and a SIGKILLed waiter whose trap never runs, before it goes anywhere near `main`.
49. **An aggregate that mixes two mechanisms measures the louder one, and its name will not warn you.** Round 6,
    combat, before running its 60-match series: `contact_second` is the first second with **any** shots and
    `engaged_distance_median` averages nearest-enemy distance over **seconds with shots in them** — and neither
    separates direct fire from indirect. N5 governs direct fire only (artillery is deliberately outside it: ARC
    already needs a spotter, and reach is its job). So in a Condemned mirror where 13% of kills were indirect, **a
    battery lobbing at a spotted contact across the map set "contact" and then held "engaged distance" at the
    separation of two armies that were not yet fighting.** `kill_distance` moved 45 → 35 m (the rule working) while
    `engaged_distance` barely moved, 79 → 75 m, and `contact` did not move at all.
    **The dangerous part is the conclusion that invites: "the bands are not binding, tighten them further"** — when
    they were binding all along, and tightening would have pushed the game into the too-quiet failure the round was
    already watching for. Same family as the metric whose value was fine but whose *printed label* hid what it was.
    So: **before running a series, ask which mechanisms each aggregate is summing over, and split the ones that mix
    a governed mechanism with an ungoverned one** — reporting the split *alongside* the old figure, never instead of
    it, so the existing baseline stays comparable. Twenty minutes on the metric beats sixty matches through a
    contaminated one.
50. **When two independently-owned numbers must stay ordered, the code has to say so — nothing will tell you the day
    they cross.** Round 6 found **three** load-bearing coincidences, each holding up something we believed was
    engineered, and each discovered only because an unrelated change moved one number:
    1. **The player's units held until ordered** because an outranging heuristic happened to return `{"type": "stop"}`
       at that distance — no hold logic existed (lesson 47).
    2. **A support-by-fire standoff stayed outside the near-ambush radius** because `standoff = min(effective_range) ×
       0.8` came to ~56 m while `near_ambush_m` was 38–42 m. Two numbers chosen independently, in different files, by
       different streams, for different reasons. Narrow the bands and the standoff lands at **28–36 m — inside the
       trigger** — so the element drives to its firing line, `near_ambush` pre-empts `support_by_fire`, the plan
       re-selects, and the two drills take the element off each other **every tick**: 128 orders in 10 s, the drill
       list alternating without a single completion. That is round 4's trip-up 17 reached by a new road.
    3. **`effective_range == range` for every weapon**, which is what made (2) hold and what several positioning
       heuristics silently depended on (lesson 39).
    The instruction: **an invariant that matters must be written as an invariant** — not left to two constants that
    happen to be ordered today.
    **But check that your belt does not undo your trousers.** The obvious spelling here,
    `standoff = max(reach × 0.8, near_ambush_m + margin, floor)`, was proposed by one stream, endorsed by the
    orchestrator as harmless insurance, and **correctly refused by the owner**: with a 45 m band it puts the firing
    line at ~47 m — *outside* the effective band, which is exactly the 50%-of-shells trade the same conversation had
    just rejected. The real invariant was the **precedence** (a deliberate support-by-fire task outranks a reaction
    drill), and once that is stated and tested, the distance floor is not insurance but a reintroduction of the bug at
    a different address. **A defensive constraint that re-creates the failure it guards against is worse than none** —
    and the person who can see that is usually the path's owner, which is why an orchestrator's "take both" deserves
    the same scrutiny as a stream's "take one". And when you find one, ask which *other* pair the same change moved: all three of these came out of
    one range narrowing, and the second and third were found days apart only because different streams tripped over
    them.
    **The corollary for reviewers:** a behaviour that has worked for four rounds is *not* evidence that anything
    enforces it. Ask what would have to be true for it to break, and check whether the code says that anywhere.
51. **"No fix at this level feels clean" is a diagnostic signal, not an aesthetic complaint — it usually means the
    defect is a level up.** Round 6, and the stream diagnosed itself better than a reviewer could have. Having found
    the support-by-fire standoff colliding with the near-ambush radius (lesson 50), it produced two candidate fixes,
    disliked both, and then **promoted the residue to a design feature**: *"support-by-fire must now choose between
    effective fire and not triggering an assault drill."* That reads like a considered trade. It was a rule fighting
    itself. Its own account of the error: *"I was reasoning inside the layer I had been looking at. The tell was right
    there and I walked past it — no distance tweak felt satisfying, which is what it feels like when the defect is a
    level up."* The real defect was one line of missing precedence a layer above the distances.
    Three instructions:
    - **When every candidate fix at your layer feels unsatisfying, stop tuning and go up a layer** before choosing the
      least-bad option. Dissatisfaction with all available fixes is evidence about where the bug is.
    - **Never turn an unexplained residue into a feature.** A self-interruption is not a cost the player can reason
      about; it is a bug wearing a trade's clothes. The test: can you state the cost in a sentence the lead would
      accept? "Posting an element buys less on a dense map" passes. "Your firing line triggers your own assault drill"
      does not.
    - **A withdrawn recommendation must be withdrawn in the document, not only in the conversation.** The stream
      committed the retraction and the reasoning so the brief carries the corrected answer rather than its first one —
      otherwise the next reader finds a confident wrong recommendation with no note on it.
    Also worth keeping: a **filtered** run cannot establish that a new test is *correct* (lesson 45), but it **can**
    establish that a failure is not an artefact of suite ordering. The stream ran one for exactly that, and said so.
52. **The orchestrator is not exempt from the trip-ups, and two of them bite hardest when you are relaying fast.**
    Round 6, in one five-minute stretch, the orchestrator committed both:
    - **Three concurrent `make remote` runs from the same worktree** (trip-up 66/68). Each rsyncs `--delete` into the
      *same* builder0 folder, so they swap files under each other and the one already executing is testing a tree that
      no longer exists. The cleanup is worse than the waste: every one of the three had to be stopped remotely and
      then locally, and the run that had held a slot for 30 minutes was void. **One remote run per worktree, and if you
      want a newer tree tested, stop the old run first rather than launching beside it.**
    - **`pkill -f "tools/remote.sh check"` from a shell whose own command line contained that string** (trip-up 19/79),
      which matched and killed the shell: exit 144. Collect pids (`ps | grep '[r]emote.sh' | awk '{print $1}'`), check
      each one's `readlink /proc/<pid>/cwd` to confirm it is **yours**, and kill by pid. Doing that here revealed that
      three of the candidate pids belonged to *other streams* (feel's `crowd-look`, nav's `test FILTER=`) and would have
      been killed by a broad pattern.
    The general point for whoever holds this role: **the orchestrator runs more infrastructure commands than anyone
    else and reads the docs least often**, because it is busy relaying. The trip-up list is not just for workers, and
    "I am only doing this quickly" is the condition under which it applies.
53. **A stream's approximation of another stream's system produces findings about the approximation.** Round 6, and it
    reached the lead before it was caught. feel needed camera poses to judge the crowd, so it approximated control's
    wall cutaway as *near plane = where the sight line to the focus crosses the wall, minus 1 m*. Its report frame at
    the lead's 12° showed the grandstand fascia filling the bottom third below the vehicles, and feel flagged it
    honestly as *"control's camera, not the crowd"* — the right instinct. But the real cutaway handles that case:
    with the camera 6 m past the wall it is **among the seats**, where control's rule always cuts, and the plane sits
    0.2 m past the wall's top edge so the fascia and the ground behind the wall go while the floor and a vehicle
    against the wall stay. control had **played that exact moment** and had a mutation-checked regression test for the
    earlier version that got it wrong. So the finding was real about feel's stand-in and false about the game — and
    the orchestrator had already sent the frame to the lead.
    Two instructions:
    - **When you need another stream's behaviour to judge your own work, call their code, do not model it.** control's
      `make camera-looks` applies the real cutaway per pose; using it would have cost nothing and produced frames that
      match the game.
    - **When relaying a frame or a number that depends on another stream's system, say which parts of it that stream
      owns and get their read first** — especially before it goes to the lead, who cannot tell a stand-in from the
      build. The cheap version of this is one message: *"does your implementation already handle this?"*
54. **A good experiment run against a broken instrument produces a confident wrong answer, and it is indistinguishable
    from a good experiment against a good one.** Round 6, arena establishing what slope the game supports. The answer
    was wrong three times before it was right, and **each wrong version looked like a clean engine limit**:
    1. The "ramp" was a 1 m slab — at 10° that is a *bridge*. The tank drove **underneath** and arrived at the goal's
       x/z at y=0.3. Read as "cannot climb above 5°".
    2. Made solid but 24 m wide, the tank drove **around** it. **A vehicle that goes around is indistinguishable in the
       output from one that cannot climb**, unless the geometry forbids the detour.
    3. Pathing to a point 1 m from the crest measured the navmesh's **agent-radius erosion along the drop edge**; the
       tolerance scaled with the rise, so it worsened with angle and read as a slope limit.
    Three geometries, three confident limits: 25°, 25°, 5°.
    **The tell was not in the data.** It was that *a tank that cannot climb 10° is not believable* — a real one manages
    30°. The fix was to stop pathing to a point and measure **coverage along the ramp's own centreline**, a quantity
    with no edges in it.
    **And the part that generalises furthest:** arena ran the decisive knob test (`agent_max_climb`) **against the
    broken measure first, and it came back negative** — the ceiling did not move, which looked like clean falsification
    and nearly retired the hypothesis that turned out to be correct. So:
    - **Check the instrument against a known quantity *before* the experiment, not after it surprises you.** Pick a
      case whose answer you already know independently (here: a tank climbs 30°, so a measured 5° ceiling is the
      instrument failing, not the engine).
    - **Implausibility is evidence.** When a result contradicts something you know about the world, suspect the
      measurement before you believe the finding — and say which known quantity you are testing it against.
    - This is the same failure as a filtered test run establishing correctness (lesson 45), and the same family as
      lessons 34, 44, 46 and 49: **this round found more broken instruments than broken game code.**
55. **Test the wire, not only the rule — and a conflict that looks like a duplicate may be two concerns on one line.**
    Round 6, and the first time this round a precaution actually paid out. combat's engagement envelope is a *rule*
    in `game/combat/engagement.gd` and a handful of *call sites* in nav's `order_controller.gd`. When it wrote the
    tests it added four that drive a **real `OrderController` through a real match** and exist solely to go red if the
    wiring is cut, justifying them as insurance against a bad merge or a failed edit (lesson 27). Then nav
    restructured that very file around those call sites — moving `_apply_unstick` out into `Movement`, and landing
    `movement.idle()` on the **same dead-code branch** as combat's `engagement_lay.forget()`. **The sixteen rule tests
    would have passed either way**, because `engagement.gd` was never touched; only the four wiring tests could have
    caught a dropped gate. That is the difference between shipping fire discipline and shipping a series that measures
    a game with no fire discipline in it.
    **And the conflict was the good kind: both sides were needed, not either/or.** `engagement_lay.forget()` resets the
    gun's lay; `movement.idle()` stops the driving. Two different concerns that happened to collide on one line.
    **Resolving it as "ours" or "theirs" would have silently broken one of them** — which is the standard move when a
    conflict looks like a duplicate, and the standard move is wrong here.
    Two instructions, the second aimed at whoever merges:
    - **When your feature is a rule plus call sites in someone else's file, write at least one test that fails if the
      call site disappears.** Rule tests cannot see an unwired rule.
    - **Before resolving a conflict by picking a side, say out loud what each side does.** If the answer is two
      different verbs, the resolution is *both*, and the fact that they occupy one line is a coincidence of layout.
56. **Repetitions of a deterministic process are not samples — check that the thing you are varying actually varies.**
    Round 6, nav: its movement suite ran five seeds and got **five identical results**, because a hold-fire drive
    contains no randomness. It defaulted the suite to one seed rather than keeping a reassuring-looking five. This is
    lesson 22 seen from the other side — that one says the fix for a *suspected bias* is a control that cancels the
    cause, never more repetitions; this one says repetitions of a deterministic process are not evidence at all, they
    are the same measurement written down five times. Before a series, **name the thing that differs between samples
    and confirm it differs**; and be suspicious of a set of results that agree *too* well, because identical is not a
    strong signal, it is usually the absence of one.
57. **A measurement's outliers deserve as much suspicion as its headline, because they are where the bugs hide.**
    Same run: **8 of every 60 units in the previous baseline were stragglers**, and the cause was not congestion at
    all — **60 units on 52 spawn points places pairs exactly on top of each other, and coincident hulls never moved
    at any point in round 5.** So part of a published arrival baseline was measuring two vehicles occupying one
    position, not vehicles getting in each other's way. The stream found it because it looked at *which* units failed
    rather than at how many. **When a measurement has a tail, identify the members of the tail before you accept the
    number** — a stable minority failing the same way is a defect, not variance, and it will otherwise be absorbed
    into the baseline everyone improves against.
58. **A shared recorded artefact belongs to whoever is last, so it belongs to the orchestrator.** Round 6: three
    streams each changed how the simulation evolves, and each was about to record `sim_state_hash.txt`. "Whoever
    merges second re-records" works for two and is undefined for three — nobody can know at record time whether they
    are last, and all three hashes would have been stale. The rule now: **no stream records it; the orchestrator
    records once on `main` after the last simulation-changing merge**, and a stream whose change moves it says so in
    its green report instead.
    The generalisable test for any artefact like this: **is it a property of the tree rather than of the change?** A
    recorded hash, a golden output, a committed baseline count, a perf baseline — all are properties of the whole
    tree, so a per-stream copy is a snapshot of a world that stops existing at the next merge.
    And the detail that made it dangerous rather than merely untidy: **nothing local could catch it.** The file is
    keyed per glibc, the laptop's glibc has no line in it, so `sim-baseline` *silently skips* locally — every stream
    could commit a stale hash and see a green local check. **A check that skips is not a check that passes**, and a
    skip that is invisible is worse than a failure.
59. **When a shared input changes, the instruments that read it are as stale as the code — and nobody owns an
    instrument.** Round 6 changed the camera once, and **four** separately-owned constants turned out to have been
    calibrated against the old one:
    1. arena's `exposure()` watcher range (a weapon-range assumption wearing a sightline's clothes);
    2. the dither metric's 60 Hz divisor, reporting double the true rate for four rounds;
    3. control's phone readability bar, set at 25°/FOV 55;
    4. **`squad-orders-test` clicking at screen fractions set for a 45° camera** — so at the lead's 12° one squad's
       target point was **sky**, no order was issued at all, and 6-7 units per run silently went uncommanded.
    The fourth is the instructive one because **it was inside the instrument that measured the round's most contested
    change.** It appeared in *both* arms of the A/B, so the comparison survived and the conclusion held — but the
    absolute numbers were wrong, and a reader would have had no way to know.
    Two instructions:
    - **After changing a shared input (a camera, a tick rate, a range band), grep the *test and tool* code for
      constants that read it, not only the game code.** Instruments are written once and inherited; they have no
      owner and no reason to be revisited.
    - **A defect present in both arms of a comparison protects the comparison and corrupts the measurement.** When you
      find one, say which of the two you are claiming — "the A/B still holds, the absolute numbers were wrong" is a
      complete and honest sentence, and it is what control said.
60. **A caveat travels with a number in a message and does not travel with the idea into a document.** Round 6, and the
    orchestrator did this to itself. combat sent a result labelled *directional, n = 2, one mirror pairing, not for the
    lead*. The orchestrator **held the number back from the lead correctly** — and then wrote the *conclusion drawn
    from it* into `game_design.md` as established design understanding, where "n = 2" did not survive. At n = 15 the
    finding **inverted**: the fire rate went down, not up, and the reframing built on it was unsupported.
    This is lesson 26 committed against oneself, in the file that briefs every future stream. Three instructions:
    - **Nothing enters a design document from a sample that could not support a claim to the lead.** The bar for
      "written down as how the game works" is the same bar as "told to the human", because a doc outlives the
      conversation that qualified it.
    - **The more a result reframes something, the smaller the sample you should accept for it.** The stream's own
      account: *"I argued it confidently because it was surprising and had a tidy mechanism behind it, which is exactly
      when I should have trusted it least."* A surprising result with a satisfying mechanism is the most seductive
      possible combination, and n = 2.
    - **Retract in place, not by deletion.** The wrong claim is left in `game_design.md` marked RETRACTED with why it
      got in, because a future agent who half-remembers the idea needs to find the retraction rather than the silence.
    Also recorded from the same run: a **pilot's job is to validate the pipeline, not to answer the question**. This
    one found two real defects in the harness (a `--variants` run that omits the shipped configuration; a metric
    contaminated in theory) and was then asked to answer a question it was never large enough to answer — twice in one
    afternoon, by a stream that knew better and said so afterwards.
61. **A number that lands near the truth from the wrong comparison on an inadequate sample is a coincidence, not a
    result — and saying so is worth more than the credit.** Round 6: a retracted figure said the fight was decided
    **28%** closer; the final, properly controlled 75-match answer was **26%**. The stream that had retracted it
    volunteered that the near-agreement was luck and insisted the retraction had still been right, because against
    the control actually used at the time the honest figure was **7%** — the two matches had been compared with the
    wrong baseline *and* were too few. **The lesson a reader would otherwise draw — "trust the small sample, it was
    nearly right" — is precisely wrong and would cost someone a round.**
    So: **when a retracted number turns out close to the truth, record why it was still wrong.** A result is a
    measurement *plus its comparison*; a right-looking number from the wrong control is not a partial success, it is
    two errors that happened to cancel.
62. **A control that is not a real "before" hides which half of a change did the work.** Same run. The first series'
    control disabled only the tuned *data* (the effective bands) while leaving the *code* gates (sight, acquisition,
    the crossing penalty) on in both arms — so it measured fire discipline alone and silently attributed the whole
    effect to it. With a genuine control (`--no-acquisition --no-crossing` as well), the decomposition inverted the
    round's priorities: **the gates moved kill distance −11 m and off-axis kills +17 points; the bands moved them −3 m
    and +2 points.** The bands had absorbed nearly all of the round's design argument and were the smaller half.
    **Before running a comparison, ask what your control actually turns off** — and if a change spans data and code,
    a data-only control is not a before, it is a different experiment.
63. **A result arriving is not the change arriving — and the orchestrator is the only one who can confuse them.**
    Round 6, caught at close by accident: the orchestrator had told two streams that CP4 was landed and their work
    unblocked, and written its conclusions into `game_design.md` as settled design understanding, **while
    `game/combat/engagement.gd` did not exist on `main` and 33 commits sat unmerged on the branch.** The sequence that
    produced it: two of the stream's infra commits were cherry-picked early; the branch then sat *deliberately* red
    waiting on another stream; and when its measurement series came back and it reported *"my outstanding work is
    done"*, that was read as the stream being finished and the search for a merge hash stopped. **The number produced
    *by* a branch was taken as evidence that the branch was *in*.**
    This is the mirror image of the rule the same orchestrator spent the day enforcing (never publish a number
    measured across a merge), and only the orchestrator can make it, because only the orchestrator holds both the
    merge state and the relay.
    Three instructions:
    - **Track checkpoints by merge state, not by conversation.** A checkpoint is landed when `git log main --merges`
      says so. *"Its result is settled"*, *"the stream is done"* and *"it went green"* are all compatible with nothing
      being merged.
    - **A branch that is red on purpose is the dangerous kind**, because the usual prompt to merge — a green report —
      never arrives, and the stream has a good reason not to send one. Put an explicit note against any deliberately
      red branch saying what it is waiting for and who clears it.
    - **When a stream says a dependency of its own is still blocked, verify rather than reassure.** This was found only
      because a stream mentioned waiting on "CP4 *on main*" and the orchestrator checked instead of correcting it.

    **And the stream's half, which is the sharper diagnosis of the two** (its own words): *"a stream's status is the
    hash, not the narrative."* It had reported findings, retractions, measurements, cross-stream diagnoses and a
    sentence for the lead — at length, repeatedly — and **never once sent "combat is green, merge here: `<sha>`"**,
    which is rule 11 of the worker contract. Because it was narrating everything else in detail, *the silence about the
    merge looked like there was nothing to say*. The mechanism was not carelessness: **the branch was legitimately red
    for most of the round, and "red by construction, waiting on <stream>" is a status it reported clearly and often.
    What neither side had was the transition.** Nothing fires when the last blocker clears — it went straight from
    *waiting* to *running the series*, because the series was the interesting thing and the merge was never an item on
    anything.
    So, for workers: **a blocked branch needs an owner for the moment it stops being blocked, and that owner is the
    stream.** A stream that reports only what it has *learned* looks finished when its findings stop; report what is
    *mergeable* as a separate, explicit thing, every time it changes.
64. **"Nothing drawn" and "drawn too dark" look identical: paint it red.** Round 6, the black band under the arena
    wall that the lead's 12° camera showed every match. Everyone — including the orchestrator, in writing, twice —
    described it as *the ground plane ends at the stands*, i.e. missing geometry, and handed it over as "a dark plaza
    would fill it". **Geometry could never have fixed it:** the camera's near-plane cutaway clips every real surface
    between a camera past the wall and the wall itself, so no mesh can occupy that band. What showed through was the
    **sky dome's below-horizon colour**, which ACES tonemapping with white 6 crushes to exactly `(0, 0, 0)`.
    The stream proved it by **painting the suspect surface red** — a two-minute test that distinguishes the two
    hypotheses absolutely, where staring at a black region distinguishes nothing.
    The general instruction: **under a tonemapper, an unlit surface much darker than its surroundings rounds to pure
    black, so "absent" and "present but crushed" are visually identical.** Before concluding something is not being
    drawn, give it an impossible colour. And the wider form, which this round hit repeatedly: when two hypotheses
    predict the same observation, **stop looking harder at the observation and find the cheap test that separates
    them** (cf. lesson 54 — a probe consistently measuring a bridge, broken open by implausibility rather than by
    repetition).
65. **A differential question implemented as an absolute comparison produces a confident false accusation.** Round 6,
    found by combat while verifying CP4: with the sim baseline legitimately stale, **three** targets failed on the same
    pair of hashes — and only one of them said anything true.
    ```
    sim-baseline FAILED: expected 8ebbed52… got 91db2388…
    announcer-record-smoke FAILED: the booth changed the simulation (91db2388…, baseline 8ebbed52…)
    music-smoke FAILED: the soundtrack changed the simulation (91db2388…, baseline 8ebbed52…)
    ```
    **The booth changed nothing and the soundtrack changed nothing** — each computed *exactly* the hash `sim-baseline`
    computed, which is the proof. Both targets want to answer *"does this subsystem perturb the simulation?"*, a
    question about the **difference between two runs**, and both answer it by comparing one run against the **global
    baseline file**. So they fail whenever anything else legitimately moves that baseline — which invariant 2 now
    guarantees happens once per round — and each time they name an innocent subsystem in their own owner's code.
    **The fix:** run the match twice in one invocation, with and without the subsystem, and compare **the two hashes to
    each other**. That tests what the target claims, is immune to the baseline moving, and needs no coordination with
    invariant 2 at all.
    The general instruction: **when a target's message names a culprit, check that its comparison can actually
    implicate that culprit.** A test that asks "did X change this?" by consulting a global constant is not asking about
    X — it is asking "is the world as it was", and will blame X for everyone else's changes. And for anyone reading a
    red check: **three failures reporting the same number are one failure**, not three.
66. **A derived value copied into a second place is a stale value waiting for its moment — and one stream hit this
    four times in a single day.** Round 6, arena, each instance the same bug in a different costume:
    1. `exposure()` hard-coding a **110 m** watcher range — a weapon-range assumption wearing a sightline's clothes,
       which had inverted a *published* flanking conclusion (1.8–2.1× detour became 1.0–1.1× once derived).
    2. `UNITS`/`ARENAS`/`RUNS` as bare make knobs another file's default could reach (with combat's `VARIANTS`).
    3. A plot titled `direct_route_exposure` — the legacy measure — printed beside a card quoting the derived one:
       **two different numbers with the same name on one page**, which is how a reader learns to distrust both.
    4. A **"posted" reach hand-set to 70 m** from "a cannon's full range", where the catalog's own median of
       `min(full range, sight radius)` is **60 m** — several units cannot *see* as far as they can shoot, and the
       sight cap that the *idle* figure applied had not been applied to the posted one. **It inflated every posting
       figure by about half.**
    The fix was the same every time and the stream said so: **put it in one place and read it.** `make arena-reach`
    now runs `Engagement.covering_range()` and writes a file the report reads, with the constants demoted to a
    labelled fallback and a flag to override.
    Two instructions:
    - **A number you did not compute in the place you use it is a copy, whatever it looks like.** A named constant, a
      make default, a plot title, a figure in prose — all copies. Derive it, or read it from where it is derived.
    - **When a re-derivation moves a number, find out whose error it was before relaying blame.** Here the
      orchestrator had warned that combat's proposal might shift arena's figures; the figure that actually shifted was
      arena's own hand-set constant, and combat's derivation was right all along.
67. **A consistent failure on one machine and an intermittent one on another are usually one bug, differing only in
    timing.** Round 6: `shell-playtest`'s faction-click checks failed **every** run on builder0 and **one in seven** on
    the laptop. The laptop case had been filed as a stray-mouse artefact (trip-up 32) and the builder0 case as "a click
    or resolution issue on builder0" — two environmental explanations for one defect. The cause was neither: the
    **loading screen** is a full-screen, click-stopping `CanvasLayer` on the root, and it was **still fading out** when
    the playtest clicked. builder0's ~1 fps desktop made the race certain; the laptop lost it occasionally.
    Two instructions:
    - **When the same check fails always here and sometimes there, do not reach for two environment stories.** Look for
      a race whose window the slower machine widens. "Flaky on A, broken on B" is one of the strongest available hints
      that a timing window exists.
    - **A gate that always fails is as uninformative as one that always passes**, and it hides real signal: this one
      had been red unconditionally on the machine we verify on, which is precisely why a texture leak in another
      stream's code went unnoticed until a human looked by hand. After this fix `shell-playtest` exits 0 on builder0
      for the first time — **an always-red check should be treated as an outage, not as a known quirk.**
68. **A checkpoint merge has a shelf life, and the tell is a third number.** Round 6, arena: it merged `main` at the
    announced point, did an hour's work, and its check failed `sim-baseline` — expected `8ebbed52…` (its tree's
    committed line), **produced `91db2388…`**, while the baseline the orchestrator had just recorded on `main` was
    `ae7466f3…`. **Three different numbers.** The explanation was not a defect: `main` had taken nav's and control's
    merges in the meantime, so `91db2388…` was the correct hash of a real third state — CP4 without nav or control.
    **The produced hash matching *neither* candidate is what made it legible**, and that is the part to remember:
    - had it matched the orchestrator's `ae7466f3…`, the obvious reading is *"my baseline file is just stale"*;
    - had it matched its own `8ebbed52…`, the obvious reading is *"CP4 did not move the simulation"*;
    - both readings would have been wrong, and each is the first thing a reasonable agent would conclude.
    So: **when a hash comparison fails, enumerate every hash you can name and check which ones the produced value
    matches.** A value matching none of them means your tree is a state nobody has a record of — usually because
    "`main`" meant something different an hour ago. And **say so when you hand over a branch merged at a stale
    checkpoint**: arena warned that its next hash would carry nav's and control's work as well as its own, which is
    exactly what an orchestrator expecting an arena-only diff needs to hear.
69. **"It fails on `main` too" clears a stream only if `main` does not contain that stream's work — and that stops
    being true the moment it first merges.** Round 6, the round's most careful isolation and it was still unsafe. nav
    reported a failing scenario, ruled its own work out by switching **five** mechanisms off individually and all
    together on its branch, and observed the same failure on `main` — a properly constructed control. The orchestrator
    relayed it to another stream as "not nav's". **But `main` already contained nav's earlier merge**, including the one
    mechanism whose experiment switch was broken and which therefore had *not* been in the A/B. nav caught it and
    retracted before the other stream had spent an hour.
    Two instructions:
    - **In a round where streams merge repeatedly, `main` is a clean baseline for a stream only until that stream's
      first merge.** After that, "reproduces on `main`" means "reproduces with my own work present". Use
      `git archive` of a commit *before* your first merge, or an explicit revert, if you need a real control.
    - **A feature whose kill switch does not work is invisible to your own A/B, and you will not notice** — the switch
      reads as coverage. When you build an experiment switch, test that it actually changes behaviour (mutation-check
      it) before you rely on it to exonerate anything.
    And the orchestrator's half: **when a stream hands you an exoneration, check that the control is still a control
    before relaying it.** The relay is where a plausible inference becomes another stream's afternoon.
70. **A false premise in a brief propagates; a false instruction only costs one worker an afternoon.** Round 6, found
    at the close: **"wrecks are on physics layer 4 on purpose, so they never block driving"** appeared in *two* stream
    briefs and in the orchestrator's HANDOFF survey, and the orchestrator repeated it in a relay. **It is false.** Only
    `tank.tscn` sets a collision layer anywhere; `Arena._build_obstacles()` makes a plain `StaticBody3D` on default
    **layer 1**, the `Obstacles` node carries the `navigation_source` group, and the bake parses layer-1 shapes in it —
    so the `wreck` **kit prop** is baked into the navmesh and blocks like any container. A destroyed **vehicle** leaves
    no body at all. **Two different things share one name.** The claim traces to `balance.md`'s destructible-cover
    proposal — *"a wreck **moves to** collision layer 4"*, future tense, never built — restated as present fact and
    carried for two rounds.
    Three instructions:
    - **This is trip-up 24 with a worse blast radius.** There, a confident wrong *instruction* cost one worker half an
      hour. Here the wrong belief was written into the briefs, so it was *inherited* by every agent who read them and
      shaped what two streams did and did not attempt (nav nearly wrote off X9 on it). **Check a claim before you put
      it in a brief, at the standard you would use before telling the lead.**
    - **A proposal quoted out of a design doc becomes a fact.** When you lift a line from a design document into a
      brief, carry its tense. If `balance.md` says a thing *would* move to layer 4, the brief must not say it *is*.
    - **The suite had already proved it and nobody read the test.** `ArenaFixture.inside_cover()` probes the widest
      collidable prop — a wreck on two shipped layouts — and asserts it is *off* the mesh, for every layout, passing
      all along. **A passing test is a statement about the world that nobody is reading.** When a belief matters, grep
      the tests for it before grepping the code: a green assertion is cheaper evidence than an investigation.
71. **After resolving a conflict, run `git status` before you commit — the index may already hold something you were
    thinking about earlier.** Round 6's close: the orchestrator ran `cp build/sim_state_hash.txt tests/baselines/` and
    `git add` it in the *same command* as a merge that then failed on a conflict. After resolving the conflict it staged
    the one file it had fixed and committed — **sweeping the baseline record into a merge whose message says "docs
    only".** The content was right; the message is now wrong, and a bisector chasing a simulation change through that
    range will not find the baseline move where it is announced.
    The fix was a follow-up commit stating exactly where the baseline landed, **not** an amend: rewriting a merge that
    other worktrees may have seen is worse than an inaccurate message with a correction attached to it.
    This is lesson/trip-up 16 and 70 in a third place (`git add -A`, then a `.tools` symlink, now a staged file
    surviving a failed commit). The generalisation that finally covers all three: **the index is not empty just because
    your last command failed.** A failed commit leaves everything staged, and the next `git add <one path>` adds to that
    set rather than replacing it.
72. **No agent on this project can play the game, and that decides which questions only the lead can answer.** Round 6
    closed with the lead playing `make skirmish` and reporting two things no stream had caught: **the camera he had
    chosen twice was unplayable**, and **the audio was silent**. Both had passed every gate. control's own statement of
    its limit is the cleanest account of why: *"I've run scripted sessions and looked at their frames at both settings.
    I can't play with a mouse."*
    Everything this project calls playtesting is **scripted input plus screenshots**. That is genuinely powerful — it
    caught the wall-clipping, the fascia, the crowd's value range, the popping — and it is blind to an entire class of
    property: how much ground you can read *while deciding*, whether panning feels right, whether a sound is present,
    whether a response feels instant rather than measures as instant. **For those, the lead is not the best check; he is
    the only one.**
    Three consequences to design around, rather than lament:
    - **Sort every open question by whether an agent can answer it.** "Does the crowd read at 200 m" is measurable —
      pixels, contrast, figure height. "Is this camera playable" is not, at any effort. Put the second kind in front of
      him **early and cheaply**, and never let a measurable proxy stand in for it. A page of stills was a proxy for
      playability and it produced a confidently wrong answer that cost a day's work in both directions.
    - **When you must ask him, make the artefact move.** A clip, a recording, or him driving it. The round asked him to
      pick a camera from frozen frames and to judge crowd audio from an MP3 — the second worked *because sound is
      time-domain and the recording was too*; the first failed because playability is not visible in a frame.
    - **Expect the gates to be silent about exactly the things he notices first.** Audio presence and camera feel are
      both first-thirty-seconds properties and both invisible to `make check`. Twice now he has reported an audio fault
      no automated check saw. **That is not a gap in the audio tests; it is the boundary of what a test can be.**
73. **A default that has to be passed is not a default — and it will work on exactly the path its author tested.**
    Round 6's last defect, reported by the lead as *"the audio is defaulted to off"*. The music director and the
    announcer booth both read `flags.text("music", "off")`: **a missing flag means OFF.** Only `make skirmish` and
    `make audio-pass` pass `--announcer=voice --music=on`. So **every other way into the game launched with no booth and
    no music** — the title screen's SKIRMISH, the garage's FIGHT, a plain launch — for as long as those defaults have
    existed. The sound *effects* were never muted, which is why it read as "some audio" rather than "no audio" and why
    nobody chased it.
    This is lesson 23's shape (*a behaviour behind a flag the default path never passes has not shipped*) with the
    polarity reversed: **the flag was the on-switch, and only two of five entry points knew to throw it.** The fix is a
    real default — a launch with a window gets voice and music unless a flag says otherwise — with the exclusions stated
    (headless, `--mute`, and the title screen's backdrop fight, which otherwise had the booth calling a match behind the
    menu).
    Two instructions:
    - **When you add a capability behind a flag, enumerate every entry point and check each one.** "The make target
      passes it" is a statement about one path. This project has five ways into a match and the feature worked on two.
    - **The verification has to traverse the path, not the unit.** feel's fix came with `make audio-launch-smoke`,
      which drives the real title → SKIRMISH → faction menu → FIGHT sequence with no audio flags, mutation-checked
      against the old code (FAIL: "no speaking booth") — the only kind of test that can see a defect that lives in
      *how the game is entered*.
74. **An interaction is only verified by performing it — reading the source you wrote cannot tell you it does nothing.**
    Round 6: the lead's arena review page presented *"Keep it · Fix it · Cut it · I'd rather just play it first"* per map
    and he reported *"that page doesn't have buttons I can click"*. The orchestrator guessed a missing `db` capability
    or an event-binding bug. **Neither. The four answers were printed as a sentence in a `<p>` tag.** They look exactly
    like a control and are text. **There were never any buttons to bind or to store from** — a page built to collect an
    answer, structurally incapable of collecting one. It had been verified by reading the HTML, which confirms the words
    are on the screen and *cannot distinguish that from a working control*.
    The stream's own note is the sharpest part: *"it caught me even after I had written the same lesson about my own
    instruments twice today"* (lessons 54 and 66). **Knowing the lesson does not transfer across media.** It had learned
    to distrust a probe and still trusted a page.
    Two instructions:
    - **Perform the interaction on the published artefact before handing over the link.** Click it. For anything a human
      is meant to *do* rather than read, source review is not verification — same boundary as lesson 72's "no agent here
      can play the game", one layer out.
    - **Prefer the shape that cannot half-work.** The fix uses real radio inputs, a textarea that rebuilds from them, and
      a Copy button — **no database, no stored state**, because the pick is the entire payload and a storage layer would
      be more to get wrong than the thing it stores. It degrades to "describe your picks" if the script fails, rather
      than to nothing. That is the same pattern that finally settled the camera (live controls, one key to print a
      pasteable line), and it worked for the same reason.
75. **A stateless form loses the answer of anyone who does not perform the final step — and "press the buttons" feels
    complete.** Round 6: the orchestrator recommended the arena review page store nothing, on the reasoning that the pick
    *is* the whole payload and a storage layer is more to get wrong than the thing it stores (lesson 74). arena built it
    that way, correctly. **The lead then pressed every button and left**, and the answers existed only on his clipboard.
    They are lost.
    The camera pattern it was copied from worked for a reason that did not transfer: **there, printing the pose was the
    natural end of the interaction** — he was hunting a value, and `P` was how he captured what he had found. **Here,
    choosing was the whole task, so pressing the last radio button felt like finishing.** A Copy button after that reads
    as optional.
    So the rule is narrower than "prefer stateless":
    - **Stateless is right when the human's own goal ends in taking the value away** (hunting a setting, capturing a
      measurement). **Persist when the human's goal ends in having answered** (a form, a review, a vote) — because they
      will stop at the point their task feels done, not at the point yours does.
    - **If it must be stateless, make the final step the only step**: no separate Copy button after the last choice —
      auto-select the summary, or make each choice update something visibly outward-bound, so there is no state in which
      the page looks finished and has sent nothing.
    - **And test the abandonment path, not the happy path.** The question to ask of any collection artefact is *what
      reaches me if they close the tab right now?*
76. **Reachability is "the path ends at the goal", never "a path came back".** Round 7, arena, and it is the **third**
    time this exact shape bit the same stream (the maze fixture, the slope probe, now the water probe). Its first water
    run reported `reachable: true` with an **8 m route for a 46 m trip across a channel spanning the whole arena**.
    The cause is documented behaviour, not a bug: `Pathing.find_path()`'s own docstring says *"an unreachable `to` yields
    a path to the closest reachable point"* — so a non-empty return means *"I got as close as I could"*, and every caller
    that treats it as success is wrong.
    **This is not only a probe problem, which is why it matters more than the three instances suggest.** `Movement` (N1)
    is built on `find_path`, so a unit ordered somewhere it cannot reach drives to the nearest point it can. If it then
    reports `arrived`, an order completes at the wrong place and the player sees **disobedience**; if it sits there, the
    player sees a **stuck vehicle**. Both are exactly what the lead reported after round 6 measured 100% arrival — and
    neither requires a pathing defect. **The pathfinder behaves as documented and the layer above believes it.**
    And the transient case is the dangerous one: a goal inside a crowd of parked friends, behind a wreck, or on a slot
    one's own formation is standing on is *temporarily* unreachable — so the unit paths to "nearest reachable", arrives,
    and the decider re-issues. **A thrash loop from a cause nobody would suspect.**
    Two instructions:
    - **Assert the endpoint, not the emptiness.** Any caller of a pathfinder must compare the path's last point to the
      requested goal within a tolerance it chooses deliberately, and report *"closest reachable"* as its own state.
    - **A documented convenience is a trap when it is convenient.** "Returns the closest point instead of failing" is a
      kindness to a caller that wants to make progress and a lie to a caller that wants to know. When an API offers
      graceful degradation, find out which of those you are.
77. **A generalisation that does not reduce to the current case is not a read-through — it is a balance change wearing
    one's clothes.** Round 7, combat generalising a single central control point into a list of objectives. The test it
    applied to its own change: score by the **share** of objectives held (`ticks += INTEL_EVERY_TICKS × held/total`)
    **because at N=1 it reduces to the old accumulation exactly.** Holding both of a mirrored pair then scores at the old
    rate and holding one scores at half — so splitting your force becomes the decision the contract exists to create,
    without any shipped arena changing. **Apply that reduction test to every "just a read-through"**: if the old case
    does not come out identical, you are shipping a balance change under a refactor's name, and nobody will review it as
    one.
    Two more findings from the same change, both about *shared mutable* state:
    - **Make the compatibility shim a VIEW, not a copy.** Its first cut made the legacy `control_owner` a copy the tick
      wrote back — and a test that pokes that field between frames had its poke overwritten, so **the match silently
      never ended.** Five streams both read *and write* that state; only a write-through view keeps every pre-existing
      reader and writer working untouched.
    - **A static accessor that can only know the default is a quiet staleness bomb.** `Match.in_control_zone` is kept
      because five streams call it, but it cannot see an off-centre objective — so the day such a layout ships,
      `cpu_commander.gd`'s call goes **quietly stale rather than loudly breaking.** Flagged with its instance
      replacements. *Prefer a loud break to a silent wrong answer when you deprecate.*
78. **The standard is easier to apply outward: expect to fail your own rule the moment your own work is the suspect.**
    Round 7, combat, in its own words: *"every time I have been wrong today, I was wrong about my own work while holding
    other people's to a standard I had just failed."* The instance: a test failed after its change, it compared a
    **filtered** pre-change run against a **full** post-change run, saw pass-then-fail, and concluded *"it IS mine,
    despite having zero references to control"* — **having given the orchestrator that exact distinction as a refinement
    to lesson 45 earlier the same day.** A filtered run and a full run answer different questions. The filtered run on
    the new tree (17/0) is what actually exonerated the change.
    So: **when your own work is the suspect, apply your own checklist deliberately rather than by instinct** — instinct
    is what defers to the suspicion. And the practical form, which is also what saved it: **re-run rather than reason.**
    The same shape appeared in three streams this round (arena's filtered 5/5, nav's `main`-is-not-a-control, this), so
    it is not a personal failing; it is what suspicion does to a standard.
79. **Ask the lead to object, not to adjudicate.** Round 7, third time in one evening: the orchestrator asked him whether
    the crowd murmur *"sounds like people or like hiss"*, whether to *"keep or drop the per-faction driving feel"*, and
    which faction should keep a duplicated unit. He did not answer the first two and replied to the third with **"I don't
    understand the question."** None of the three was a bad *decision* to want from him; all three were **badly shaped
    asks**.
    **What he answers well, on the evidence:** a concrete choice with the consequence stated — the camera page (he picked,
    twice), the arena verdict (keep / fix / cut / play it first, six maps, answered in one sitting), *"which arena is
    fun"* once it became *"this map funnels every fight into the middle — keep, fix, or cut?"*. **What he does not
    answer:** a trade-off between options whose consequences he has no way to evaluate, and anything requiring him to
    hold internal design context he has never been given.
    **So the default shape is: state what we are doing and why, in one or two sentences of his vocabulary, and ask
    whether he objects.** *"We are dropping the Syndicate's Lancer because their tank already shoots further than it
    does — object?"* is answerable in three seconds. *"Which faction should keep the Lancer?"* requires him to know four
    rosters. **A recommendation with a visible reason costs him a yes/no; a question costs him a design session he did not
    ask for.**
    Corollary, and it is the reason this keeps happening: **the orchestrator asks questions in the shape the streams
    hand them over in.** A stream that has just weighed two options naturally reports the two options — and relaying that
    shape is the failure. **Converting a stream's trade-off into a recommendation is part of the relay, not an optional
    courtesy.**
80. **UI that explains behaviour must be *derived from* the behaviour, or it becomes a confident lie.** Round 7: the lead
    asked for help that shows *"what each action does"* because he could not tell what `screen` meant. control built the
    animated preview against a **stand-in** of each posture — reasonable, since squad's planner was not yet on `main`.
    When it merged and the previews switched to **squad's real planner**, they changed: **support-by-fire guns sit at a
    standoff each covering its own sector**, not all pointing exactly at the point as the stand-in drew; **Hold previews as
    the all-round coil the planner actually forms.** The stand-in was plausible, legible, and wrong — **and it would have
    taught the lead a posture the game does not produce.**
    The fix control made is the reusable part: **the test now asserts that the planner is the source**, not that the
    drawing matches a picture. So the preview cannot drift from the behaviour without failing.
    Two instructions:
    - **Explanatory UI is a second consumer of the real system, never a second implementation of it.** Tooltips,
      previews, tutorials, help diagrams and debug overlays all have this property. This is lesson 66 (a derived value
      copied is a stale value waiting) applied where the copy is a *drawing* — and it is worse there, because a wrong
      number looks wrong to someone eventually while a wrong diagram looks authoritative forever.
    - **Assert the source, not the output.** "This preview came from the planner" is a test that survives the planner
      changing; "this preview looks like *this*" is a test that pins today's posture and will be updated to match
      whatever the drawing becomes.
81. **A removal recommendation is not complete until it states what the set looks like afterwards.** Round 7: combat
    recommended dropping `syn_lancer` on a clean comparison — the Syndicate's own tank reaches 104 m against the lancer's
    86, so it was a shorter-ranged duplicate of a role that faction already dominates. Correct about the unit, and wrong
    about the roster: **the lancer was the Syndicate's only special**, so removing it would have left them the one faction
    with no identity beyond the core four. The Condemned survive losing theirs only because they also field the Burner.
    combat found this **while implementing its own accepted recommendation**, because
    `test_every_playable_faction_fills_the_core_roles` failed.
    Two things to take from it:
    - **The guardrail worked because it asserts a design pillar, not an implementation detail.** "Counters stay learnable
      across factions" is a sentence from `vision.md`; the test is that sentence in executable form. **Tests that encode
      pillars catch design mistakes that no amount of unit-level correctness will.** Write more of them, and name the
      pillar in the assertion message so the failure explains itself.
    - The reviewable question for any *delete this* proposal is **"what is the count afterwards, per faction, per role?"**
      A comparison between two units cannot answer it, because the comparison is local and the damage is structural.
82. **"The lead did not object" is not a decision, and relaying it to a second stream as one is the orchestrator's error.**
    Same episode. combat proposed the drop, the lead said nothing against it, and I told **feel** to stop work on that
    unit — before the change had been implemented, let alone tested. feel had just fixed that model's backwards
    orientation, so I described real work as wasted, and it was not.
    This is lesson 63 (*a result arriving is not the change arriving*) in the design register rather than the code one:
    **a stream's status is the hash; a design decision's status is the test that passes with it in place.** Silence from
    the lead is permission to *try*, never confirmation that it *works* — and the cost of relaying it early lands on a
    stream that has no way to check.
    Practical rule: **do not tell stream B about stream A's decision until A has landed it green.** The exception is
    exactly the reverse case — when B is about to duplicate or contradict A's *in-flight* work, say so immediately, and
    label it as in-flight.
83. **The suite tests a directory; we hand each other commits; nothing in the process compares the two.** combat caught
    on itself that `git checkout HEAD~1 -- <file>` **writes the index** — it had restored the working tree from copies
    afterwards, so the old version stayed *staged* and the next commit carried it. **Every test passed, because tests run
    from the working tree.** A "docs-only" commit silently reverted N7, and the green hash it would have reported did not
    contain the feature it was reporting on.
    This is the same hole as lesson 71 (*the index is not empty just because your last command failed*) from the other
    side, and it is the more dangerous side: **a staged-but-unintended change is invisible to every check we run.**
    The rule both halves point at: **verify `git show HEAD:<path>` before naming a hash**, not the file on disk. And after
    any `git checkout <ref> -- <path>`, `git restore --staged` or a conflict resolution, **read `git diff --cached` before
    committing.**
84. **A proposal written in future tense becomes a fact the moment it is quoted into a brief.** arena's framing of
    lesson 70, and it is the mechanism, not the symptom: `balance.md` said wrecks *would* be moved to physics layer 4;
    I repeated it into two briefs and the HANDOFF survey as though they *were*; nothing in the restatement carried the
    tense. **A proposal and a fact are indistinguishable once separated from their source.**
    So: **briefs cite where a claim comes from rather than restating it** — `game/x.gd:120` or `balance.md` *(proposed,
    unbuilt)* — and design docs mark unbuilt proposals as proposals in the same line as the proposal, because that line
    is what gets copied.
85. **Probing that an engine feature *exists* is not probing whether we already *use* it — and I published a roster built
    on the first.** `algorithms.md` listed `PATH_POSTPROCESSING_CORRIDORFUNNEL` as **unused** and the funnel algorithm as
    **OWED**, on the strength of a `ClassDB` probe that showed the constant existed and a reading of our call site that
    showed we called the older `map_get_path(..., optimize=true)`. nav established the actual fact: **`optimize=true`
    *is* the corridor funnel.** We have had funnel smoothing since round 1. I had congratulated the file for being
    *"probed rather than read from docs"* — and the probe answered a different question than the one the row claimed.
    Worse, the row carried a **diagnosis** with it: *"waypoints are raw navmesh corners, so vehicles saw off turns."* The
    premise was false, so the diagnosis was too — the sawing was **steering at the corners**, fixed by round 6's carrot.
    **A wrong entry in a roster is more expensive than a missing one**, because it is quoted into briefs as a task
    (lesson 84) and it retires a real symptom under a wrong cause. I relayed it to two streams before nav corrected it.
    Three rules:
    - **For every "we don't use X" claim, name the call site that would use it and quote what that call site does.** Not
      the class, the call.
    - **The owner of the file is the authority on the file.** A roster written by the orchestrator is a *hypothesis list*
      until each row is confirmed by the stream that owns the code. Mark unconfirmed rows as unconfirmed.
    - **Keep the corrected row, struck through, rather than deleting it.** Same treatment as the retracted range finding
      in `game_design.md`: a deleted wrong answer gets re-derived, a visible wrong answer does not.
86. **A hand-over is only as available as its least-committed part, and the reference-patch mechanism hid that.** Round 7:
    nav diagnosed, fixed and *measured* the lead's loudest bug — scouts ramming their targets — then left a patch at
    `_agents/streams/references/nav/<name>.patch` for squad, because the hook lands in squad's file. squad accepted the
    design, agreed the test inversion, and stopped: **the patch references `CombatMotion.fixed_style`, which existed only
    in nav's working tree.** Not on `stream/nav`, not on `main`. squad could not compile, so it could not start.
    The mechanism was mine and so is the gap: I introduced reference patches so no stream would edit another's file, and
    **I never said the patch's dependencies must be committed first.**
    Worse, the *number* had already travelled. The measurement was written into `algorithms.md` and `game_design.md`
    while the code sat uncommitted — **a documented result nobody can reproduce**, which is the worst way to lose work.
    Rules:
    - **A reference patch must name the commit that provides every symbol it calls.** No commit, no hand-over.
    - **Commit before you measure, or at the latest before you report.** A commit is not a claim that the work is
      finished; it is the difference between a result and an anecdote.
    - **When a fix and an unrelated regression-repair are in the same working tree, make them separate commits**, so the
      orchestrator can merge the one that unblocks another stream without waiting on the one that is still validating.
    - Corollary for me: **when a stream reports a result, ask where the code is in the same breath as asking the hash.**
87. **A readiness check built on a *property* rather than an *identity* passes for the wrong object — and making the
    property more specific never ends.** arena's words, and they are the best-stated instrument lesson this project has
    produced:
    > *"`ArenaFixture` could not tell two arenas apart when both came from the same base layout. Its readiness probe was
    > 'a point inside this layout's cover is off the mesh' — equally true of the **previous** arena's navmesh. So a test
    > that varies only `terrain` or `shape` silently measured the arena before it. That is the fourth time this stream has
    > met the stale-navmesh bug, and the fix is finally general: wait until the map's regions are exactly this arena's,
    > which is identity rather than a proxy. Every previous fix of mine made the property more specific; only identity
    > ends it."*
    **The escalating-specificity path has no end, because every property is shared with something.** Four rounds of
    tightening a proxy, and the bug returned each time under a narrower disguise. Wherever a test waits for a thing to be
    ready, **wait on the thing's identity** — this map's region RIDs, this build's hash, this commit — not on a symptom
    that the right object and the previous object both exhibit.
    Two companions from the same message, both mistakes about **what the system already does** rather than what it should:
    - arena asserted the navmesh stops at the perimeter wall. **It never has** — on foundry the mesh is still 0.5 m away
      at x = 155, 35 m outside the wall; units simply cannot reach it because the walls enclose them. **A test asserting a
      behaviour the game has never had is worse than no test**: it passes the day it is written and fails the first time
      somebody fixes something unrelated.
    - the arena bound is a **square extent, not a radius** — today's square already has corners 164 m from the centre, so
      "fit inside a 120 m circle" would have shrunk the existing arena for no reason. **Check whether a limit is an
      extent or a radius before building geometry against it.**
88. **A constraint that lives in the contents does not show up when you look at the container — and a well-phrased
    argument is the hardest kind to check.** Round 7, the hexagon sizing, and it went wrong twice in an hour.
    feel's wall module implied a hexagon **139.7 m** across. arena "corrected" it to **120.0 m** on a convention
    argument — a regular polygon's vertices sit further out than its flat sides, so building to the apothem would push
    the arena past a radar and fog sized for |x| ≤ 120. Clean reasoning, and I approved it in one step. **Then arena went
    to build it and the armies did not fit: a square keeps its full width to the wall, a hexagon narrows, and the spawn
    block sits exactly where it narrows.** Foundry's rows at z = 98, 106 and 114 fall outside a flat side at 103.9 m —
    **48 of 104 spawn points inside the arena.** 139.7 m turned out to be the *smallest* clean-tiling hexagon that holds
    the spawn block. feel's number had been satisfying a constraint nobody had written down, and the correction removed it.
    Everything downstream of the wrong size was also wrong: the area reduction was reported as **35%** and is **12%**;
    the approach-length worry that reduction raised **does not arise at all**, because the spawn rows do not move in
    either shape, so base-to-base is unchanged by construction.
    - **Before accepting a change to a container's dimensions, enumerate what has to fit inside it.** Spawn points,
      formations at their widest, the largest hull, patrol routes. Geometry arguments are about boundaries; games are
      about contents.
    - **arena's own pattern-match is the valuable half:** the same stream had just asserted the navmesh stops at the
      perimeter wall (it never has — the mesh extends 35 m past it), which is *also* a claim about a boundary made
      without checking what happens at it. **Two confident geometry errors in one day, both container-shaped.**
    - **And the phrasing is part of the failure.** arena's case rested on *"five things move so one number can stay
      round"*, which is persuasive, memorable, and does the work of an argument without being one. arena's note:
      *"That phrasing was mine and it was persuasive, which is part of why I should have checked it harder."* **When a
      recommendation arrives with a good line in it, that is the moment to ask for the measurement** — the line is
      evidence about the writer's fluency, not about the world. I relayed it to feel inside a minute.
89. **A scalar bound is a hidden claim about shape, and it survives the shape changing.** Round 7: the arena became a
    hexagon, `ARENA_HALF_SIZE` went 120 → 140, and the break was none of the constants anyone listed. combat found it:
    **`DRIVABLE_LIMIT` is used as a *square* clamp in six places** — `absf(x) > LIMIT or absf(z) > LIMIT` three times in
    `arena.gd`'s validate, and `clampf` in `orders.gd`, `rts_controls.gd` and `army_layout.gd`. A hexagon of circumradius
    139.7 m has an **inradius of 121.0**, and **a square clamp at ±136 permits points 192 m from centre on the diagonal.**
    Every one of those sites would have placed an obstacle, clamped an order or laid out an army outside the playable
    arena, **and the validator would have approved it.**
    combat's statement of it is the one to keep: *"the container question is 'how big is the arena' and has a clean
    answer; the contents question is 'is this point inside it' and no longer has a scalar answer at all."*
    - **Six call sites each held a private copy of the assumption "the arena is a square."** That is lesson 66 with a
      *shape* as the duplicated value instead of a number, and it is why the fix is a contract (M4
      `Arena.contains`/`clamp_into`) owned by the stream that owns the shape — not six corrected clamps.
    - **⚠ The proportional-scaling trap, and I would have walked into it.** The safe inscribed limit for a 139.7 m
      hexagon is **117**, barely different from today's 116. Scaling 116 → 136 alongside `ARENA_HALF_SIZE` makes the
      clamp **three times too permissive rather than slightly.** *When a constant's units are metres, "scale it with the
      thing it came from" is only right if the thing it came from kept its shape.*
    - Second time in one day that a proportional scaling would have been wrong, both mine to catch.
90. **A tool that cannot express a configuration produces numbers that silently claim generality.** combat, unprompted:
    `faction_matrix.py` passed **no `--arena`**, so **every faction number this project has ever quoted — the gangs at
    53%, the heights null, the designator run — is a *foundry* number, and nothing in the tool's output said so.** Fixed
    at `c2b27516`: it takes `ARENA=`, names the map in its header, and writes a per-arena file; `balance.md`'s rows are
    relabelled *"on foundry"*.
    **The numbers are not wrong, and that is what makes this subtle.** Every arm of every A/B ran on the same ground, so
    each comparison is sound. **They become unsound the moment an effect is conditional on terrain** — which the
    designator's is, since acquisition speed pays off where sightlines are long. A result that is valid as a difference
    was being read as a property of a faction.
    - **Every instrument must print the configuration it ran in**, not just its result. This is the measurement half of
      *every number carries its commit and its machine*: it also carries its map, its seed count, and its unit count.
    - **The deeper point is combat's:** *"that is the per-map breakdown you asked for, and I could not have produced it an
      hour ago because the tool could not express the question."* **When a question cannot be asked, its answer defaults
      to whatever the tool happens to do** — and nobody notices, because there is no error, only an unmarked default.
91. **A check that skips is not a check that passes — and this one is silent on the machine where a human would notice.**
    `sim-baseline` keys the recorded hash per glibc version. **builder0 is `glibc-2.43`; our laptops are `glibc-2.39`, and
    there is no 2.39 line** — so locally the target prints `sim-baseline SKIPPED: no baseline for glibc-2.39 (got
    695f9709a11197e4)` **as information, and exits 0.** It passes on a laptop no matter what changed, and fails only on
    builder0.
    combat's sharpening is the memorable form: **the one machine where a human is most likely to notice is the one
    machine where the check says nothing.** Everyone develops on the laptop; only the merge gate can fail. **A skip that
    is invisible is worse than a failure**, because a failure is investigated and a skip is read as a pass by everyone who
    is not looking for it.
    - **Any check that can skip must be able to say so loudly.** A skipped guarantee should be reported in the summary
      line — `N passed, M failed, K skipped` — not left in the scroll-back.
    - **Prefer a check that cannot skip.** A per-machine baseline is a design that guarantees this failure mode; a
      machine-independent invariant (fixed-point, or a hash of decisions rather than of floats) would not have it. That is
      already in `determinism.md`'s future work and this is another argument for it.
92. **Deferring a shared fix costs nothing to whoever defers, so it always looks cheap.** I read invariant 2's *"the sim
    baseline is recorded once, after the last simulation-changing merge"* as permission to defer to round close, merged
    two sim-changing branches to `main`, and left **`main` red on `sim-baseline` for hours.** Every stream that merged
    `main` afterwards inherited a failure that was not theirs, could not attribute it, and had to ask me.
    I had also been attributing the total absence of green hashes that day **entirely to builder0's queue**, which is the
    second-order damage: **a known-bad shared state becomes the explanation for everything, so nothing else gets
    diagnosed.**
    combat's framing is the transferable one: *"a rule whose cost falls entirely on people who did not make the decision
    will always look cheaper than it is."*
    - **When a rule defers work, ask who pays during the interval.** If the answer is "everyone but me", the rule needs a
      deadline, not a milestone.
    - **Two cheap fixes, both now in invariant 2:** record in the same *session* as the merge, not at round close; and
      **say "this moves the sim baseline" in the merge commit**, so a stream can answer the question with
      `git log main --grep` instead of a round trip.
    - **And beware an over-determined failure standing in for evidence.** combat's branch carried three of its own
      hash-moving changes, so its `sim-baseline` failure was *"consistent with both stories and evidence for neither"* —
      combat said so rather than letting me quote it as confirmation. **Only a check on `main` establishes `main`.**
93. **A silent lookup in a keyed table produced this project's longest-running false finding — twice.** combat, round 7:
    `Army.squads_for()` loops **`for role in SQUADS`** — it iterates the *table*, not the units. **A unit whose role is
    not a key in that table is silently dropped from every generated army.** No error; the army still builds; one unit
    type simply never appears. So re-roling the Lance Platform from `"lancer"` to `"designator"` **deleted it from the
    Syndicate**, which then fought 60 matches with four unit types instead of five.
    **The same table caused the gangs' 23%.** Its own comment records it: the gangs' rat rods were given the Condemned
    scout's *spotters-first* directive, so 15 assault vehicles sat at standoff range while the swarm died. We treated that
    as a faction balance problem across two rounds and later watched it "dissolve" to 53%. One table, two silent
    failures, two multi-round false findings — a *wrong* value the first time and *no* value the second.
    **I first wrote here that the 23% "was never real". combat corrected me and the correction is the better lesson:**
    > *"The 23% **was** a real measurement of a real build. What it was never is a **property of the faction**. A build
    > in which 15 assault vehicles sit at standoff spotting while the swarm dies really does win 23%; that is a true
    > number about a broken army, not a false number. The error was treating a measurement of a configuration as a fact
    > about a faction — the same error as reading a foundry number as a property of the game. 'Never real' invites the
    > reading that measurements lie, and this one did not."*
    **That is the unifying form of lessons 90, 93 and 94: every number here is a measurement of a configuration, and
    almost every mistake in this project has been promoting one to a property.** The defence is that an instrument prints
    the configuration it ran in, so the promotion has to be done deliberately rather than by omission.
    **Timeline established (combat, `git log -S`), and it is worth keeping because the shape recurs:** `f1b0ee9e`
    **reports the 23% and adds the `gangs/scout` entry in the same diff** — the run found the bug and the fix was written
    in response. No faction matrix ran again until `1333cc73` two days later, which measured 53%. So the fix precedes the
    recovery — **but the gap also contains the `ready_to_fire` tick, armies holding until ordered, 30 Hz, Jolt and all of
    CP4.** The directive bug is an **unexcluded candidate, not a demonstrated cause**, and neither is the mechanics story.
    **The settling move is the ablation this project already knows to run (lesson 25): delete the `gangs/scout` entry on
    the current build and re-run the matrix.** A direct test beats an inference from a timeline, and it costs one
    60-match run.
    - **Any lookup keyed by a value from elsewhere needs a test that every possible key resolves.** combat's
      `test_every_roster_role_can_be_put_in_a_squad` walks every roster unit and asserts its role has a `SQUADS` entry —
      and it is **mutation-checked**: combat removed the entry and watched it fail, naming the unit. **A test you have not
      seen fail is a test you are hoping about.**
    - **Iterating the table instead of the contents is the code smell.** It makes absence unrepresentable and therefore
      unreportable.
    - **Orchestrator's share, and it is the real one: I made the re-role decision and never asked what else was keyed by
      role.** Same failure as the hexagon (*what has to fit inside it?*) and the baseline (*who pays during the
      interval?*), three times in one day: **approving a change by evaluating the change and not its surroundings.**
94. **A confound is only investigated when it pushes the wrong way, so the dangerous confounds are the plausible ones.**
    combat looked for the bug above **because the designator — a pure buff — measured as making its faction slightly
    worse** (43% → 40%). Its own words: *"I could have written a tidy paragraph about how an acquisition buff might
    backfire."*
    **Invert it and nothing happens.** Had the missing unit made the Syndicate look *better*, or had it been dropped from
    an opponent, the identical bug would have produced a believable number with a good explanation attached, and it would
    have travelled: stream → orchestrator → lead → design decision. **Our whole error-detection process is "does this
    surprise me", which is exactly blind to confounds that produce expected results.**
    - **The defence is not more scepticism about surprising results — it is guardrails that fire without anyone being
      suspicious.** A test, a printed configuration, an assertion that every key resolves. Suspicion does not scale;
      mutation-checked invariants do.
    - **Corollary for reporting: a result in the expected direction deserves the same confound hunt as a surprising one**,
      and it will not get it unless the hunt is a checklist rather than an instinct.
95. **`make check` stops at the first failing target, so one known failure silently hides every target after it — and
    `N passed, 0 failed` still reads as comprehensive.** Round 7, found by control while reading its own check #17 rather
    than reporting it. With `sim-baseline` red on `main`, the four targets that follow it — **`garage-smoke`,
    `army-loop-smoke`, `announcer-check`, `audio-check`** — **never ran.** From outside, *"`sim-baseline` was the only
    failure"* and *"`sim-baseline` was the last target that got a chance to fail"* are **indistinguishable**.
    **The orchestrator's error, and it was broadcast:** I told five streams *"if `sim-baseline` is the only failure, treat
    the tree as green."* That instruction **converts an incomplete result into a complete one by assertion.** Worse, the
    hidden targets were in each case **the ones most relevant to the stream's own diff** — `army-loop-smoke` exercises the
    relaunch path control's loading screen sits on and the match setup squad's army layout runs in; `announcer-check` and
    `audio-check` are feel's; `garage-smoke` and `army-loop-smoke` are where combat's designator changes *when units fire*
    across a loop of matches. **A truncated run is least informative precisely where it matters most.**
    - **Never read a partial run as a pass.** The operational form: **run every target *except* the known-bad one**
      (control's `#18`), which is conclusive, rather than running all of them and excusing one, which is not.
    - **A summary line must count what it did not run.** `N passed, M failed` with four targets unattempted is a true
      sentence that misleads. `N passed, M failed, K not run` would have made this self-evident.
    - **⚠ AMENDED, combat: it is not "the four after `sim-baseline`" — it is "everything after whatever fails first".**
      `check` is `lint test net-smoke … determinism sim-baseline garage-smoke …` and **`test` is second.** combat's
      `d21a3d86` failed inside `test`, so **`sim-baseline` and the four after it never ran either** — that run established
      *lint passed, `test` has one failure, and nothing whatsoever about the other eleven targets.* **A stream reading
      `>> exited 2` cannot tell how far it got without counting targets in the log**, so the abort position is itself
      invisible. Any instruction of the form *"if X is the only failure…"* is therefore unsound on this Makefile,
      whatever X is.
    - **Fix the shared breakage instead of teaching everyone to read around it.** Five *"here is how to interpret the
      failure"* messages were the wrong response to *"the baseline needs re-recording"*, and they cost more than the fix.
    - **The generalised orchestrator failure, third instance in one day:** relaying the lancer deletion as settled before
      it was implemented; relaying a container argument without checking its contents; relaying a truncated check as
      green. **One mechanism — promoting something provisional to something established at the moment of relaying it.**
      That is a relay failure, not a judgement failure, and it needs watching for by name.
96. **Summarising and asserting are the same word in the output, which is why a relay failure is invisible to the
    relayer.** combat, on my three relay failures in one day: *"Promoting something provisional to something established
    at the moment of relaying it is invisible **because the compression is the job.** You cannot relay six streams'
    states without discarding detail, and 'treat a single known failure as green' is a perfectly good summary right up
    until the discarded detail is the load-bearing part. The failure mode is not carelessness — it is that summarising and
    asserting look identical in the output. A summary that says 'green' and a judgement that says 'green' are the same
    word."*
    **The conclusion is the important part, and it arrived from two directions at once:** *"make the artefact carry its own
    conditions… **you cannot fix a relay by trying harder at the relay**."* Every fix that worked today was of that shape
    and none of them were about diligence: `ARENA=` printing the map in the header; an instrument printing its
    configuration; a merge commit declaring that it moves the sim baseline; `git show HEAD:<path>` instead of trusting the
    working tree; a reference patch naming the commit that provides its symbols. **Each removes something the relayer
    would otherwise have to remember to say.**
    **And the cost structure is what made this one expensive.** Five streams each received the unsafe rule **separately
    and privately, with no way to compare notes.** combat had independently hit the same problem that morning — it ran the
    skipped targets by hand after a `sim-baseline` failure, on the principle *"a check that skips is not a check that
    passes"* — and **did not flag my rule as unsafe, because when I gave it, it matched what combat had already done.**
    Two agents each held half of it. **A worker who has solved a process problem should assume the orchestrator has not**,
    and say so; and the orchestrator should ask *"has anyone already hit this?"* before issuing a reading rule, because in
    a star topology only the centre can connect two halves — and the centre is the one who was wrong.
97. **The thing that moves the code to the machine is the thing that strips the identity of the code.** combat built the
    mechanical guard for mismatched comparisons — `tools/run_conditions.py`, so `faction_matrix` and `engagement_report`
    print `run: <machine> at <commit>` and record `{machine, commit, dirty}` in their json — and found while checking it
    that **`tools/remote.sh` excludes `.git/` from its rsync.** So on **builder0, where nearly every measurement this
    project quotes is taken, there is no repository to ask**, and a naive helper would have printed `commit: unknown`
    exactly where it matters most. Fixed in `remote.sh` (orchestrator's file): the commit and dirty flag are captured
    locally and exported into the remote environment, with the helper falling back to git when run locally.
    - **`dirty` is the load-bearing field, not `commit`.** An rsync carries uncommitted changes, so on a dirty tree the
      commit **does not identify what ran**. combat made the helper shout about it — the case most worth seeing and the
      easiest to miss, since a dirty tree is the normal state of a working stream.
    - **combat found it by checking whether the helper worked *remotely before* wiring it in**, not after. A guard that is
      only exercised in the environment it was written in is untested where it is needed.
    - **The general form: every transport boundary is a place where context is silently dropped** — rsync without `.git`,
      a pipe that loses an exit code, a patch that loses the commit providing its symbols, a summary that loses which
      targets ran. **Name what each boundary drops, and carry it explicitly across.**
98. **Agreement reached from different premises looks identical to agreement, and it is the cheapest place to lose a
    finding.** combat's mirror of *a worker who has solved a process problem should assume the orchestrator has not*:
    > *"When an instruction matches what you already do, that is the moment to check whether it matches for the **same
    > reason**. Mine matched your rule by coincidence — I had run the skipped targets because I distrusted the skip, not
    > because I knew the abort position was invisible."*
    combat had been running the masked targets by hand since that morning. My unsafe rule — *treat a single known failure
    as green* — **produced the same behaviour from a false premise**, so there was nothing for combat to object to, and the
    finding stayed put until control hit it independently. **Two agents each held half and the agreement hid the gap.**
    - **When you find yourself agreeing with an instruction, state your reason, not your assent.** *"Yes, I already do
      that, because X"* exposes a mismatched X; *"yes"* does not.
    - This is the social form of lesson 47 (*a guarantee no test isolates*): **a shared conclusion with unshared reasoning
      is a guarantee nobody is checking.**
99. **The fix for "the wrong answer and the right answer are indistinguishable at the point you look" is never a better
    property — it is finding something that can only be true of the right object.** arena's generalisation, drawn from
    **four separate defects found in a single day**:
    - `ArenaFixture`'s readiness probe — *"a point inside this layout's cover is off the mesh"* — was equally true of the
      **previous** arena's navmesh, so a test varying only `terrain` or `shape` measured the arena before it (lesson 87).
    - the perimeter span symmetry rule agreed with itself for a **centred** gate, so it could not detect an asymmetric one.
    - `sim-baseline` locally **skips and exits 0** on a glibc with no recorded line, so it passes identically to a real
      pass (lesson 91).
    - a truncated `check` and a complete one are **byte-identical in their summary line** — there is no `N of M targets`
      anywhere, so the only way to tell them apart is to know the target order and find where the output stops, *"which is
      exactly the kind of thing nobody does when the last line says what they hoped"* (lesson 95).
    **Every one was fixed by tightening a property, repeatedly, and every one came back.** The pattern that ends it is
    **identity**: wait for the map's regions to be *exactly this arena's*; assert the preview came *from the planner*;
    verify `git show HEAD:<path>` rather than the file on disk; print `run: <machine> at <commit>`. **Ask of any check:
    what else in the world satisfies this? If the answer is "the previous version of the thing I am testing", it is not a
    check.**
    **Applies to test design too, not just instruments.** Round 3's `runs >= 3` was a property the *buggy* scout satisfied;
    *"never inside the ram gap, most of the time in band and nose on"* is one **only the correct behaviour** can satisfy.
100. **Credit the mechanism, not the instinct — including when a stream declines the credit you offered.** I praised arena
    for holding out for a conclusive run (*"nothing of mine should merge until I send the wrapper line"*) and treated it
    as foresight about the truncation problem. arena corrected me:
    > *"My 'nothing merges until I send the wrapper line' was about **my** uncertainty, not foresight about yours — I had
    > no idea `check` stopped at the first failure until you told me. **The instinct was right for the wrong reason**,
    > which is worth recording accurately if it goes in the lessons."*
    **A lesson file that credits instincts teaches people to have hunches; one that credits mechanisms teaches people to
    build guards.** And the accurate history matters here: what actually caught the truncation was **control reading its
    own check output carefully**, not anyone's caution. **Recording the wrong cause of a success is the same error as
    recording the wrong cause of a failure** — see the gangs' 23%, where an unexcluded candidate was reported as a
    demonstrated cause in this very document.
101. **Assert that the treatment engaged — a measurement cannot otherwise tell you that the thing you meant to measure is
     the thing that ran.** combat's framing of the gap, after two designator runs in one night measured a different game
     than it thought: first the unit **was not on the battlefield at all** (silently dropped from every army by a keyed
     table), then it **was on it wearing the wrong hat** (role `"designator"` put it outside `FRAGILE_ROLES` and
     `PROTECTED_ROLES`, so the CPU front-lined a spotter). **Both were found by a result looking slightly wrong, not by any
     check** — which is lesson 94's trap: the same bug pushing the plausible way would have shipped.
     **The answer is the clinical-trial idea of adherence: you do not report a drug trial without checking the patients
     took the drug.** So the harness **counts the mechanism's own events and refuses — not annotates, refuses — to report a
     treatment arm showing zero.** A treatment arm with no treatment is **not a null result, it is a failed run**, and
     that distinction is what cost two runs. Built at `e0f6ce40`.
     - **Every A/B in this project should assert its treatment engaged.** The standoff run counts scouts entering the
       standoff state; the `gangs/scout` ablation asserts the entry is genuinely absent from the tree that ran.
     - **arena's extension is the general form and the one to copy:** *"assert the map is the one named, the objectives are
       where the layout says, and the armies are the size requested — inside the probe. Every wrong number this stream
       produced today would have been caught by one of those three."*
     - **The distinction that makes this more than hygiene:** `run: <machine> at <commit>` proves **which build**; a
       positive control proves **which behaviour**. Conditions *around* the run versus conditions *inside* it — and only
       the inside version survives someone changing the setup, including an agent who has never read this file.
102. **A new value in a keyed system is an interface change, not a value.** combat, having authorised-by-me a re-role of one
     unit, went looking for how many places would need editing and found **eight lists across four streams**:
     `Units.ROLES` · `Army.SQUADS` · `SquadTactics.FRAGILE_ROLES` · `TacticsFormation.PROTECTED_ROLES` · `CpuCommander`'s
     line/support split · `ElementSituation` · `ArmyCatalog.ROLE_LABELS` · `command_icons`. **None reference a single
     registry.** Adding a role means editing eight independent lists owned by four people, and missing one fails either
     **silently** (the army drop) or **obscurely** (a missing icon).
     **combat's statement: *"a value that eight places key off is not a value, it is an interface"* — and this one has no
     owner, no registry and no enforcement.**
     - **The fix that worked was not doing it.** Designation is a **capability**, not a taxonomy: `role` stayed `"lancer"`
       and the unit carries `"designates": true`. All eight lists keep working untouched, the `SQUADS` entry became
       unnecessary, and the faction kept five roles **without a re-role at all** — a strictly smaller change than the one
       the orchestrator authorised. `game_design.md` already said *"the role is shared across factions, the vehicle is
       not"*; nobody applied it.
     - **Stopping one fix into an eight-fix patch is the hard part.** combat was at 1 a.m. with seven edits to go and went
       backwards instead. **When the cost of a change is discovered to be eight times the estimate, that is data about the
       design, not a reason to push on.**
     - **Orchestrator's share: I approved "re-role it" while thinking about art budget, and never asked what `role` was
       load-bearing for.** Fourth instance in one day of approving a change by evaluating the change and not its
       surroundings.
103. **A control must state the condition it checked and what it refuses to report — never *why* the condition matters.**
     arena's new `nav-maze` control fired correctly on its first run and printed: *"8 pairs of units started on top of
     each other — spawn slots wrapped, **and those hulls cannot move, so every arrival number below would be wrong**."*
     The assertion was right. **The explanation was a round-6 fact in the present tense**: coincident hulls have parted by
     name since `e291a35a` (`avoidance.gd:204`), on `main` since `7cce78af`. In round 5 they genuinely never moved — 8 of
     the 20 non-arrivals in arena's own baseline — and the sentence outlived its cause.
     nav settled it with arithmetic rather than a claim about whose tree was whose: **the probe counts all 60 units and the
     8 wrapped pairs are 16 of them, so if those hulls could not move, at most 52 of 60 could arrive. 60/60 means all 16
     moved.**
     **A stale diagnosis in a failure message is worse than one in a document, because it arrives at the moment someone is
     deciding what to do.** I read it, immediately suspected nav's validation, told nav its numbers might be void, and
     offered to hold a commit out of the merge queue. **The control was right and still nearly cost a merge and a
     retraction — because I believed the explanation, not just the assertion.**
     - **Write:** *"8 pairs started on top of each other: spawn slots wrapped, so this run is not the experiment named (60
       distinct start points). No number written."* Permanently true, and it invites no conclusion about movement.
     - **And fix the cause rather than downgrading the check.** nav offered "make it a warning"; the condition genuinely is
       violated, so **refusing is right and the fix is to give the probe 60 distinct start points.** A warning is the
       invisible-skip failure of lesson 91 wearing a different hat. **Fixed at `c2ed5b3c`**: surplus units are offset half
       a column sideways, so 60 means 60 distinct start points, and the control passes at 30 and 60, one-way and head-on.
       arena then **added a condition for the fix itself** — *every unit must start on the navmesh* — because shifting a
       hull sideways could put it inside cover on a layout with a tighter spawn zone. **A fix to a setup deserves its own
       assertion, since it is exactly the change that breaks something quietly.**
     - **⚠ The detail that stings, in arena's words: *"I copied a finding from the very stream that had since fixed it."***
       The sentence came from nav's round-5 report, and nav fixed the cause in round 6. **Copying a peer's finding copies
       its timestamp, and nothing in the copy carries it.**
     - **arena produced four distinct forms of lesson 84 in a single day**, which is worth listing because they look
       unrelated until they are side by side: a **proposal read as a description** (`balance.md`'s physics layer 4); a
       **legacy constant surviving inside something that looked updated** (the plot's `direct_route_exposure`); a **metric
       name promoted from configuration to property** (`centre_sees_share`); and a **fact copied forward past its fix**
       (this one). **All four are a claim that outlived its conditions**, which is the same disease as promoting a
       measurement to a property (lesson 93) — and it is the single most common failure in this project's history.
     - **And the unforeseeable payoff, which arena rightly says nobody would have argued for in advance: the positive
       control generated a test in another stream's paths.** arena built probe hygiene; nav saw that **wrapped spawns also
       happen in real matches — respawns, big armies — so "coincident starts separate within N s" is a behaviour test for
       the thing that actually matters.** An assertion about an experiment became an assertion about the game.
104. **Refuse to *persist*, not merely to *print*. A printed refusal can be scrolled past; an absent file cannot be
     cited.** combat's positive control refused to print a result; arena's refuses to write the JSON at all. combat adopted
     arena's version on seeing the difference: *"a refused run cannot end up in `references/` by someone copying the last
     file they see."*
     **And the two controls caught different classes, which is the argument for having both:** combat's caught a
     **treatment that never engaged** — a missing effect. arena's caught a **control arm that was silently broken**, which
     is worse, *"because a broken control does not look like nothing, it looks like a result."*
105. **Being protected by an unexamined habit is not the same as being safe, and it feels identical.** combat checked its
     own exposure to the notification trap and found its waiters read the wrapper's line correctly — then reported *why*:
     > *"not because I had reasoned about the notification. I built those waiters that way because the wrapper's line was
     > what `CLAUDE.md` told me to read on my first hour, and I never revisited it. **I was protected by a habit I had not
     > examined** — exactly the position you were in with the rule that matched what I already did. I would have been
     > vulnerable the first time I wrote a waiter that polled a notification instead of a log, and nothing in my process
     > would have stopped me."*
     **This is lesson 98 from the inside.** Agreement from unshared premises is invisible; so is compliance from an
     unexamined premise. **When you find you are already doing the right thing, ask what would have to change for you to
     stop** — if the answer is "nothing in particular", the protection is luck with a good track record.
     **Four instances today of one shape and one defence.** A faction number with no map, a truncated check, a container
     argued without its contents, and an `exit code 0` from the wrong process: *the wrong answer and the right answer are
     indistinguishable at the point you look*. **Every defence that worked made the channel carry what it is about** — the
     wrapper line names the target, `run: <machine> at <commit>` names the build, the positive control names the behaviour.
     **None of them are vigilance.**
106. **Pre-register the decision rule before running the experiment. It costs one sentence and it is the only defence
     against interpreting a result after it arrives.** nav, before building a commitment term in `CombatMotion`:
     > *"The decision rule, stated now so I can't move it later: if commitment cuts churn and survivability doesn't get
     > worse beyond seed noise, it ships and the churn was not the price of not dying. If survivability drops, evasion is
     > load-bearing, and I tell you the fix is legibility (control) with the numbers."*
     **Every measurement failure this round was a result interpreted after the fact**, and each had a plausible story ready:
     the designator's 43% → 40% was one paragraph away from *"an acquisition buff can backfire"* (it was a missing unit);
     the gangs' 23% → 53% became *"a balance problem dissolved by mechanics"* (it may be a bug fix, and the ablation is
     still pending); my own n=2 range finding became design understanding and inverted at n=15. **None of those were
     dishonest. A result arrives with its explanation already forming, and the explanation is free.**
     - **A pre-registered rule makes a null result reportable and a bad result unspinnable.** It also forces the *acceptance
       criteria* to be chosen while they can still be chosen fairly — nav's include *survivability must not get worse*,
       which is the criterion an author hoping for a churn win would quietly omit.
     - **Pre-register a GUARD metric as well as a success metric — name what must NOT get worse.** nav's rule covered
       churn and survivability; the thing that actually moved was a third, **attack-move "progressing" 44% → 41%**, and
       the rule was silent on it. **A pre-registered rule protects only the metrics you thought of**, and the one that
       moved was the one closest to the lead's own complaint. nav reported it unprompted, against its own result, which
       is the only reason it is not lost — **but the practice should not depend on that.**
     - **Say the noise threshold in advance too** ("beyond seed noise"), because *"within noise"* is the phrase that
       absorbs an inconvenient result after the fact.
     - **This is the practice for every A/B in this project from here.** It pairs with the positive control (lesson 101):
       one asserts the treatment engaged, the other fixes what the answer means before you know it.
     **And nav's decomposition is the model for what precedes a fix.** Evasion split into **(a)** dodging a round actually
     in flight (`would_be_hit` against `IncomingFire`, reactive, load-bearing, never cut) and **(b)** timer-driven replans
     and strafe-side flips *with nothing incoming* — whose justification, spoiling a gunner's lead, **is real for tank
     shells at 60–70 m and weak against hitscan.** So a behaviour that pays for itself against one weapon class is being
     applied against all of them. **That is a falsifiable claim about where a cost is unjustified**, which is a far better
     starting point than "reduce the churn".
107. **An absolute timing budget is a claim about the machine, not about the code — and in this project it is a claim about
     other streams' activity.** control's `test_the_ui_stays_cheap_with_a_full_army_selected` asserted a 2.0 ms frame
     budget and failed at **2.33 ms** on builder0. Idle builder0 is about **0.65 ms**; the laptop measures **1.80** and
     **also tripped it at loads 4–8 (2.2–3.1 ms)**. **The old budget had 11% headroom**, so with six to nine concurrent
     remote runs — the normal state of a round here — it was one busy afternoon away from failing at any time, for reasons
     having nothing to do with the code under test.
     **The fix is to remove the variable rather than tune against it:** control's frame time is now divided by a **fixed
     reference workload timed interleaved with it**. Ratio 5.5–7.2 across loads 3–8, budget 8.0, and **mutation-checked —
     +1 ms in `summary()` gives 9.7 and fails.**
     - **A test whose result depends on a shared resource nobody owns fails in a way that looks like a code defect.** That
       is the same shape as the stale sim baseline, and both cost this project a day.
     - **The too-tight instrument was also hiding a real defect:** `summary()` sorted the selection **twice a frame**.
       Because the test could not separate *"the UI is expensive"* from *"the machine is busy"*, nobody could act on it in
       either direction. **An instrument nobody trusts is worse than none, because it also excuses what it should catch.**
     - **Suspect every wall-clock assertion in the suite**, including generous-looking ones: `match-smoke`'s `speedup > 2`,
       any per-tick budget, and latency tests. A fastest-of-N sample reduces noise but is **still absolute** — control
       measured a **24 ms** excursion on ~4 ms of work, a 6× outlier.
     - **Prefer a ratio, a count, or a comparison against a reference measured in the same run.** *"Every number carries
       its machine"* (CLAUDE.md) is the reporting rule; this is its testing counterpart — **a number that must not depend
       on the machine should not be measured in units the machine controls.**
108. **A guard runs on the hot path of every future run, so it earns MORE end-to-end exercise than the thing it guards, not
     less.** combat, reporting its own: **the positive control it added to `faction_matrix` crashed every run it had been
     written to protect** (fixed at `9821cac7`), **and its refusal path called `main()` bare, so `return 2` exited 0 — a
     refusal that reported success to `make`.**
     **A guard that reports success when it refuses is the exact inversion of its purpose**, and it is the third instance
     in one day of **an exit status belonging to the wrong thing**: `tail`'s status reaching the harness's task
     notification; `make check` aborting at target two while printing `1135 passed, 1 failed`; and now a refusal returning
     0. **`exit code 0` keeps arriving from somewhere other than the thing we asked about.**
     - **Mutation-check every guard: make it fail on purpose and watch it fail.** Every guard that worked today was
       mutation-checked — arena watched its `nav-maze` control fail, control watched its frame ratio fail at +1 ms, combat
       watched `test_every_roster_role_can_be_put_in_a_squad` name the offending unit. **The ones that bit us are the ones
       nobody watched fail.**
     - **Exercise the refusal path, not only the pass path.** A guard has two outputs and the interesting one is the one
       that stops a run. In Python, `sys.exit(main())` — never a bare `main()`.
     - **We have been treating guards as if writing them were the work.** A guard is infrastructure: it is in front of
       every measurement forever, so a defect in it is a defect in everything downstream.
     - combat also scanned the other `tools/*.py` for the same shape and explained why `ai_ladder.py` and
       `tactics_ladder.py` are false positives (numeric returns are scoring helpers, not error paths). **Saying why a grep
       hit is not a hit is what turns a grep into a check.**
109. **A rule whose trigger word is optional is a rule nobody can follow reliably.** The worker contract says *merge `main`
     only at announced checkpoints*. I told all six streams *"merge `main` into your branch for the baseline"* — which
     **was** the announcement — and combat then reported itself for a contract violation and offered to reset its branch.
     **It had done exactly what I asked, in response to my own instruction, and could not tell that the instruction was an
     authorisation** because I had not used the word.
     **Third time in one day a stream was more careful than the orchestrator.** The fix is mine and it is mechanical: **say
     "this is an announced checkpoint" in those words, and name the commit.** `b70608d6` is one.
110. **A rule taught without its purpose gets applied where it does not fit — state what every proxy is a proxy FOR.**
     feel's `check10` ran every target to completion: `1142 passed, 0 failed`, `sim-baseline passed`, every smoke through to
     **`audio-check passed`** — and `audio-check` is the **last** target in `check`. Its wrapper then died before printing
     `>> remote: make check exited N`, and feel concluded *"by the rule, that's no verdict"* and discarded a forty-minute
     run on a saturated build machine.
     **feel was right about the rule and the rule was wrong here.** *"Read the wrapper's own exit line"* is a **proxy** for
     *did every target run, and did every target pass*. It exists because a piped exit code answers a different question.
     **A complete target list ending in the final target's pass is stronger evidence than the exit line, not weaker** — the
     exit line gives you a number, the target list tells you what happened.
     - **This is lesson 99 turned on our own process: prefer identity to property.** The exit line is a property that
       usually accompanies success; *"the last target passed"* is nearer the identity of green.
     - **The orchestrator's error: I taught the proxy for months without teaching what it stood for.** A rule stated
       without its purpose either lets something through or throws away good evidence, and there is no way for the person
       following it to tell which case they are in. **Every rule in this file that is a proxy should name its target.**
     - **It cost nothing here only because the run was on the wrong commit anyway** (`39dd5b2f` predates `cb171a98`, so it
       did not cover the second backwards vehicle). **That is luck, not process.**
111. **`make facing-audit` found four backwards-authored parts; the lead reported one.** The gang IFV (which he saw), the
     **Syndicate lancer**, the **gang tank's barrel** and the **Law rocket pod** — all authored pointing backwards, three of
     them never reported by anybody. **The argument for the audit was never "the lead complained"**; it was that **nobody
     on this project can inspect 21 units by eye** (lesson 72), so the only alternative to an audit is waiting for him to
     notice one at a time.
     **And the audit itself lied on its first run**, which feel caught from the renders: *"the tank drives its own turret
     back to rest, so the audit wasn't really showing 70°."* **An instrument that is asked for 70°, renders 0°, and labels
     the picture 70° does not error — it produces a plausible artefact.** Fixed by holding the turret at the angle asked
     for. **Fourth instrument defect found in one day**, and the fourth to be caught by someone looking at the output
     rather than by a failure.
112. **A constant in a test is a scale assumption, whenever the thing under test has a size.** combat, fixing arena's
     `test_a_hexagon_is_the_shape_that_varies_most`: it probed the pinch ratio at a **hard-coded z = 60 m**. The ratio is
     scale-invariant — hexagon 0.711, octagon 0.914 **at any bound** — but **60 m is a different fraction of a 140 m arena
     than of a 120 m one**, so at the new bound it read 0.753 against a 0.75 bar and failed. **It detected nothing except
     that the map had got bigger.** Fixed by probing at `bound * 0.5`, which reproduces the original numbers at every size.
     **The test was measuring the right quantity and sampling it in the wrong units** — and it would have been read as
     "the hexagon stopped being the shape that varies most", which is a design conclusion, from a change that was purely
     dimensional. **Express every test coordinate as a fraction of the thing's own size**, not in metres, unless the metre
     is the point.
113. **A change that invalidates another stream's file should land atomically with it, not as N requests plus a known-broken
     interval.** combat's `ARENA_HALF_SIZE` work made three readers wrong the moment the constant moved — `radar.gd`
     (control's), `agent_bridge.gd` (squad's) and its own `visibility_field.gd`. **It moved them with the constant rather
     than filing requests**, and said so unprompted, comment-tagged each *"owner, rewrite freely"*, and offered to revert
     them into requests if preferred.
     **That was the right call and the orchestrator's routing was the error.** I had already routed two of those same
     lines to their owners, so squad and control were each about to write a conflicting version of a one-line fix.
     **Nobody was wrong; I failed to tell combat that I had routed them.**
     - **The rule: if your change makes someone else's file wrong, fix it in the same commit, flag it in your report, and
       tag it for the owner.** The alternative is a window in which `main` is knowingly broken, which is worse than a
       boundary crossing.
     - **The orchestrator's rule: when routing a fix, say who else is touching that area.** In a star topology only the
       centre knows, and the centre is the one that has to say it.
     - **And the cross-cutting fix found a bug neither owner had:** `radar.gd` drew a square outline at ±`ARENA_HALF_SIZE`
       — **20 m outside the wall on every map ever shipped**, invisible because a square drawn slightly too large around a
       square arena still looks like a square arena. **The hexagon would have made a long-standing bug look like a new
       one.**
114. **"I cannot account for this process" is a reason to leave it alone, not a reason to include it.** combat, having
     positively identified which PID belonged to its live gate run, **killed its neighbours anyway on the assumption that
     anything older than the launch was stale — and one of them was the live chain.** Exit 143, gate lost, an hour gone.
     **Age is not evidence of staleness here**: checks legitimately run 30–50 minutes, so "older than my launch" describes
     most healthy runs on the machine.
     **The underlying footgun is real and is nobody's mistake:** `remote.sh` dying locally does **not** stop the `make` it
     started on builder0, so every killed or SIGTERMed run leaves a slot holder and a tree that the next `rsync --delete`
     overwrites underneath it. **A wrapper that trapped its own exit and stopped the remote job would remove the entire
     class** — round-8 work, deliberately not attempted mid-round, because `remote.sh` is the one tool all six streams
     depend on. **Do not rewrite the shared build tool while six streams are mid-check**; that is the same error as
     approving a change by evaluating the change and not its surroundings.
115. **Guard the treatment, not just the setup — and the general form is per-COMPARISON, not per-run.** arena, applying
     combat's positive control to its own `arena_series`: the assertion *"the match ran on the arena I asked for"* had
     existed since round 5, because `Arena` falls back to `foundry` on a layout it cannot load. **What was missing is that
     a fairness result is a *paired difference*, and a `--swap-bases` that silently failed to apply would leave two
     identical arms and a perfectly plausible "no south advantage."**
     **That is the answer we hope for, reached by the treatment never happening.**
     - **An assertion about the stage is not an assertion about the experiment.** Which map, which build, which commit —
       all necessary, none sufficient.
     - combat's own guard *"asks whether the treatment engaged in ONE run, and it would pass happily on two arms that were
       secretly the same arm."* **Neither tool checks that two arms actually differ, and that is the version worth
       building**: a comparison must assert that its arms are distinguishable before it reports a difference between them.
     - **Three distinct defects caught by this one idea in a single day, across three streams' instruments:** a treatment
       arm with no treatment, a control arm with immobilised units, and a paired comparison whose pairing might not have
       happened. **The third is the one nobody would find by inspection, because two identical arms produce a beautifully
       clean null.**
116. **Inertness does not compose.** combat, and it is the most useful sentence of the round: *"'A is inert' and 'B is
     inert' does not give 'A+B is inert', because A can be inert only in the absence of B."*
     Three streams each reported a green `sim-baseline` on their own branch. **`main`, after merging them, produced a hash
     none of the branches implied.** I wrote that up as an anomaly and messaged a stream suggesting its "clean control"
     claim might be wrong. **It was a correct claim about the tree it was measured on.** Each branch was measured against
     a *different* baseline, on a *different* tree, *alone* — and none of those measurements is a prediction about the
     composition.
     - **A branch's green `sim-baseline` predicts nothing about `main` after merge.** That is *why* invariant 2 puts the
       recording on `main` after the last merge; I had been following the rule without understanding it, which is why I
       was willing to treat its consequence as a contradiction.
     - **Same error as promoting a measurement to a property** (lessons 90, 93), in a new place: *"inert"* is a relation
       between a change and a tree, not an attribute of the change.
     - **And a change can be genuinely inert in BEHAVIOUR while not inert in the HASH** — arena's `_build_perimeter()`
       generates the wall from a polygon instead of authored boxes: identical geometry, **different collision bodies in a
       different creation order, which is enough for Jolt.** Expect it from any change to how the physics world is
       *built*, not just how it behaves.
     - **Orchestrator's error underneath it: I put a load-bearing fact — that the recorder rsynced before arena merged —
       in the last paragraph of a commit message**, and combat reasoned from the merge order in the log instead. **A fact
       that changes someone's conclusion goes first, not last.**
117. **The arm-distinguishability guard caught, on its first run, the exact failure it was built for — and it would have
     shipped a feature on a treatment that never happened.** nav's first commitment A/B came back with **both arms
     byte-identical on all five seeds**: same churn (15.71/min), same losses, same shot counts. `--nav-off=commit` had
     never applied. **Under nav's pre-registered rule — "if commitment cuts churn and survivability doesn't get worse, it
     ships" — that reads as *no worse, ship*.** Nothing was reported from the run.
     **Cause: a static-initialisation-order bug.** `CombatMotion.commit_on` was a `static var` initialised from
     `Movement._off`; `Movement`, `TankBrain` and `CombatMotion` reference one another, **so the initialiser can run before
     `Movement`'s statics are populated and see an empty switch list.** Fix: resolve switches at **read** time
     (`Movement.switched_off()` parses on first use), keeping the existing API shape so squad's call sites are unchanged.
     - **⚠ The same bug is already on `main` in `CombatMotion.fixed_style` (`2cae3bda`)**, where it is harmless only
       because the default is the wanted one and every test pins it by assignment — **but `--nav-off=standoff` from the
       command line silently does nothing.** `algorithms.md` and `game_design.md` both claimed that switch was available
       for A/B; **both are now struck through.** The standoff *measurements* stand: they were taken by assigning the style
       directly.
     - **This is lesson 25's trap, which `verification.md` already warned about in nav's own words** — *"a switch that
       silently does nothing makes 'no difference' meaningless — prove each switch moves some number first."* **The warning
       existed, was written by the stream that then hit it, and was not enough**, because it asked for a one-time proof
       when the failure is per-run. **Per-comparison, every run, or it does not count.**
     - **nav's guard is the right shape: the probe prints the treatment read LIVE FROM THE CODE** (`commit=…,
       fixed_style=…`) and the A/B target exits 1 if any seed's two arms print the same treatment line, or if every seed's
       results are identical. **Read the treatment from the running system, never from the flag you passed** — combat's
       formulation: *"a flag is what you asked for; `controls` in `MATCH_RESULT` is what happened."*
     - **Two streams independently built the same guard within hours, and it paid for itself immediately in one of them.**
       The generalisable claim is no longer theoretical: **of the first three comparisons this guard was applied to, one
       was already broken.**
118. **The untreated arms ARE the noise floor — measure it inside the run rather than arguing it from a formula.**
     combat's `gangs/scout` ablation: **that entry is the only faction-keyed one in `Army.SQUADS`, so only the gangs were
     treated and every other faction in the table is an untreated arm of the same experiment.**

     | faction | boulevard | yard | treated? |
     |---|---|---|---|
     | **gangs** | **+7** | **+7** | **yes** |
     | law | −7 | −10 | no |
     | condemned | +3 | +0 | no |
     | syndicate | −3 | +3 | no |

     **Law moved −10 points without being touched — larger than the treated faction's +7.** combat's framing: *"the noise
     floor is not an argument I am making; it is in the table, measured by factions that received no treatment."*
     **That is worth more than the SE (12.9 points at n=30), because it is measured in the same run, on the same machine,
     with the same workload** — it cannot be waved away as a modelling assumption, and it is legible to anyone reading the
     table. **Whenever an experiment has untreated subjects, report them; they are a free control.**
     - **And the conclusion was "cannot resolve", offered with a price:** ~n=400 per faction per arm, about SEEDS=70 and
       **four hours of builder0**, for an effect smaller than any balance difference the lead would notice. **A costed
       "cannot resolve" is a better deliverable than a fifth run with the same error bars**, and combat recommended
       against spending on its own stream's most-cited result.
     - **RETIRE a number that cannot be reconstructed rather than explaining it.** The gangs' 23% → 53% was this project's
       most-cited result and the evidence for *"a balance problem dissolved by mechanics"*. The original comparison was
       most likely **never a comparison** — different builds, and plausibly different maps. **That is precisely the
       subtraction `compare_arms` now refuses and could not refuse then.** The principle it supported survives on the
       sharper argument: *do not tune against numbers whose cause you have not established.*
