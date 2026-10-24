> **ARCHIVED (round 38 closed 2026-10-23).** The branch becomes `round38/doctrine`; its unmerged references stay on that branch. Round 39's brief is `streams/doctrine.md` where one exists.

# Stream: doctrine (the CPU defender stops, holds and shoots first)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.2) and
> in *Round 37*: CP37.1, R37.14 (the guard lines' base), R37.22-R37.26 (the rules arms and the motion read), R37.44 (Bar K). Then
> `game_design.md` *OPEN QUESTIONS for him before round 37* and *Summary of his answers*. Rules' close notes:
> `streams/archive/round37/rules.md`. **You own:** brains' paths (`game/ai/**`, `game/tactics/**` outside the carve-outs in
> workstreams *Round 38* Ownership), `tests/tactics/**`, `tests/test_tactics*.gd`, the `tests/ai_scenarios/**` scenarios you add,
> `tests/rules/**` re-reads, `mk/tactics.mk`. **Model:** FABLE. **Machine:** builder2 for guard-line series; builder0 light runs.

## The lead's direction

"How can we make it so that tactics and strategy can win out over a large frontal assault?" ... "in the real world, the defender
generally has an advantage" (round 36, game_design.md). His round-37 answers built rules that reward stopping (sight, accuracy, pinning,
hull-down); every one leaned the right way but none cleared noise because **the CPU defender itself keeps moving**. And his standing
rule: smart AI on both sides; symmetric AI improvements ship without asking.

What he will notice: a CPU force holding a zone stops in cover and shoots first; a blob of his (or the CPU's) charging it loses more
often than today; his own defending squads do the same when parked (settle owns "parked").

## Where things stand

- The guard lines (CP37.1): BLOB (his right-click, everything at once) wins 48 %, TURTLE 39 % against today's CPU (R37.14), paired
  320-fight reads with `tools/scoreboard/guard.py --pair`; guard.sh GUARD_CHUNK=2.
- The motion read (R37.26, `make rules-guard-motion`): blob fires faster than a crawl 70.1 % of rounds, the CPU 55.5 %, and the CPU fires
  41 % more rounds.
- Rules on main, OFF: `--rules-on=sight,spread,pin_slow` (R1-R3), `--cover-on=hulldown` (K2).

## Backlog (in order)

1. **D1 the read:** when CPU elements are tasked to HOLD / defend a zone, how often do their crews fire while moving, and why (which
   brain options move a holding crew: ENGAGE, SPOT, FLANK, re-seat). Design note to the orchestrator before code.
2. **D2 hold-and-fire:** a defending CPU element halts to fire (stops, uses cover seats, bounds only when it must), behind a switch;
   lab first; bar on the guard lines (deciding: the blob's win rate down; guards: the turtle not up, kills/length per faction, perf, and
   "the CPU still attacks when it is the attacker"). A pass ships ON (symmetric).
3. **D3 the re-read:** R1-R3 and K2 ON top of D2, each and as a package, on the same 320 fights.
4. **Stretch:** the CPU choosing low-cover seats when it defends (K5 maps have barriers).

## How to verify

Lab both paths; `make quick-remote`; guard-line series on builder2 (`make guard-run GUARD_ARGS=... GUARD_TAG=...`); every number with
commit, machine, workload, n. Smoke: `make skirmish ARENA=locks`, watch the CPU hold its zone.

## Don't touch

orders' control paths, settle's deploy/halt/seat functions and the parked-hold seam (merge notes), manoeuvre's movement blocks,
`game/match/**`, `game/combat/**`, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

**R38.55 (2026-10-23): R1-R3 ship ON by default (his direction call, game_design.md *His call on R1-R3*). GREEN:
95a3a8f54** (builder0 `make check exited 0`, 3135 passed / 0 failed, sim-baseline 13/13 unmoved on the adopted lines,
determinism 258cc8b1c957a796). On main 15baf0e09:
- a99bd09ed: `RuleSwitches.DEFAULT_ON = ["sight", "spread", "pin_slow"]`, header comment; `--rules-off=` still turns each
  off. `make rules-shots`' OFF arm now passes `--rules-off=sight,spread,pin_slow`. Hull-down untouched.
- 181f46f61: scenario_cover's fights_from_cover holds sight OFF (accepted for this merge). With R1 ON, builder0
  a99bd09ed read hidden 90 %, shots 2, back to cover 1 (bar 2); laptop runs show sight alone moves it. **Round 39: the
  peek-and-return loop under R1** (in round 39's doctrine brief).
- eb635cc6c: sim-baseline adopted, all 13 maps moved (read twice on builder0 at 181f46f61, agreeing; old -> new in
  the commit message).
- 95a3a8f54: test_control_dials' inset test holds R1-R3 OFF and restores them in teardown. Each run alone on
  builder0: at eb635cc6c (rules ON) it FAILS, 0.44 v 0.50. At 15baf0e09 it PASSES. With sight alone OFF it still fails,
  0.56 v 0.59: the fixture's two blocks fight while the camera settles. The laptop fails it even with the rules OFF;
  that failure is the laptop's own.
- scout_suppress::test_target_crossing (pending) now passes unexpectedly. It is left pending, for round 39 to promote.



_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-23, FINAL for round 38). GREEN: 5a9464679** (builder2 `make native check exited 0`, 3069 passed / 0
failed, sim-baseline 13/13 unmoved; the scenario perf row NOT JUDGED, reason=loaded, as on every builder2 check: builder2 isn't a
judging machine). Commits after it change only this brief (`git diff --stat 5a9464679 HEAD`: _agents/streams/doctrine.md alone).
Earlier greens: c475c3163 (3066 / 0), acbdef4c5 (3063 / 0), both builder2.
- **D1 the read: DONE** (below). Against a blob, the CPU fired 75 % of its damage in attack posture from its own half.
- **D2 hold-and-fire (`--cpu-defend`): FAIL, ships OFF.** Blob -4.4 points at 1.5 se; turtle kills -3.8 se.
- **D2b (defend only against a contact coming for the ring): FAIL, ships OFF.** Blob -3.1 at 0.9 se; turtle kills -2.8 se;
  CPU v CPU +31 % length.
- **D2c (SPLIT: post only the elements the threat needs, the rest attack; `--cpu-defend --cpu-defend-split`): FAIL on the
  deciding line, ships OFF.** Blob -4.4 at 1.2 se. Every guard held: turtle kills 1.6 se, CPU v CPU +6 %. CLOSING
  (`--cpu-defend-closing`) is built, and the labs showed it undoes SPLIT, so it ships OFF.
- **D3, R1-R3 and K2 re-read on OFF: no switch moves the CPU v the guard lines** (read below). This is for his design call.
- **Stretch (CPU low-cover seats when defending): not built.** D3's hull-down stops 0.85-1.24 rounds a fight; the gate was 8.
- **Decisions I made:** D3 on top of OFF, not D2 (accepted, R38.29). D2c's series arm re-filed to SPLIT alone after the labs,
  before any series number (recorded, R38.30). The D2c design and constants are mine (design note below).
- **For round 39 (R38.41):** a powered SPLIT series. The effect looks like ~4 points (-4.4 / -3.1 / -4.4 across three series),
  which needs ~4x the fights for 2 se. Use fresh seeds again, since 5001-5108 have now shaped it.
- **Known issues:** the D2c lab (20 fights, 2 seeds) said 9 -> 4 and the series said 51 -> 47 %, so lab reads on 2 seeds are
  not evidence. `make doctrine-shots` needs a real GPU (laptop), and its show-match camera follows the action, so it can't show
  where the posts stand. G4 perf was never judged on builder0 for the switches (all ship OFF, and the OFF path is unchanged).
- **Playtest (all OFF by default; `make skirmish` passes no extra flags and play.mk isn't mine, so call Godot directly):**
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --enemy=cpu --element-cpu --cpu-defend
  --cpu-defend-split` shows the CPU posting part of its line on its near ring and attacking with the rest. (`--element-cpu`
  is the default since round 21 and only spells it out.) Add `--cpu-defend-closing` for the closing trigger. D2's whole-line defend is
  `--cpu-defend` alone. A `SKIRMISH_FLAGS` passthrough in play.mk would be a small request to its owner. Pictures: `make doctrine-shots DOCTRINE_SHOT_FLAGS="..."` on the laptop.
- **Merge notes:** owned paths only: game/tactics/posture.gd, element_commander.gd (new switches, default OFF), tests/
  test_tactics_posture.gd (24 tests), tests/tactics/hold_fire_probe.gd + hold_fire_pair.py, mk/tactics.mk (doctrine-shots,
  tactics-hold-fire). No baseline moved. Raw guard logs: ~/doctrine-guard-raw/{acbdef4c5,c475c3163,5a9464679}-*; scripts:
  ~/doctrine-runs/*.sh. Per-faction pairing used native's guard.py (stream/native 68301e6a7), not committed here.
- **Questions for the lead:** none blocking. D3's read is his to weigh (below): the rule switches don't change the CPU's
  results, so whether they ship is about how the game feels.

**D1 the read (DONE).** Tool: `make native tactics-hold-fire` (tests/tactics/hold_fire_probe.gd extends the guard line read-only;
every direct round, the same weighted by damage a round, and a 2 Hz crew sample, split by posture, posture reason, map half,
element task verb, brain option and seat distance, motion as R37.26). Reads, all builder0 native ON, light:
(1) 640850023, blob 80 fights + turtle 45 (the slot's 90 min cap took the rest; ~/doctrine-runs/d1);
(2) 6e049da5b with damage and reasons, blob 55 of 80 (stopped at the orchestrator's request, the box was loaded; ~/doctrine-runs/d1b).
- **The CPU is not defending when the blob comes.** Blob line, damage-weighted (2): 81.7 % of the CPU's damage is fired in ATTACK
  posture, and **75.0 % is ATTACK because it "holds no objective" while it stands in its OWN half**: the blob reaches the CPU's
  near ring (the blob's target) before the CPU has taken it, and Posture.decide only holds a zone the side already owns. 17.4 %
  "threatened" (a held zone, enemy within 60 m), 0.3 % ahead. Rounds (1): 82.6 % attack posture, 55.5 % moving (= R37.26).
- In attack posture it fights as an attacker: by verb (damage) attack 42 % (50 % of it moving), support_by_fire 32 % (54 %),
  screen 11 % (62 %); by option ENGAGE 39 % (48 % moving), MOVE 23 % (79 %), HOLD 24 % (23 %); by seat, crews > 15 m from their
  slot 35 % of damage (66 % moving), within 5 m 19 % (17 % moving).
- **A CPU crew that holds on its seat already stops to fire** (hold|HOLD|near: 83 % still by damage, 93 % by rounds). In hold
  posture the movers are crews driving to posts 15 m+ away (hold|MOVE|away 72 % moving): `_hold` re-lays the posts across the
  enemy's CENTRE each think, so as the blob comes on the post line swings and crews drive mid-fight.
- Turtle line (CPU the attacker, as it should be): 90 % of its rounds in attack posture, 56 % moving.
- Not the lever: the HOLD option itself, ENGAGE inside a hold (2 % of damage), SPOT (< 1 %).

**D2 design (my paths only: posture.gd, element_commander.gd; native: no twin, confirmed by native).** `--cpu-defend`:
(a) DEFEND posture: a side whose near ring (Posture.near_ring) is not the enemy's and has a known enemy within THREAT_M (60 m)
of it HOLDS that ring, owned or not yet, whatever the score; a threatened held zone still comes first; the hold is kept
(POSTURE_KEEP_TICKS) while the ring is not the enemy's. The hold is round 19's `_hold` as it is: posts across the zone facing
the threat, recon screening out, support behind, one post on an intruder. (b) the posts keep the facing they were laid with
until the enemy's direction from the zone swings > 45 degrees. Symmetric: every side a commander runs (both CPU sides in CPU v
CPU); his squads are not commanded (parked = settle's). Why not the brain: a holding crew on its seat already fires still.
Lab: tests/test_tactics_posture.gd 16/0 (6 new: off = today, defend, far enemy, enemy-owned ring attacked, mirrored, held zone first).

**D2 lab (NOT judged: 40 blob fights, 2601-2604 x 5 maps x both sides, builder0 native light J=4, paired with D1's OFF rows
at 6e049da5b; `tests/tactics/hold_fire_pair.py`).**
- Lab 1, 6877a099c (defend (a)+(b) at 60 m): CPU damage in defend posture 0 -> 39.6 %, in attack/"nothing"/own half 77.5 -> 26.4 %
  (the posture engages), but CPU damage fired moving only 49.8 -> 47.0 %; blob wins 18 -> 20 of 40 (flips 2 / 4: noise). Why:
  inside the hold the first post's `attack` on an intruder was 20 % of all CPU damage (43 % moving), and crews drove onto posts
  laid after contact (hold|MOVE|away 87 % moving).
- So (still before any judged number, same switch): (c) a defending post never breaks off for an intruder; (e) an element in
  contact within 35 m of its post stands where it is; (d) defend triggers at 100 m (Posture.DEFEND_M), not 60. Tests 18/0.
- Lab 2, b9f8a347c (a)-(e): **blob wins 18 -> 13 of 40 (flips to a loss 5, to a win 0)**; CPU damage fired moving 49.8 ->
  **37.4 %** (per-seed se 3.8); in defend posture 43.4 %; holders (hold verb) 73 % still; kills blob 681 -> 655, CPU 894 -> 917.
  The remaining movers: attack posture 31 % of damage (52 % moving), hold|MOVE|away 5 % (90 % moving). Lab only: the bar decides.

**Bar D2 (FILED 2026-10-22 before any arm number; C38.1/C38.2).** Change: `--cpu-defend` ON v OFF.
- **Base:** main 1c484a525's `references/scoreboard/guards/1c484a525.fights.jsonl` (320 fights, builder2). Gate: my pair tree
  OFF replays it with 0 flips on one seed block (2601), else the base is re-run on the pair tree and paired against that.
- **Workload:** the same 320 guard fights an arm (5 maps x 2601-2608 + 2701-2708 x both sides x blob/turtle), builder2,
  `guard.sh`, judged `guard.py --pair`. Plus the CPU v CPU line (`GUARD_KINDS=none`, 2601-2608, both arms).
- **Positive control:** `tactics-hold-fire` ON on the blob line: the CPU's damage share fired in "defend" posture > 0 on every
  map, and its share in attack/"holds no objective"/own half DOWN.
- **Deciding:** the blob's win rate DOWN v base by > 2 x paired se AND exact McNemar p < 0.05.
- **Second line:** the blob's kill ratio not UP by > 2 x paired se (a contradiction, not a pass).
- **Mechanism (reported, the brief's claim):** the CPU's moving share of damage fired on the blob line, ON v OFF (base 50.8 %, 55
  fights); expected down.
- **G1 (the CPU still attacks when it is the attacker):** turtle v tactics: the turtle's win rate not UP by > 2 x paired se and
  its McNemar p not < 0.05 in its favour; turtle median length not up by > 2 x paired se.
- **G2:** kills a fight and median length per faction, both lines, within base +- 2 x paired se (a faction outside is named).
- **G3 (what DEFEND could break: two defenders stall):** CPU v CPU (none line, 40 distinct fights x 2 sides): fights reaching the
  600 s cap ON <= OFF + 2, and median length ON <= OFF x 1.2; decisive results reported.
- **G4:** perf: commander code is a think a second (no per-crew cost); perf-judge on builder0 when the orchestrator judges main.
- **Equality:** sim-baseline unmoved with the switch OFF.
- **A pass ships ON** (symmetric AI improvement: his standing rule). One re-tune allowed only on the guard lines (THREAT_M for
  defend), then judged as it stands.

**D2 verdict (2026-10-22; acbdef4c5, builder2, `guard.sh` J14, 320 fights, `--cpu-defend` v 1c484a525; 320/320 ON logs
carry the switch; OFF gate 2601 0 flips): FAIL, ships OFF.**
- Deciding: blob 49 -> 44 % (-4.4, paired se 2.9 = 1.5 se; flips 15 to a loss, 8 to a win; McNemar p 0.105). Not met. Leans right.
- Second line: blob kill ratio 0.86 -> 0.81 (-0.051, se 0.032): not up.
- G1: turtle 40 -> 42 % (+2.5, se 4.4), McNemar 0.79 (not in its favour), median 195 -> 194 s. Holds.
- **G2 broken on the turtle line:** kills a fight (both sides) 32.4 -> 26.2 (-6.2, se 1.6, -3.8 se); by the guard's faction
  condemned -9.4 (-3.5 se), gangs -10.3 (-2.5 se), law -4.5 (-3.2 se), syndicate -1.8 (-2.2 se); length +3.3 s (+0.9 se). Blob
  line flat: kills -0.5 (-0.9 se), length -2.0 s (-0.7 se), every faction inside 2 se. Reading: defend fired on ANY contact within
  DEFEND_M of the CPU's near ring, a turtle sitting on its own zone was often that close, and the CPU stopped attacking it.
- G3: not run for D2. The none line OFF (seeds 2601-2608) is read and serves D2b; D2's own none-ON was skipped as moot.
- Tool: G2's paired kills/length per faction came from a scratch script on guard.py's reader (to fold into guard.py --pair: a
  request to native, which owns it).

**Bar D2b (FILED 2026-10-22 before any D2b arm number; re-filed under R38.14, fresh seeds).** Change: `--cpu-defend` with
D2b's trigger ON v OFF, **tree 4297bbb8b+** (eaf4c508f: a contact counts toward defend only when nearer the CPU's near ring
than to every zone its side owns; 4297bbb8b: with defend ON, a held zone is "threatened" only by such a coming contact too).
- **Workload:** FRESH guard seeds **4801-4808 + 4901-4908** (no round-38 guard series used them; D2b's trigger was shaped by D2's
  320 fights, R37.17). x 5 maps x both sides x blob/turtle = 320 fights an arm. **Both arms on D2b's tree** (the Status commit on 4297bbb8b,
  once its full check is green on builder2), builder2, `guard.sh` GUARD_CHUNK=8, judged `guard.py --pair OFF ON` (paired with each other, not with
  1c484a525). Plus the none line (CPU v CPU), seeds 4801-4808, both arms.
- **Equality / positive control / deciding / second line / mechanism / G1-G4:** Bar D2's text unchanged, with "base" meaning
  this OFF arm.
- **G2t (explicit):** the turtle line's kills a fight (both sides), ON within 2 paired se of OFF.
- No re-tune: judged as it stands. A pass ships ON (symmetric).

**D2b verdict (2026-10-23; c475c3163 both arms, builder2, `guard.sh` J14 GUARD_CHUNK=8, seeds 4801-4808 + 4901-4908, 320
fights an arm, 0 attempts lost; 400/400 ON logs carry `cpu-defend`, 0/400 OFF; judged with native's per-faction `guard.py
--pair`, stream/native 68301e6a7): FAIL, ships OFF.**
- Deciding: blob 47 -> 44 % (-3.1, paired se 3.4 = 0.9 se; flips 16 to a loss, 11 to a win; McNemar p 0.22). Not met.
- Second line: blob kill ratio 0.82 -> 0.82 (+0.004, se 0.030): not up. Blob kills a fight 18.74 -> 18.73, length 98 -> 96 s;
  every faction inside 2 se (law kills -1.32, se 0.73 = 1.8 se, the nearest).
- G1: turtle 39 -> 32 % (-6.9, se 3.5), down not up; median 193 -> 193 s. Holds.
- **G2t broken:** turtle line kills a fight 14.74 -> 12.81 (-1.94, se 0.69 = -2.8 se); gangs -1.27 (-4.4 se), condemned -2.42
  (-2.1 se). Losses a fight too: -2.45 (-2.4 se). Smaller than D2's -3.8 se but not inside 2 se: fights v a turtle are quieter.
- **G3 broken:** none line (CPU v CPU, 4801-4808, 80 fights): caps ON 0 v OFF 2 (holds), median 130 -> 170 s (+31 %, +40 s se
  15; the bar is x1.2), every faction +13..+45 s. Two CPUs that both defend take longer to settle it.
- Mechanism and positive control: not read on these fights (hold_fire_probe is a lab tool; moot with the deciding line unmet).
- G4: not judged (the check's perf row NOT JUDGED, reason=loaded); moot, the switch ships OFF and its OFF path is unchanged.
- Reading: the trigger fix bought back half of D2's turtle cost and none of the blob's; holding the near ring does not beat a
  blob at these numbers. Raw: ~/doctrine-guard-raw/c475c3163-{off,defend}/{blob,turtle,none}.

**Design note: why DEFEND made the CPU passive, and a version that might not (2026-10-23, for round 39; R38.29).**
- **What the numbers say:** the CPU didn't fight worse, it fought less. Turtle line: kill ratio flat (D2b 0.84 -> 0.85) while
  kills AND losses a fight both fell (-1.94 and -2.45). None line: +40 s median. Labs (builder0 light, turtle 2601-2602, 20
  fights): CPU time in hold posture OFF 36 %, D2 77 %, D2b 59 %. The blob line, where the enemy really comes, didn't move.
- **Cause 1, it's side-wide.** Posture is one word for the whole side. Defend puts every line element on the ring, and in
  `Posture.decide` it comes before "not ahead -> attack". So a side that is behind on points, which OFF would send forward,
  sits instead. That's the main leak: the score logic is overruled by proximity.
- **Cause 2, proximity is the trigger.** Any known enemy within DEFEND_M (100 m) holds us. D2b dropped enemies sitting on
  their own zone, but an enemy that stops 90 m out still holds the whole side indefinitely, and a turtle's posts or a
  CPU's holding line do exactly that. Nothing measures whether it is actually coming.
- **Cause 3, no clock.** Defend lapses only when the contact leaves 100 m, and POSTURE_KEEP_TICKS then delays the switch back.
  Two CPUs (none line) each see the other near their ring and both hold, so a standoff resolves only on control ticks.
- **Cause 4, no counter-stroke.** DEFEND (c) took away the one element that went for an intruder (it fired 43 % on the move,
  so the lab cut it). The hold then has no way to turn a stalled attack into a kill.
- **Best guess, "hold with some, strike with the rest":**
  1. *Economy of force, per element:* defend tasks only as many line elements as the coming threat needs (by count of
     coming contacts, at most half the line). The rest follow what `decide` would say with defend OFF, so a side behind
     still attacks.
  2. *Closing, not near:* a contact counts only while its distance to the ring has fallen over the last ~10 s. The commander
     keeps the last distance per contact name, which keeps it out of TankBrain/Movement state.
  3. *A clock:* defend lapses after ~30 s with no contact closing, and isn't re-armed by the same contact without it
     closing again.
  4. *Counter on a stall:* once the coming contacts stop closing, or the local force ratio is >= 1.5, the held elements go
     back to attack from their posts (the base of fire for the rest).
- **Bar shape for it:** fresh seeds (5001+; D2/D2b's fights shaped this, R37.17). Deciding is blob win rate down, as D2's.
  Guards are D2b's G2t and G3, plus a lab guard: CPU hold-time share on the turtle line <= OFF + 10 points (36 % -> <= 46 %).
  1 and 2 are separable switches, so the lab can tell which one buys what. My guess is 1 matters most, since cause 1 alone
  explains the behind-but-sitting fights.

**Bar D2c (FILED 2026-10-23 before any D2c number; R38.30).** Change: `--cpu-defend --cpu-defend-split --cpu-defend-closing`
(the package) ON v OFF, code ebb817ea0. SPLIT: a defend posts only `defenders_needed` (crew for crew with the coming contacts,
>= 1, <= half the line, nearest the ring first), and when the side would attack with defend off the rest attack. CLOSING: a
contact counts only while closing (>= 10 m nearer the ring over 5 s), and the defend lapses 30 s after the last one closed.
- **Labs first** (builder0 native light J4, hold_fire_probe, turtle + blob, seeds 2601-2602 x 5 maps x both sides, 40 fights an
  arm; all arms on one tree): OFF, split, closing, package. They say which switch buys what, and they hold the lab guard. One
  re-tune of the constants is allowed in labs, recorded here before the series tree is named; the series then judges as is.
- **Series workload:** FRESH guard seeds **5001-5008 + 5101-5108** (registered by R38.30) x 5 maps x both sides x blob/turtle =
  320 fights an arm, both arms (OFF, package) on the series tree once its full check is green, builder2 after D3, `guard.sh`
  GUARD_CHUNK=8, judged `guard.py --pair OFF ON`. Plus the none line (CPU v CPU), 5001-5008, both arms.
- **Deciding:** the blob's win rate DOWN by > 2 paired se AND McNemar p < 0.05.
- **Second line:** the blob's kill ratio not UP by > 2 paired se.
- **G1:** the turtle's win rate not UP by > 2 paired se (McNemar p not < 0.05 in its favour); its median length not up > 2 se.
- **G2 / G2t:** kills a fight and median length per faction within 2 paired se on both lines (a faction outside is named); the
  turtle line's kills a fight (both sides) within 2 paired se.
- **G3:** none line: caps ON <= OFF + 2, median length ON <= OFF x 1.2.
- **Lab guard:** turtle line, the package lab on the series tree: CPU crew samples whose element task verb is `hold` <= OFF +
  10 points (the posture word "hold" covers the attacking half under SPLIT, so the verb is the read; D2b's OFF lab 22.0 %, its
  posture-hold 35.7 %).
- **G4:** perf, commander-only code (one decide more a think under SPLIT, a distance per contact under CLOSING). **Equality:**
  sim-baseline unmoved with the switches OFF.
- A pass ships ON (symmetric). If the round closes first it carries to round 39 with this bar intact.

**D2c labs (NOT judged; builder0 native light J4, hold_fire_probe, tree 587c31976 (code ebb817ea0), seeds 2601-2602 x 5 maps x
both sides, 20 fights a line an arm; switches confirmed in every ON log's TANK_SQUAD_READY, none in OFF; OFF reproduces
D2b's OFF lab exactly, 22.0 % / 35.7 %, so the OFF path is unchanged):**

| arm | turtle: guard wins | kills guard + CPU | CPU hold (verb / posture) | blob: guard wins | kills guard + CPU | CPU hold (verb / posture) |
|---|---|---|---|---|---|---|
| OFF | 8 | 283 + 310 | 22.0 / 35.7 % | 9 | 301 + 383 | 5.2 / 13.4 % |
| split | 7 | 271 + 324 | 31.6 / 64.3 % | **4** | 249 + 407 | 25.5 / 67.3 % |
| closing | 10 | 281 + 316 | 23.4 / 38.6 % | 9 | 310 + 378 | 32.1 / 55.2 % |
| package | 8 | 270 + 320 | 23.2 / 46.6 % | 10 | 343 + 352 | 17.7 / 46.9 % |

None line (CPU v CPU, same seeds, 20 fights): OFF median 158 s (6 control, 14 elimination); split 139 s (4 / 16); package 188 s
(8 / 12). Kills 684 / 672 / 638.
- SPLIT is the lever: the blob wins 4 of 20 v 9, turtle-line kills hold (595 v 593; D2 527, D2b 542), and CPU v CPU fights got
  shorter, not longer. CLOSING buys nothing on the blob and undoes SPLIT's gain inside the package (10 of 20), and it lengthens
  CPU v CPU. My read: a blob held at a barrier stops closing, the defend lapses after 30 s, and the CPU leaves its ring.
- **Series arm re-filed (2026-10-23, before any series number): `--cpu-defend --cpu-defend-split` (SPLIT alone), not the
  package.** The bar's text is otherwise unchanged. No constant was re-tuned. CLOSING stays in the code, OFF. Lab guard on
  SPLIT: 31.6 % v OFF 22.0 %, inside +10 points by 0.4. Tight: the series reports it again on the series tree.

**D2c in pictures (`make doctrine-shots DOCTRINE_SHOT_FLAGS="--cpu-defend --cpu-defend-split" DOCTRINE_SHOT_DELAYS="60 90"`,
laptop GPU, tree de27d0370, locks 2602, blob = green; the ON logs carry both switches):** at 60 s both arms look alike, with the
blob massed at the bridge's south end under fire. At 90 s, OFF: blob cars are inside the CPU's street among its buses. SPLIT:
the show-match camera is on the CPU's rocket trucks firing from the rear. No defect on screen, but the frames don't show the
split itself (the camera picks the action, not the ring). A camera pinned on the near ring would be needed to see it. The
series decides.

**D2c verdict (2026-10-23; 5a9464679 both arms (green), builder2, `guard.sh` J14 GUARD_CHUNK=8, fresh seeds 5001-5008 +
5101-5108, 320 fights an arm, 0 attempts lost; 400/400 ON logs carry `cpu-defend-split`, 0/400 OFF; native's per-faction
`guard.py --pair`): FAIL on the deciding line, ships OFF. The guards held.**
- Deciding: blob 51 -> 47 % (-4.4, paired se 3.8 = 1.2 se; flips 18 to a loss, 11 to a win; McNemar p 0.13). Not met.
- Second line: blob kill ratio 0.90 -> 0.86 (-0.042, se 0.028): down, not up.
- G1: turtle 39 -> 35 % (-4.4, se 2.4), down; median 194 -> 193 s. Holds.
- G2t: turtle kills a fight 14.12 -> 13.57 (-0.56, se 0.35 = 1.6 se). **Holds**, where D2 was -3.8 se and D2b -2.8 se, so the
  passivity is fixed. G2 per faction, outside 2 se: blob law median 111 -> 97 s (-3.5 se, shorter); turtle condemned kills
  -1.32 (se 0.66, at 2.0 se).
- G3: none line, caps 0 v 0; median 159 -> 168 s (+6 %, the bar x1.2). Holds (D2b was +31 %).
- Lab guard: split's lab 31.6 % v 22.0 % (inside +10).
- Reading: the 20-fight lab's 9 -> 4 did not hold at 160. The blob effect is the same size as D2's (-4.4 points, now -3.1 and
  -4.4 across D2b/D2c), and every one of the three series fell short of 2 se at 160 fights. The lab was luck on two seeds. SPLIT
  costs nothing the guards measure, so it is a candidate for a larger series (about 4x the fights to see 4 points at 2 se),
  which is the orchestrator's call for round 39. Not pooled here: the bar names one series. Raw:
  ~/doctrine-guard-raw/5a9464679-{off,split}.

**Bar D3 (FILED 2026-10-23 before any D3 arm number).** _(R38.35: if D2c passes, its base and every arm gain `--cpu-defend --cpu-defend-split`, re-filed
before any D3 number; if it fails, as written.)_ Change: the round-37 rule switches ON v OFF, on what ships (defend OFF,
D2/D2b failed): **rules** `--rules-on=sight,spread,pin_slow`; **hulldown** `--cover-on=hulldown`; **pkg** both together.
- **Workload:** tree c475c3163 (green), builder2, `guard.sh` GUARD_CHUNK=8, the same 320 guard fights (4801-4808 + 4901-4908 x
  5 maps x both sides x blob/turtle), each arm paired with **c475c3163-off** (read above) by `guard.py --pair`. These switches
  weren't shaped by these fights (R37.17 holds). No none line (the switches are symmetric; caps read off the guard lines).
- **Read, not a ship call:** these are game rules that change what the player feels, so whether to turn one on is the lead's call
  (design pillar); this reports what each does to the CPU v the two lines.
- **Reported per arm:** blob and turtle win rates with paired se and McNemar p; kill ratio; kills/losses a fight and median length
  per faction (a faction beyond 2 se is named); caps; for hulldown/pkg, `cover_struck` a fight (rounds hull-down stopped).
- **"Matters" (the stretch gate):** hulldown or pkg moves a line's win rate by > 2 paired se, OR `cover_struck` a fight >= 5x R37's
  1.6 (505 in 320). Neither: the stretch (CPU low-cover seats) is written up as not worth building now.

**D3 read (2026-10-23; c475c3163, builder2, `guard.sh` J14 GUARD_CHUNK=8, seeds 4801-4808 + 4901-4908, 320 fights an arm,
0 lost; every arm's GUARD_RESULT "args" carries its switches (320/320); each paired with c475c3163-off; native's guard.py --pair):**

| arm | blob wins (paired se, McNemar) | blob kill ratio | blob median | turtle wins (se) | turtle kills a fight | rounds hull-down stopped a fight |
|---|---|---|---|---|---|---|
| OFF | 47 % | 0.82 | 98 s | 39 % | 14.74 | 0 |
| rules (sight, spread, pin_slow) | 43 % (-3.7, se 2.7; p 0.19) | 0.80 | 105 s (+7, se 2) | 39 % (+0.6, se 3.9) | 15.17 (+0.42, se 0.28) | 0 |
| hulldown | 46 % (-1.3, se 0.9; 2 flips) | 0.82 | 98 s | 39 % (+0.6, se 1.1) | 14.74 | blob 0.85, turtle 1.24 |
| package | 42 % (-5.0, se 2.9; p 0.11) | 0.79 | 105 s (+8, se 2) | 40 % (+1.3, se 3.6) | 15.11 (+0.37, se 0.30) | blob 0.68, turtle 1.14 |

- No arm moves either line's win rate by 2 paired se. No caps in any arm.
- **The rules slow blob fights by 7-8 s** (3.5 se), mostly law (89 -> 107 s, +4.5 se). Turtle fights are shorter for gangs
  (-37 s) and syndicate (-52 s) at about 3 se.
- **Hull-down does almost nothing:** about 1 round stopped a fight, 0-2 results flipped in 160. That is R37's read again.
- **Stretch gate (Bar D3's "matters"): not met.** No win rate moves 2 se, and hull-down stops 0.68-1.24 rounds a fight against
  the gate's 8. CPU low-cover seats are not worth building on these numbers.
- **For his design call:** turning R1-R3 on doesn't help or hurt the CPU v the guard lines measurably. It makes blob fights a
  little longer and some turtle fights shorter, so whether to ship them is about how a fight feels, not about results.

**D2b labs (NOT judged; builder0 native light J4; D2's seeds 2601-2602 x 5 maps x both sides; hold_fire_probe):**
| line, 20 fights | CPU hold time | CPU dmg in defend | in "threatened" | kills (guard + CPU) | guard wins |
|---|---|---|---|---|---|
| turtle OFF (4297bbb8b) | 36 % | 0 % | 29 % | 283 + 310 = 593 | 8 |
| turtle D2 trigger (1105f83cb) | 77 % | 35 % | 57 % | 240 + 287 = 527 | 8 |
| turtle D2b trigger (c042ca206) | 60 % | 21 % | 66 % | 243 + 299 = 542 | 7 |
| turtle D2b + threatened filter (4297bbb8b) | 59 % | 24 % | 63 % | 243 + 299 = 542 | 7 |
| blob D2b + threat. (4297bbb8b) v OFF (D1 640850023) | | 46 % | | 267 + 395 v 301 + 383 | 6 v 9 |
Reading: D2b's trigger recovers about half the turtle-line kills D2 cost. The rest: under defend the CPU takes its near ring early,
then holds it against turtle posts that stand nearer that ring than their own zone (they pass the "coming" test). Not tuned
further, since tuning to these 20 fights is what R37.17 forbids. The fresh-seed bar decides, and G2t may fail.

**D2 in pictures (`make doctrine-shots`, laptop, a656460ea's tree; locks seed 2602, blob = green, 60 s in, 1854x1011 and
1200x540; looked at):** OFF, the CPU's rust line burns north of the bridge and the blob has crossed it. ON, the rust CPU stands
on its own scoring ring (FAR QUAY) firing, and the blob is held at the barrier beside the building. The phone frame reads the same.
builder0's llvmpipe can't render these (12/12 runs exited 124 at the 300 s timeout), so run it on the laptop.

**builder2 hand-off:** when the D2 series ends, message settle (godot-settle-6b) AND the orchestrator "builder2 free" (settle's
S2 re-read waits behind it, R38.10).

**Pairing base (native, 2026-10-22):** main 1c484a525's `references/scoreboard/guards/1c484a525.fights.jsonl` (on main since
cc7c7ef1a; 320 fights, builder2): blob 49 % (± 7), turtle 40 % (± 16). Arms pair with `guard.py --pair` against it; main's rolling
guard.sh (cc7c7ef1a) resumes per fight; I merge main for it before D2's series.

**Plan (in order; one-line reasons):**
1. D1 the read: `make tactics-hold-fire` (tests/tactics/hold_fire_probe.gd, extends the guard line read-only): every CPU direct round
   and a 2 Hz crew sample split by posture (hold/attack), element task verb, brain option and seat distance, with R37.26's motion
   buckets; blob AND turtle lines, the base's seeds 2601-2608 x 5 maps x both sides (160 fights), builder0 light. Reason: the
   brief wants the cause (which option moves a holder) before any code.
2. D1 design note to the orchestrator: where a holder moves, which lever, and the bar (C38.1: the property it could break).
3. D2 hold-and-fire behind a switch, lab first; quick-remote; one full check on a named hash; the paired guard series on builder2.
4. D3 R1-R3 and K2 re-read, on what ships (defend OFF, after D2/D2b failed): Bar D3 above.
5. Stretch: low-cover seats when defending. **NOT BUILT: D3's gate not met (hull-down stops ~1 round a fight).** **Read (laptop, uncommitted tree on 362e81c6e, locks 2602 blob, 120 s, `--cpu-defend
   --cover-seat=on --cover-on=hulldown`, the probe's new `cover` field):** O6's call (`--cover-seat=on`) can't reach the CPU's holds.
   `ElementPlan._deploy_state` deploys only a `move` without a told facing, and the CPU's holds are `hold` with a facing: CPU
   elements deployed in 0 of 919 2 Hz samples (the blob 73 of 661), and no seats moved on either side. A CPU cover seat needs its own
   path: per crew, a hook in the halt lay (settle's function: a request, not mine to edit), or the commander shifting a defend
   post once behind low cover (mine). **Gated on D3's hulldown arm (Bar D3's "matters"):** only build it if K2 stops enough rounds to
   matter (R37's read: 505 shots stopped in 320 fights, too few to change outcomes).
